import 'dart:io';

import '../models/programming_language.dart';
import 'c_runtime.dart';
import 'python_runtime.dart';

/// 一次外部进程调用的完整描述
class RunSpec {
  final String command;
  final List<String> args;
  final Map<String, String> environment;

  const RunSpec({
    required this.command,
    required this.args,
    this.environment = const {},
  });
}

/// 一门语言的运行时策略：**怎么把学生写的一段源码跑起来**
///
/// 这是「解释型 vs 编译型」的差别收口处。判题引擎只负责
/// 「喂输入 → 读输出 → 比对结果」，不关心语言怎么跑；
/// 语言相关的部分（源码文件名、要不要先编译、错误怎么翻译）全在这里。
///
/// 接入 C/C++ 时的落点：
/// 1. [sourceFileName] 改成 `solution.c`
/// 2. [compileSpec] 返回 `clang solution.c -o solution`（不再返回 null）
/// 3. [explainRuntimeError] 换成 clang/gcc 的报错特征
/// 引擎本身不用动 —— 它会先跑 [compileSpec]，非零退出即判「编译错误」。
abstract class LanguageRuntime {
  const LanguageRuntime();

  ProgrammingLanguage get language;

  /// 判题工作目录里源码文件的文件名（`solution.py` / `solution.c`）
  String get sourceFileName;

  /// 判题前在工作目录里准备辅助文件。默认什么都不做。
  ///
  /// Python 用它在 `sitecustomize.py` 里把 `input()` 的提示挪到 stderr，
  /// 否则 `input("a=")` 的提示文字会混进判题比对的标准输出。
  Future<void> prepare(Directory workDir) async {}

  /// 需要先编译的语言返回编译调用；解释型返回 null（引擎会跳过这一步）。
  ///
  /// 编译失败会直接被判成「编译错误」，不会再去运行。
  RunSpec? compileSpec(Directory workDir, File sourceFile) => null;

  /// 把源码（编译型则是编译产物）跑起来的调用
  RunSpec runSpec(Directory workDir, File sourceFile);

  /// 编译产物的工作目录名（只有编译型语言用）。默认 `solution`。
  String get binaryName => 'solution';

  /// 据 stderr / stdout 判断这是不是「运行时出错」
  bool looksLikeRuntimeError(String stderr, String output) => false;

  /// 把该语言的运行错误翻译成给学生看的中文提示；
  /// 返回 null 表示没有针对性文案，由引擎用通用兜底。
  ///
  /// [exitCode] 为负表示被信号杀掉（C 的段错误就是这样），
  /// 编译型语言要靠它才能说出「程序崩溃」而不是「运行错误」。
  String? explainRuntimeError(String stderr, String output,
          {int exitCode = 0}) =>
      null;

  /// 清洗编译器/解释器的原始输出，去掉学生看不懂的噪音
  /// （临时目录绝对路径、内部符号等）。默认原样返回。
  String cleanDiagnostics(String raw, Directory workDir) => raw;
}

// ------------------------------------------------------------------ Python

/// Python 运行时：解释执行，无需编译
class PythonLanguageRuntime extends LanguageRuntime {
  const PythonLanguageRuntime({this.commandOverride});

  /// 覆盖解释器路径（测试注入 / 设置页自定义）
  final String? commandOverride;

  @override
  ProgrammingLanguage get language => ProgrammingLanguage.python;

  @override
  String get sourceFileName => 'solution.py';

  /// 判题用包装：重写 input()，把提示(prompt)写到 stderr 而非 stdout。
  /// 这样 prompt 不会混入判题比对的标准输出，`a=input("a=")` 这类代码能正常判对。
  static const String _siteCustomize = r'''
import builtins, sys

# 记录原始 input，避免递归
_real_input = builtins.input

def _judge_input(prompt=""):
    # 提示语改写到 stderr（判题比对只看 stdout），真正的 input 读取不变
    if prompt:
        try:
            sys.stderr.write(prompt)
            sys.stderr.flush()
        except Exception:
            pass
    return _real_input("")

builtins.input = _judge_input
''';

