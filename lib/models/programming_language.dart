/// 平台支持的编程语言
///
/// 之所以做成枚举而不是散落的字符串：语言贯穿题库、进度存储、判题运行时、
/// 语法高亮、设置项五处，任何一处用裸字符串都会在加语言时漏改。
///
/// 每个语言的 [id] 是**稳定标识**，会被写进：
/// - 进度存储键（`problem_python_101`）
/// - 题库资源目录（`assets/problems/<id>/…`）
/// - 进度导出 JSON 的 `language` 字段
///
/// 所以 [id] 一旦发布就不能改（改了等于让所有用户的进度失联），
/// 而 [displayName] 随便改。
library;

enum ProgrammingLanguage {
  python(
    id: 'python',
    displayName: 'Python',
    fileExtension: 'py',
    compiled: false,
  ),
  c(
    id: 'c',
    displayName: 'C',
    fileExtension: 'c',
    compiled: true,
  ),
  cpp(
    id: 'cpp',
    displayName: 'C++',
    fileExtension: 'cpp',
    compiled: true,
  );

  /// 稳定标识（存储键 / 目录名 / JSON 字段），发布后不可更改
  final String id;

  /// 界面上展示的名字
  final String displayName;

  /// 源码文件扩展名，判题时临时文件名用（`solution.py` / `solution.c`）
  final String fileExtension;

  /// 是否编译型：决定判题是「一次运行」还是「先编译再运行」
  final bool compiled;

  /// 运行面板的标题。
  ///
  /// 刻意放在语言定义里：它是**跟着语言走**的展示文案，而且只有这一处
  /// 需要知道「Python 有 REPL、C 没有」这件事 —— 散到各页面去判断反而容易漏。
  /// - 解释型（Python）：常驻进程、可逐行试，叫「交互终端」
  /// - 编译型（C/C++）：没有 REPL，面板是「编译一次跑一次」，叫「编译运行」
  String get runPanelTitle => compiled ? '编译运行' : '交互终端';

  const ProgrammingLanguage({
    required this.id,
    required this.displayName,
    required this.fileExtension,
    required this.compiled,
  });

  /// 解析存储/JSON 里的语言标识。
  ///
  /// 未知标识回退到 [python] —— 老数据里没有语言字段，
  /// 而加语言前平台上只有 Python，所以这个回退在语义上是正确的。
  static ProgrammingLanguage fromId(String? id) {
    if (id == null || id.isEmpty) return ProgrammingLanguage.python;
    for (final lang in values) {
      if (lang.id == id) return lang;
    }
    return ProgrammingLanguage.python;
  }

  /// 是否为已知的语言标识（用于迁移时判断数据格式）
  static bool isKnownId(String id) => values.any((l) => l.id == id);
}
