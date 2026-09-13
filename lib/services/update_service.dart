/// 自动更新检查（查 GitHub Releases）
///
/// 只做三件事：**问 GitHub 最新版是多少 → 跟自己比 → 把结果交给界面**。
/// 下载与安装都不在这里：直接把用户送到对应平台的安装包，让他自己装。
///
/// ## 为什么是「跳转下载」而不是自动下载安装
///
/// 自动替换自己的可执行文件，在三个平台上要写三套完全不同的代码，
/// 而且每一套都需要提权或绕过系统的安全检查：
///
/// - macOS：要往 `/Applications` 里换 `.app`，未公证的包还会被 Gatekeeper 拦；
///   应用自己换自己还涉及已签名 bundle 的完整性
/// - Windows：正在运行的 `exe` 无法被覆盖，得先起一个分离的进程、
///   等自己退出后再替换（安装器模式的经典做法）
/// - Linux：装在哪取决于用户是怎么装的（系统包 / 解包目录），应用猜不出来
///
/// 而「跳到下载页、用户双击安装包」这条路在三个平台上都是用户本来就熟的，
/// 也不需要任何提权 —— 本项目的安装包都是免管理员、装到用户目录的，
/// 覆盖安装不会丢进度（进度不在安装目录里）。
///
/// ## 失败必须静默
///
/// 检查更新失败**永远不能打扰用户**：没网、公司代理、GitHub 被墙、
/// API 限流（匿名 60 次/小时）都是很常见的事，而这些跟「能不能做题」毫无关系。
/// 所以 [UpdateService.check] 不抛异常，失败就返回 [UpdateCheckStatus.failed]，
/// 启动时那条路更是直接当没发生。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../app_version.dart';
import 'error_log_service.dart';

/// 本项目的 GitHub 仓库（更新检查的唯一数据源）
const String kGitHubRepo = 'hqswww/python-practice-platform';

/// 全局服务单例（和 settings / languageService 同一个路子）。
/// 当前版本取 [appVersion] —— 版本号仍然只有这一个维护点。
final updateService = UpdateService(currentVersion: appVersion);

/// 一次 HTTP 取文本的结果。抽出来是为了测试能塞假响应。
class HttpTextResponse {
  final int statusCode;
  final String body;

  const HttpTextResponse(this.statusCode, this.body);
}

/// 取一个 URL 的文本。生产实现见 [defaultTextFetcher]。
typedef TextFetcher = Future<HttpTextResponse> Function(Uri url);

/// 一条可用的更新
class UpdateInfo {
  /// 规范化后的版本号（去了 `v` 前缀、去了构建元数据），如 `1.5.0`
  final String version;

  /// Release 的原始 tag，如 `v1.5.0`（展示时用原来那个更亲切）
  final String tagName;

  /// 更新内容（Release 正文的 **Markdown 原文**，与 GitHub 上一致）。
  ///
  /// 展示前用 [cleanReleaseNotes] 收拾一下 —— 把显示层的活儿留在显示层，
  /// 模型里存的东西跟接口给的保持一致。
  final String notes;

  /// Release 页面地址（找不到对应安装包时的兜底去处）
  final String releaseUrl;

  /// 本平台安装包的直链；没有对应产物时为 null
  final String? downloadUrl;

  /// 安装包文件名（展示给用户，让他知道要下哪个）
  final String? assetName;

  const UpdateInfo({
    required this.version,
    required this.tagName,
    required this.notes,
    required this.releaseUrl,
    this.downloadUrl,
    this.assetName,
  });

  /// 界面上优先用哪个链接
  String get preferredUrl => downloadUrl ?? releaseUrl;
}

/// 一次检查的结果。
///
/// 手动检查（设置页）需要区分「已是最新」和「检查失败」——
/// 这两种情况对用户的意思完全相反，不能都显示成「没有更新」。
enum UpdateCheckStatus {
  /// 已经是最新版（含「远端还没有发布任何 Release」）
  upToDate,

  /// 有新版本
  updateAvailable,