  @override
  Future<void> prepare(Directory workDir) async {
    await File('${workDir.path}/sitecustomize.py').writeAsString(_siteCustomize);
  }

  @override
  RunSpec runSpec(Directory workDir, File sourceFile) => RunSpec(
        command: commandOverride ?? PythonRuntime.resolvePythonCommand(),
        args: [...PythonRuntime.utf8Args, sourceFile.absolute.path],
        // 保证 sitecustomize.py 被加载 + 强制 UTF-8
        environment: PythonRuntime.withUtf8Env({'PYTHONPATH': workDir.path}),
      );

  static const List<String> _errorMarkers = [
    'Traceback', 'SyntaxError', 'NameError', 'TypeError', 'ValueError',
    'IndexError', 'KeyError', 'ZeroDivisionError', 'EOFError',
    'IndentationError',
  ];

  @override
  bool looksLikeRuntimeError(String stderr, String output) {
    for (final marker in _errorMarkers) {
      if (stderr.contains(marker) || output.contains(marker)) return true;
    }
    return false;
  }

  @override
  String? explainRuntimeError(String stderr, String output,
      {int exitCode = 0}) {
    final combined = '$stderr\n$output';
    if (combined.contains('SyntaxError')) {
      return '⚠️ 语法错误：代码有拼写或格式问题，通常是少了冒号、括号没闭合或缩进不对。\n\n$combined';
    }
    if (combined.contains('NameError')) {
      return '⚠️ 名称错误：用了一个未定义的变量或函数。可能是拼写错误（试试变量名是否一致）。\n\n$combined';
    }
    if (combined.contains('TypeError')) {
      return '⚠️ 类型错误：对类型不匹配的数据做了操作。比如字符串和数字相加。\n\n$combined';
    }
    if (combined.contains('ValueError')) {
      return '⚠️ 值错误：数值转换/输入格式有问题。比如 int() 空字符串时会报这个。\n\n$combined';
    }
    if (combined.contains('IndexError')) {
      return '⚠️ 索引越界：访问了列表/字符串不存在的下标。下标从 0 开始，最末一个是 len-1。\n\n$combined';
    }
    if (combined.contains('ZeroDivisionError')) {
      return '⚠️ 除零错误：不能除以 0。\n\n$combined';
    }
    if (combined.contains('EOFError')) {
      // 输入读取错误：程序想读更多，但测试用例输入已耗尽。
      // 常见根因：代码用了多个 input()，但题目输入是单行空格分隔（如 `17 5`）。
      return '⚠️ 输入读取错误：程序试图读取比输入更多的内容。\n'
          '这通常是**代码用了多个 input()，但题目的输入是单行、多个数用空格分隔**。\n'
          '\n'
          '✅ 如果是一行多个数，改成一次读取再拆分：\n'
          '> a, b = map(int, input().split())   # 一行读 17 5 两个数\n'
          '\n'
          '💡 也可以先看题目「输入格式」说明，确认是一行还是多行。\n'
          '\n$combined';
    }
    if (combined.contains('IndentationError')) {
      return '⚠️ 缩进错误：Python 用缩进表示代码块，记得统一用空格或制表符（最好统一用 4 个空格）。\n\n$combined';
    }
    return null;
  }
}

// ------------------------------------------------------- 编译型语言公共实现

/// C / C++ 的公共实现
///
/// 两者的判题流程**完全一样**（编译一次 → 所有用例复用产物），
/// 差别只有四处：源码扩展名、编译器、标准版本参数、以及报错文案。
/// 把它们收在这里，加新编译型语言（Rust/Go…）时只要再继承一次。
abstract class CompiledLanguageRuntime extends LanguageRuntime {
  const CompiledLanguageRuntime();

  /// 传给编译器的标准版本参数（`-std=c11` / `-std=c++17`）
  ///
  /// **必须显式指定**：不同编译器/版本的默认标准不一样，
  /// 不锁的话同一份代码可能在这台机器编得过、那台编不过。
  String get stdFlag;

