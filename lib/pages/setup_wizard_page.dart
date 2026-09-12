import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/problem_repository.dart';
import '../models/programming_language.dart';
import '../services/language_runtime.dart';
import '../services/language_service.dart';
import '../services/runtime_installer.dart';
import '../services/settings_service.dart';
import 'widgets/accent_color_picker.dart';
import 'widgets/responsive.dart';
import 'widgets/runtime_status_row.dart';

/// 首次运行向导。
///
/// 为什么需要它：这个应用判题走**本机环境**，机器上有没有编译器/解释器直接决定
/// 学生能不能做题。没有向导的话，一个刚装好应用的新用户要自己撞上「判题失败 →
/// 去设置页 → 才知道缺东西」这条弯路 —— 而他这时根本不知道「编译器」是个什么。
/// 向导把这件事提前到第一次打开：一次看清三门语言各自的准备情况。
///
/// 这里改的每一项都走 [settings] / [languageService]，和设置页是同一份存储，
/// 所以「向导里设过、设置页里还能改」是天然成立的，不存在两套配置。
class SetupWizardPage extends StatefulWidget {
  const SetupWizardPage({super.key, required this.onFinished});

  /// 向导结束（完成或跳过）后回调，让外层切回主界面
  final VoidCallback onFinished;

  @override
  State<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends State<SetupWizardPage> {
  static const int _lastStep = 3; // 0 欢迎 / 1 运行时 / 2 个性化 / 3 完成

  int _step = 0;

  /// 各语言自检结果。**必须缓存**：checkStatus() 会读文件系统、扫 PATH，
  /// 每帧重算就是每帧几十次 stat。
  final Map<ProgrammingLanguage, RuntimeStatus> _statuses = {};

  /// 各语言的手动路径输入框
  final Map<ProgrammingLanguage, TextEditingController> _pathControllers = {
    for (final lang in availableLanguages)
      lang: TextEditingController(text: settings.runtimePath(lang)),
  };

  /// 正在安装的语言（null = 没在装）
  ProgrammingLanguage? _installing;

  /// 安装脚本的输出，显示给用户看进度
  final List<String> _installLog = [];

  @override
  void initState() {
    super.initState();
    _detectAll();
  }

  @override
  void dispose() {
    for (final c in _pathControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _detectAll() {
    for (final lang in availableLanguages) {
      _detect(lang);
    }
  }

  void _detect(ProgrammingLanguage lang) {
    _statuses[lang] = runtimeFor(lang).checkStatus();
  }

  /// 有没有还缺东西的语言 —— 决定「完成」那一步说什么
  List<ProgrammingLanguage> get _missing => [
        for (final lang in availableLanguages)
          if (_statuses[lang]?.available == false) lang,
      ];

  Future<void> _savePath(ProgrammingLanguage lang) async {
    await settings.setRuntimePath(lang, _pathControllers[lang]!.text);
    setState(() => _detect(lang));
  }

  /// 一键安装（目前只有 Windows 有安装脚本）
  Future<void> _autoInstall(ProgrammingLanguage lang) async {
    final script = RuntimeInstaller.findScript();
    if (script == null) return;

    setState(() {
      _installing = lang;
      _installLog
        ..clear()
        ..add('正在运行 ${script.path}');
    });

    int code;
    try {
      code = await RuntimeInstaller.runScript(
        script,
        onOutput: (line) {
          if (!mounted) return;
          setState(() => _installLog.add(line));
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _installing = null;
        _installLog.add('启动安装脚本失败：$e');
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _installing = null;
      // **重新检测**：装完不重测的话，用户看着「未找到编译器」会以为白装了。
      // 注意 CRuntime 里已经把脚本的默认安装位置列为兜底路径，所以即使
      // 当前进程读不到新的 PATH，这里也能立刻认出来。
      _detect(lang);
      _installLog.add(code == 0 ? '安装脚本执行完毕。' : '安装脚本退出码：$code');
    });
  }

  Future<void> _openUrl(String url) async {
    final ok = await RuntimeInstaller.openExternal(url);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('打不开浏览器，请手动访问：$url')),
    );
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
  }

  Future<void> _finish() async {
    await settings.setSetupWizardDone(true);
    widget.onFinished();
  }

  void _next() {
    if (_step >= _lastStep) {
      _finish();
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: MaxWidthBody(
          maxWidth: ContentWidth.article,
          child: Column(
            children: [
              _buildProgress(),
              Expanded(child: SingleChildScrollView(child: _buildStep())),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 进度

  static const List<String> _stepTitles = ['欢迎', '运行环境', '个性化', '完成'];

  Widget _buildProgress() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          for (var i = 0; i < _stepTitles.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= _step ? scheme.primary : scheme.outlineVariant,
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= _step ? scheme.primary : scheme.surfaceContainerHighest,
                  ),
                  child: i < _step
                      ? Icon(Icons.check, size: 15, color: scheme.onPrimary)
                      : Text('${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: i == _step
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          )),
                ),
                const SizedBox(height: 4),
                Text(_stepTitles[i],
                    style: TextStyle(
                      fontSize: 11,
                      color: i <= _step ? scheme.primary : scheme.onSurfaceVariant,
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ 各步

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildWelcome();
      case 1:
        return _buildRuntime();
      case 2:
        return _buildPersonalize();
      default:
        return _buildDone();
    }
  }

  Widget _heading(String title, String subtitle) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: TextStyle(fontSize: 14, height: 1.7, color: Colors.grey[700])),
          ],
        ),
      );

  Widget _buildWelcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          '欢迎使用编程练习册 👋',
          '这是一个**完全离线**的编程练习工具：题库、判题、进度全在本机，不需要注册也不用联网。\n\n'
              '判题用的是你电脑上的运行环境 —— Python 要解释器，C / C++ 要编译器。'
              '下一步会检查这些装好了没有，缺的话可以现场装上。',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.lightbulb_outline,
                        size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('这三步都可以跳过',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '所有设置之后都能在「设置」页里改，随时可以重新跑这个向导。'
                    '现在不想管，直接点「下一步」到最后就行。',
                    style: TextStyle(fontSize: 13, height: 1.7, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRuntime() {
    final missing = _missing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          '检查运行环境',
          missing.isEmpty
              ? '三门语言的环境都齐了，可以直接开始。'
              : '有 ${missing.length} 项还没准备好。缺的那门语言暂时做不了题，'
                  '但其它语言不受影响 —— 也可以用「跳过」。',
        ),
        for (final lang in availableLanguages)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
            child: _buildLanguageCard(lang),
          ),
      ],
    );
  }

  Widget _buildLanguageCard(ProgrammingLanguage lang) {
    final st = _statuses[lang];
    final busy = _installing == lang;
    final anyBusy = _installing != null;
    final isCompiler = lang.compiled;
    final guidance = RuntimeInstaller.guidanceFor(lang);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(lang.displayName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text(isCompiler ? '编译器' : '解释器',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const Spacer(),
                IconButton(
                  tooltip: '重新检测',
                  visualDensity: VisualDensity.compact,
                  onPressed: anyBusy ? null : () => setState(() => _detect(lang)),
                  icon: const Icon(Icons.refresh, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            RuntimeStatusRow(language: lang, status: st),

            if (busy) ...[
              const SizedBox(height: 12),
              Row(children: [
                const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                const Expanded(child: Text('正在安装…')),
              ]),
              if (_installLog.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  height: 132,
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView(
                    reverse: true,
                    children: [
                      for (final line in _installLog)
                        Text(line,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 11, height: 1.5)),
                    ],
                  ),
                ),
              ],
            ] else if (st?.available == false) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (RuntimeInstaller.canAutoInstall)
                    FilledButton.icon(
                      onPressed: anyBusy ? null : () => _autoInstall(lang),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('一键安装'),
                    ),
                  if (guidance.url != null)
                    OutlinedButton.icon(
                      onPressed: () => _openUrl(guidance.url!),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(guidance.urlLabel ?? '打开下载页'),
                    ),
                  if (guidance.command != null)
                    OutlinedButton.icon(
                      onPressed: () => _copy(guidance.command!),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('复制安装命令'),
                    ),
                ],
              ),
              if (guidance.command != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  guidance.command!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ],

            // 手动指定路径：无论检测结果如何都留着 —— 装在非常规位置、
            // 或者装完 PATH 没刷新时，这是唯一的出路。
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              title: const Text('手动指定路径', style: TextStyle(fontSize: 13)),
              children: [
                TextField(
                  controller: _pathControllers[lang],
                  decoration: InputDecoration(
                    hintText: isCompiler
                        ? r'例如 C:\mingw64\bin\gcc.exe'
                        : r'例如 /usr/bin/python3',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _savePath(lang),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: () => _savePath(lang),
                    child: const Text('保存并重新检测'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalize() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('按你的喜好调一下', '这几项之后都能在「设置」页改。'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('主题色', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              const AccentColorPicker(),
              const SizedBox(height: 24),
              _fontSizeTile(),
              const SizedBox(height: 8),
              _indentTile(),
              const SizedBox(height: 24),
              const Text('打开时默认学习哪门语言',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: languageService,
                builder: (context, _) => SegmentedButton<ProgrammingLanguage>(
                  segments: [
                    for (final lang in availableLanguages)
                      ButtonSegment(
                          value: lang, label: Text(lang.displayName)),
                  ],
                  selected: {languageService.value},
                  onSelectionChanged: (s) => languageService.select(s.first),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fontSizeTile() {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('代码字号', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${settings.editorFontSize} px',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ]),
          Slider(
            value: settings.editorFontSize.toDouble(),
            min: 12,
            max: 22,
            divisions: 10,
            label: '${settings.editorFontSize}',
            onChanged: (v) => settings.setEditorFontSize(v.round()),
          ),
        ],
      ),
    );
  }

  Widget _indentTile() {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Row(children: [
        const Text('缩进宽度', style: TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 2, label: Text('2 空格')),
            ButtonSegment(value: 4, label: Text('4 空格')),
          ],
          selected: {settings.editorIndentWidth},
          onSelectionChanged: (s) => settings.setEditorIndentWidth(s.first),
        ),
      ]),
    );
  }

  Widget _buildDone() {
    final missing = _missing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          missing.isEmpty ? '一切就绪 🎉' : '可以开始了',
          missing.isEmpty
              ? '三门语言的环境都检测通过，去「练习」页挑一道题试试吧。'
              : '${missing.map((l) => l.displayName).join('、')} 暂时还缺运行环境，'
                  '做这几门语言时会提示你。其它语言现在就能用。',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('几个要点',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Text(
                    '· 顶栏可以切换 Python / C / C++，三门口味各自独立记进度\n'
                    '· 写完代码点「运行并判题」，对了就会自动记录进度和成就\n'
                    '· 卡住时先看题目的「提示」，再看「教程」分区\n'
                    '· 缺环境、想改设置，随时去「设置」页，那里能重新跑一遍本向导',
                    style: TextStyle(fontSize: 13, height: 1.9, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- 底部栏

  Widget _buildBottomBar() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (_step > 0)
            TextButton(onPressed: _back, child: const Text('上一步'))
          else
            TextButton(
              onPressed: () => _finish(),
              child: const Text('跳过'),
            ),
          const Spacer(),
          FilledButton(
            onPressed: _installing != null ? null : _next,
            child: Text(_step >= _lastStep ? '开始使用' : '下一步'),
          ),
        ],
      ),
    );
  }
}

/// 首次运行判断的落点。
///
/// 单独抽出来是为了让测试能直接问「这台机器该不该显示向导」，
/// 而不必去 build 整个 App。
bool shouldShowSetupWizard() => !settings.setupWizardDone;