  /// 网络/接口出问题，没查成（不抛异常，只报告）
  failed,
}

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final UpdateInfo? update;

  /// 失败原因（给人看的一句话，主要进日志）
  final String? error;

  const UpdateCheckResult._(this.status, this.update, this.error);

  const UpdateCheckResult.upToDate()
      : this._(UpdateCheckStatus.upToDate, null, null);

  const UpdateCheckResult.available(UpdateInfo info)
      : this._(UpdateCheckStatus.updateAvailable, info, null);

  const UpdateCheckResult.failed(String reason)
      : this._(UpdateCheckStatus.failed, null, reason);

  bool get hasUpdate => status == UpdateCheckStatus.updateAvailable;
}

/// 平台标识 —— 用来挑对应的安装包
enum UpdatePlatform {
  macos('macos', '.dmg'),
  windows('windows', '.exe'),
  linux('linux', '.tar.gz');

  const UpdatePlatform(this.key, this.assetSuffix);

  final String key;

  /// 本平台安装包的扩展名。macOS 用 dmg（拖拽安装）；
  /// Windows 用 exe（Inno 单文件安装包）；Linux 是 tar.gz 绿色包。
  final String assetSuffix;

  /// 当前运行平台。测试里别调它 —— 用 [pickAsset] 的显式参数。
  static UpdatePlatform current() {
    if (Platform.isWindows) return UpdatePlatform.windows;
    if (Platform.isMacOS) return UpdatePlatform.macos;
    return UpdatePlatform.linux;
  }
}

/// Release 里的一个附件
class UpdateAsset {
  final String name;
  final String url;

  const UpdateAsset({required this.name, required this.url});
}

/// 检查更新的服务。
///
/// [fetcher] 只为测试注入；默认走 [defaultTextFetcher]。
class UpdateService {
  final String repo;
  final TextFetcher _fetch;

  /// 当前版本，默认取 [appVersion]（由调用方传进来避免这里依赖 UI 层常量）
  final String currentVersion;

  UpdateService({
    this.repo = kGitHubRepo,
    required this.currentVersion,
    TextFetcher? fetcher,
  }) : _fetch = fetcher ?? defaultTextFetcher;

  /// 问一次 GitHub，判断有没有新版本。**不会抛异常。**
  ///
  /// [platform] 用来挑本平台的安装包；不传则按当前运行平台。
  Future<UpdateCheckResult> check({UpdatePlatform? platform}) async {
    final url = Uri.parse('https://api.github.com/repos/$repo/releases/latest');
    HttpTextResponse res;
    try {
      res = await _fetch(url);
    } catch (e) {
      // 没网、DNS 失败、超时、代理拒绝…… 全部归到这一类
      errorLog.log(
        '检查更新失败（网络）：$e',
        source: LogSource.system,
        level: LogLevel.info,
      );
      return UpdateCheckResult.failed('网络不通或超时');
    }

    // 404 = 仓库还没有任何 Release。这对用户就是「已经是最新」，
    // 不是错误 —— 项目刚起步时 Releases 是空的。
    if (res.statusCode == 404) return const UpdateCheckResult.upToDate();

    if (res.statusCode != 200) {
      // 403 多半是匿名 API 限流（60 次/小时/IP）
      final hint = res.statusCode == 403 ? '接口限流（稍后再试）' : '接口返回 ${res.statusCode}';
      errorLog.log(
        '检查更新失败：$hint',
        source: LogSource.system,
        level: LogLevel.info,
      );
      return UpdateCheckResult.failed(hint);
    }

    UpdateInfo? info;
    try {
      info = parseLatestRelease(
        res.body,
        currentVersion: currentVersion,
        platform: platform ?? UpdatePlatform.current(),
      );
    } catch (e) {
      // 返回体不是预期的 JSON（比如被网络中间层塞了个登录页）
      errorLog.log(
        '检查更新失败：返回内容看不懂（$e）',
        source: LogSource.system,
        level: LogLevel.info,
      );
      return UpdateCheckResult.failed('返回内容看不懂');
    }

    if (info == null) return const UpdateCheckResult.upToDate();
    return UpdateCheckResult.available(info);
  }
}

// --------------------------------------------------------------- 纯函数部分
// 下面这些不碰网络、不碰文件系统，全部可以直接测。

