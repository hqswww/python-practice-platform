import 'dart:io';

import '../models/programming_language.dart';
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

  /// 据 stderr / stdout 判断这是不是「运行时出错」
  bool looksLikeRuntimeError(String stderr, String output) => false;

  /// 把该语言的运行错误翻译成给学生看的中文提示；
  /// 返回 null 表示没有针对性文案，由引擎用通用兜底。
  String? explainRuntimeError(String stderr, String output) => null;
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
  String? explainRuntimeError(String stderr, String output) {
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
    case ProgrammingLanguage.cpp:
      // 接入时的落点：在这里返回 CppLanguageRuntime / CLanguageRuntime
      throw UnsupportedError(
        '${language.displayName} 的运行时尚未接入（题库也还没做）',
      );
  }
}