  /// 解析编译器路径（各语言默认编译器不同）
  String resolveCompiler();

  @override
  String get binaryName => 'solution';

  /// 编译命令：<编译器> solution.c -o solution -std=… -O0 -lm
  ///
  /// `-O0`：判题不需要优化，编得越快越好（C++ 尤其明显）。
  /// `-lm`：链接数学库，否则用了 sqrt/pow 的学生会莫名其妙链接失败。
  @override
  RunSpec? compileSpec(Directory workDir, File sourceFile) => RunSpec(
        command: resolveCompiler(),
        args: [
          sourceFile.absolute.path,
          '-o',
          '${workDir.path}${Platform.pathSeparator}$binaryName',
          stdFlag,
          '-O0',
          '-lm',
        ],
      );

  @override
  RunSpec runSpec(Directory workDir, File sourceFile) => RunSpec(
        // 直接跑编译产物；工作目录就是它所在目录
        command: '${workDir.path}${Platform.pathSeparator}$binaryName',
        args: const [],
      );

  /// 编译型语言的运行期错误都走 stderr（没有任何输出反而是异常）
  @override
  bool looksLikeRuntimeError(String stderr, String output) =>
      stderr.trim().isNotEmpty;

  /// 崩溃/除零这类**两种语言共有**的提示；子类可以再补自己特有的
  @override
  String? explainRuntimeError(String stderr, String output,
      {int exitCode = 0}) {
    final combined = '$stderr\n$output';

    // 被信号杀掉（段错误 = SIGSEGV = 11，浮点异常 = 8，中止 = 6）。
    // Shell 那边通常只打印 "Segmentation fault"，学生看不懂。
    if (exitCode < 0 || combined.contains('Segmentation fault')) {
      return '⚠️ 程序崩溃了。${language.displayName} 里最常见的原因是：\n'
          '· 数组下标越界（比如长度为 5 的数组访问了 a[5]）\n'
          '· 用了没初始化的指针，或用完释放之后又访问\n'
          '· 指针指向了非法地址（忘了取地址 & 或忘了分配内存）\n'
          '\n$combined';
    }
    if (combined.contains('Floating point exception')) {
      return '⚠️ 浮点异常，通常是**整数除以 0**。\n\n$combined';
    }
    if (combined.trim().isEmpty) {
      return '⚠️ 程序非正常退出（退出码 $exitCode），但没有输出错误信息。\n'
          '检查一下是不是 return 了非 0 的值，或者中途异常退出。';
    }
    return null; // 有 stderr 但没见过 → 交给通用兜底，把原文显示出来
  }

  /// 清洗编译器输出。
  ///
  /// 原始输出长这样，直接甩给学生全是噪音：
  /// ```
  /// /var/folders/bh/xxx/T/judge_ab12/solution.c:3:5: error: expected ';' after expression
  ///     printf("hi")
  ///     ^
  /// 1 error generated.
  /// ```
  /// 清洗后：
  /// ```
  /// 第 3 行（第 5 列）: error: expected ';' after expression
  ///     printf("hi")
  ///     ^
  /// 1 error generated.
  /// ```
  @override
  String cleanDiagnostics(String raw, Directory workDir) {
    var out = raw;

    // 1) 抹掉临时目录的绝对路径（每次判题都不一样，对学生毫无意义）
    out = out.replaceAll('${workDir.path}${Platform.pathSeparator}', '');
    out = out.replaceAll(workDir.path, '');

    // 2) 行:列 翻成中文（clang/gcc 格式一致：file:line:col:）
    //    扩展名覆盖 C 与 C++ 常见写法
    const ext = r'c|cpp|cc|cxx|h|hpp';
    out = out.replaceAllMapped(
      RegExp('([\\w./\\-]+\\.(?:$ext)):(\\d+):(\\d+):'),
      (m) => '第 ${m.group(2)} 行（第 ${m.group(3)} 列）:',
    );
    // 只带行号的情况（gcc 某些提示、链接错误）
    out = out.replaceAllMapped(
      RegExp('([\\w./\\-]+\\.(?:$ext)):(\\d+):'),
      (m) => '第 ${m.group(2)} 行:',
    );

    // 3) 去掉开头多余空行
    return out.trim();
  }
}

