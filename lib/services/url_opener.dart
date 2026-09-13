/// 用系统默认程序打开一个外部链接。
///
/// 为什么不用 `url_launcher`：那是个插件，会给 macOS 加 Pod、给 Windows 加
/// 插件注册、改 GeneratedPluginRegistrant —— 而这里要的只是「让浏览器打开一个
/// 网址」，三个平台各一行命令就够了。本项目其余部分（判题、终端、编译器探测）
/// 也全是 `dart:io` 的 `Process`，保持一致。
library;

import 'dart:io';

/// 打开成功返回 true。
///
/// 失败**不抛异常**：调用方是「点了去下载」这种用户操作，打不开就提示一句
/// 「请手动访问 …」，不能让整个界面崩在这儿。
Future<bool> openExternalUrl(String url) async {
  final safe = normalizeExternalUrl(url);
  if (safe == null || !isSafeExternalUrl(safe)) return false;

  try {
    if (Platform.isMacOS) {
      // open 是 macOS 的分发入口，交给 Launch Services 决定用哪个程序
      final r = await Process.run('open', [safe]);
      return r.exitCode == 0;
    }
    if (Platform.isWindows) {
      // ⚠️ Windows 上**不走 shell**。
      //
      // 常见写法是 `cmd /c start "" <url>`，但那条路对本项目**特别危险**：
      // 我们的安装包名字是中文，GitHub 给出来的链接是百分号转义的，里面会出现
      // `%E7%BC%96%E7%BB%83...` 这种片段。cmd 会把 `%...%` 当成变量引用去展开
      // —— 万一被展开成空串，链接就被悄悄改坏了，用户只会看到一个打不开的页面。
      //
      // `rundll32 url.dll,FileProtocolHandler` 直接走 CreateProcess，
      // 不经过任何命令行解析，`%` 和引号都是普通字符。
      // 它失败时再退回 cmd（`Process.run` 传的是参数列表，
      // 除了 cmd 自己的百分号展开之外没有别的解析环节）。
      final r = await Process.run(
          'rundll32', ['url.dll,FileProtocolHandler', safe]);
      if (r.exitCode == 0) return true;
      final fallback = await Process.run('cmd', ['/c', 'start', '', safe]);
      return fallback.exitCode == 0;
    }
    // Linux 桌面环境统一用 xdg-open（GNOME / KDE / XFCE 都认）
    final r = await Process.run('xdg-open', [safe]);
    return r.exitCode == 0;
  } catch (_) {
    // 命令不存在（比如无桌面环境的 Linux）、权限不足等
    return false;
  }
}

/// 规范化链接：把中文这类非 ASCII 字符转义成 `%XX`，顺便统一大小写。
///
/// **这一步是必须的**：本项目挂在 GitHub 上的安装包名字是中文
/// （`编程练习册-Setup.exe`），而 `browser_download_url` 给的到底是原文还是
/// 转义后的形式，两种情况都可能遇到。先过一遍 `Uri` 让它们统一 ——
/// 不统一的话，[isSafeExternalUrl] 会把「带中文的下载链接」判成不合法，
/// 于是我们自己发的安装包永远只能走「手动复制网址」那条退路。
///
/// 解析不了就返回 null。
String? normalizeExternalUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  try {
    final s = uri.toString();
    return s.isEmpty ? null : s;
  } on FormatException {
    return null;
  }
}

/// 只放行「干净的 https 链接」。
///
/// 这个 URL 来自 GitHub API 的响应，正常情况下没问题 —— 但它是**网络来的数据**，
/// 而这串字符最终会被交给 `cmd` / `open` 去执行。中间隔着一层命令行解析，
/// 所以要按「不可信输入」处理：
///
/// - 只允许 `https://`（顺手排除 `file://`、`javascript:`、自定义协议）
/// - 只允许可见 ASCII，且排除 Windows 命令行里有特殊含义的字符
///   （`"` `'` `` ` `` `&` `|` `^` `<` `>` `(` `)`）
///
/// 注意空格与中文会被 [normalizeExternalUrl] 转义成 `%20` / `%XX`，
/// 转义之后是安全的，不会因此被拒。
///
/// 被拒的话界面会退回到「把网址显示出来让用户自己复制」，功能不受影响。
bool isSafeExternalUrl(String url) {
  final s = normalizeExternalUrl(url);
  if (s == null) return false;
  if (!s.startsWith('https://')) return false;
  if (s.length > 2000) return false;
  for (final rune in s.runes) {
    // 可见 ASCII 之外一律拒（控制字符、中文 —— 中文本该已被转义掉，
    // 还剩中文说明 Uri 没能处理它，那就不要冒险）
    if (rune < 0x21 || rune > 0x7E) return false;
    if (_shellSpecials.contains(rune)) return false;
  }
  return true;
}

/// Windows 命令行 / POSIX shell 里有特殊含义的字符，外加引号类。
///
/// 这些出现在 https 链接里也没有正当理由。分两类：
/// - **Uri 转义不掉的**（`&` `;` `(` `)` `'` `$`）：会原样进到命令行，必须自己挡
/// - **Uri 会转义成 %XX 的**（`|` `"` 空格 `<` `>` 等）：转义后已经没有特殊含义，
///   挡不挡都行；留着是为了万一哪天换了调用方式（比如走 shell）还能兜一层
///
/// 顺带说明为什么要有这一层：这里的字符串来自网络，最终又被交给系统命令；
/// 虽然三个平台都走「参数列表」而不是 shell（见 [openExternalUrl]），
/// 但按不可信输入处理是应该的 —— 代价只是极少数畸形链接退回手动复制。
const Set<int> _shellSpecials = {
  0x22, 0x27, 0x60, // " ' `
  0x26, 0x7C, 0x5E, // & | ^
  0x3C, 0x3E, // < >
  0x28, 0x29, // ( )
  0x3B, 0x24, // ; $
};