/// 解析 GitHub 的 `releases/latest` 返回体。
///
/// 返回 null 表示「当前版本不比它旧」（含远端 tag 比本地还低的情况 ——
/// 开发机上跑未发布版本时会遇到）。
UpdateInfo? parseLatestRelease(
  String body, {
  required String currentVersion,
  required UpdatePlatform platform,
}) {
  final json = jsonDecode(body);
  if (json is! Map) throw const FormatException('顶层不是对象');

  final tag = (json['tag_name'] ?? '') as String;
  if (tag.trim().isEmpty) throw const FormatException('没有 tag_name');

  if (compareVersions(tag, currentVersion) <= 0) return null;

  final assets = <UpdateAsset>[];
  for (final a in (json['assets'] as List<dynamic>? ?? const [])) {
    if (a is! Map) continue;
    final name = (a['name'] ?? '') as String;
    final url = (a['browser_download_url'] ?? '') as String;
    if (name.isNotEmpty && url.isNotEmpty) {
      assets.add(UpdateAsset(name: name, url: url));
    }
  }
  final asset = pickAsset(assets, platform);

  return UpdateInfo(
    version: normalizeVersion(tag),
    tagName: tag,
    notes: ((json['body'] ?? '') as String).trim(),
    releaseUrl: (json['html_url'] ?? 'https://github.com/$kGitHubRepo/releases')
        as String,
    downloadUrl: asset?.url,
    assetName: asset?.name,
  );
}