// --------------------------------------------------------------------- C

/// C 运行时：编译型
class CLanguageRuntime extends CompiledLanguageRuntime {
  const CLanguageRuntime({this.commandOverride});

  /// 覆盖编译器路径（测试注入 / 设置页自定义）
  final String? commandOverride;

  @override
  ProgrammingLanguage get language => ProgrammingLanguage.c;

  @override
  String get sourceFileName => 'solution.${CRuntime.extensionFor(language)}';

  @override
  String get stdFlag => '-std=c11';

  @override
  String resolveCompiler() =>
      commandOverride ?? CRuntime.resolveCompiler(language);
}

// ------------------------------------------------------------------- C++

/// C++ 运行时：编译型
///
/// 与 C 共用同一套「编译一次、多用例复用产物」的流程，差别在：
/// 源码扩展名 `.cpp`、编译器 `clang++`/`g++`、标准 `-std=c++17`，
/// 以及 C++ 特有的报错文案（模板报错、链接错误等）。
class CppLanguageRuntime extends CompiledLanguageRuntime {
  const CppLanguageRuntime({this.commandOverride});

  final String? commandOverride;

  @override
  ProgrammingLanguage get language => ProgrammingLanguage.cpp;

  @override
  String get sourceFileName => 'solution.${CRuntime.extensionFor(language)}';

  /// C++17：范围 for、结构化绑定、`std::optional` 这些都在里面，
  /// 对初学者够用又不至于像 C++20 那样各家编译器支持参差。
  @override
  String get stdFlag => '-std=c++17';

  @override
  String resolveCompiler() =>
      commandOverride ?? CRuntime.resolveCompiler(language);

  /// 在「崩溃/除零」这些通用提示之外，补 C++ 特有的
  @override
  String? explainRuntimeError(String stderr, String output,
      {int exitCode = 0}) {
    final generic = super.explainRuntimeError(stderr, output, exitCode: exitCode);
    // 崩溃/非正常退出这类结论明确的，直接用它
    if (generic != null && (exitCode < 0 || stderr.trim().isEmpty)) {
      return generic;
    }

    final combined = '$stderr\n$output';
    if (combined.contains('undefined reference to')) {
      return '⚠️ 链接错误：用到了某个函数/变量，但编译器找不到它的定义。\n'
          '· 函数只写了声明（或原型）没写函数体\n'
          '· 类成员函数在类外定义时忘了写 `类名::`\n'
          '\n$combined';
    }
    if (combined.contains('was not declared in this scope')) {
      return '⚠️ 名字找不到：用了一个当前作用域里不存在的名字。\n'
          '· 拼写错了，或者变量声明在用了之后\n'
          '· 忘了 `#include` 对应的头文件（比如用 `std::string` 要 `#include <string>`）\n'
          '· 忘了写 `std::` 前缀\n'
          '\n$combined';
    }
    if (combined.contains('no matching function') ||
        combined.contains('invalid conversion')) {
      return '⚠️ 类型不匹配：参数的类型和函数要求的对不上。\n'
          '· 检查实参类型与个数（C++ 对类型比 C 严格得多，int 和 double 不会自动互相顶替）\n'
          '\n$combined';
    }
    return generic;
  }
}

// --------------------------------------------------------------- 运行时注册

/// 取某门语言的运行时策略。
///
/// [commandOverride] 供测试注入或设置页自定义路径使用，
/// 只对实现了它的语言（目前是 Python）生效。
LanguageRuntime runtimeFor(
  ProgrammingLanguage language, {
  String? commandOverride,
}) {
  switch (language) {
    case ProgrammingLanguage.python:
      return PythonLanguageRuntime(commandOverride: commandOverride);
    case ProgrammingLanguage.c:
      return CLanguageRuntime(commandOverride: commandOverride);
    case ProgrammingLanguage.cpp:
      return CppLanguageRuntime(commandOverride: commandOverride);
  }
}