/// 把 Release 正文收拾到「弹窗里能看」的程度。
///
/// GitHub 的 Release 正文是 Markdown，而弹窗里是普通文本渲染。
/// 与其引一个 Markdown 渲染库（体积、样式、安全都得管一遍），不如把那几个
/// **在纯文本里看着像 bug** 的标记处理掉，剩下的交给项目自己的
/// `RichMessageText`（它认 `**加粗**` 和 `` `代码` ``）：
///
/// - 行首的 `#`（标题标记）去掉，只留文字
/// - 代码围栏 ``` 整行去掉，里面的内容保留
/// - 行首的 `- ` / `* ` 换成 `· `（`*` 会和加粗标记打架）
/// - 连续空行压成一个
///
/// 真实数据验证过：pandoc 的 Release 正文开头就是三个反引号，
/// 不处理的话弹窗第一眼看到的就是它。
String cleanReleaseNotes(String raw) {
  final out = <String>[];
  for (final line in raw.replaceAll('\r\n', '\n').split('\n')) {
    final t = line.trimRight();
    // 代码围栏整行丢掉（``` 或 ```dart）
    if (RegExp(r'^\s*```').hasMatch(t)) continue;
    // 标题：去掉行首的 #，文字留着
    final heading = RegExp(r'^\s*#{1,6}\s+(.*)$').firstMatch(t);
    if (heading != null) {
      out.add(heading.group(1)!);
      continue;
    }
    // 列表标记换成中点，免得 `*` 和 `**加粗**` 抢
    final bullet = RegExp(r'^(\s*)[-*]\s+(.*)$').firstMatch(t);
    if (bullet != null) {
      out.add('${bullet.group(1)}· ${bullet.group(2)}');
      continue;
    }
    out.add(t);
  }

  final text = out.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

/// 按平台挑安装包：取第一个扩展名对得上的。
///
/// 为什么按扩展名而不是按精确文件名：文件名的中文部分（「编程练习册」）
/// 随时可能改，按名字匹配会变成「改一次展示名，更新检查就找不到包了」。
UpdateAsset? pickAsset(List<UpdateAsset> assets, UpdatePlatform platform) {
  for (final a in assets) {
    final lower = a.name.toLowerCase();
    // macOS 只认 dmg：zip 是绿色版，用户拖进 Applications 也能用，
    // 但 dmg 才是「双击 → 拖一下」的那条正路
    if (platform == UpdatePlatform.macos && lower.endsWith('.zip')) continue;
    if (lower.endsWith(platform.assetSuffix)) return a;
  }
  return null;
}

/// 比较两个版本号：`a > b` 返回正数，相等返回 0，`a < b` 返回负数。
///
/// 容忍这几种写法（真实会遇到的）：
/// - `v1.5.0` / `V1.5.0`（GitHub tag 通常带 v）
/// - `1.5`（少写一段，按 `1.5.0` 算）
/// - `1.5.0+4`（构建号，**不参与比较** —— 它只是同一版本的重新打包）
/// - `1.5.0-beta.1`（预发布：按 SemVer，它比 `1.5.0` **小**）
int compareVersions(String a, String b) {
  final pa = _parseVersion(a);
  final pb = _parseVersion(b);
  for (var i = 0; i < 3; i++) {
    final d = pa.core[i].compareTo(pb.core[i]);
    if (d != 0) return d;
  }
  // 核心相同时：正式版 > 预发布版（1.5.0 > 1.5.0-beta.1）
  if (pa.pre == null && pb.pre == null) return 0;
  if (pa.pre == null) return 1;
  if (pb.pre == null) return -1;
  return _comparePre(pa.pre!, pb.pre!);
}

/// 规范化成 `x.y.z`（去 v 前缀、去构建号、补齐缺失的段）
String normalizeVersion(String v) {
  final p = _parseVersion(v);
  return '${p.core[0]}.${p.core[1]}.${p.core[2]}';
}

class _ParsedVersion {
  final List<int> core; // 恒为 3 段
  final String? pre; // 预发布标识，没有则为 null
  const _ParsedVersion(this.core, this.pre);
}

_ParsedVersion _parseVersion(String raw) {
  var s = raw.trim();
  if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
  // 构建元数据不参与比较：1.5.0+4 和 1.5.0+7 是同一个版本
  final plus = s.indexOf('+');
  if (plus >= 0) s = s.substring(0, plus);
  // 预发布标识
  String? pre;
  final dash = s.indexOf('-');
  if (dash >= 0) {
    pre = s.substring(dash + 1);
    s = s.substring(0, dash);
    if (pre.isEmpty) pre = null;
  }

  final parts = s.split('.');
  final core = <int>[];
  for (var i = 0; i < 3; i++) {
    core.add(i < parts.length ? _leadingInt(parts[i]) : 0);
  }
  return _ParsedVersion(core, pre);
}

/// 取开头的数字：`0beta` → 0，`12` → 12，`x` → 0。
/// 不抛异常是有意的 —— 版本号格式千奇百怪，宁可当成 0 也不能让更新检查崩掉。
int _leadingInt(String s) {
  final m = RegExp(r'^\d+').firstMatch(s.trim());
  return m == null ? 0 : int.parse(m.group(0)!);
}

/// 比预发布部分：逐段比，数字段按数值比、字母段按字典序，数字 < 字母（SemVer 规则）
int _comparePre(String a, String b) {
  final pa = a.split('.');
  final pb = b.split('.');
  final n = pa.length < pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = pa[i];
    final y = pb[i];
    final nx = int.tryParse(x);
    final ny = int.tryParse(y);
    int d;
    if (nx != null && ny != null) {
      d = nx.compareTo(ny);
    } else if (nx != null) {
      d = -1; // 数字段排在字母段前面
    } else if (ny != null) {
      d = 1;
    } else {
      d = x.compareTo(y);
    }
    if (d != 0) return d;
  }
  // 前缀相同：段数多的更新（1.5.0-beta.1 > 1.5.0-beta）
  return pa.length.compareTo(pb.length);
}

// ------------------------------------------------------------ 真正的网络调用

/// 默认的取文本实现：`dart:io` 的 HttpClient（零第三方依赖）。
///
/// 三个必须做对的细节：
/// 1. **User-Agent 一定要给**：GitHub API 对没有 UA 的请求直接 403
/// 2. **走系统代理**：公司/校园网里很常见，`findProxyFromEnvironment`
///    认 `HTTP_PROXY` / `HTTPS_PROXY` 环境变量（国内直连 GitHub 常常不通）
/// 3. **超时短一点**：检查更新是件可有可无的事，不能挂在那儿让用户等
Future<HttpTextResponse> defaultTextFetcher(Uri url) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..findProxy = HttpClient.findProxyFromEnvironment;
  try {
    final req = await client.getUrl(url).timeout(const Duration(seconds: 6));
    req.headers.set('User-Agent', 'code-workbook-update-check');
    req.headers.set('Accept', 'application/vnd.github+json');
    final res = await req.close().timeout(const Duration(seconds: 6));
    final body = await res.transform(utf8.decoder).join();
    return HttpTextResponse(res.statusCode, body);
  } finally {
    // 每次检查新建一个 client，用完就关，不然连接会一直挂着
    client.close(force: true);
  }
}
