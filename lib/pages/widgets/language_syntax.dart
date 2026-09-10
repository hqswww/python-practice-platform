import '../../models/programming_language.dart';

/// 一门语言的语法高亮描述
///
/// 把「哪些词是关键字/内置函数」和「注释、字符串长什么样」从高亮算法里拆出来。
/// 加语言时只要在这里补一份描述，`highlight()` 本身不用改。
///
/// [pattern] 由词表和片段**组装**而成（不是手写死的整条正则），
/// 避免词表和正则两处各写一遍然后慢慢漂移。
/// 捕获组顺序固定为：`1=注释 2=字符串 3=扩展 4=数字 5=关键字 6=内置`。
class LanguageSyntax {
  /// 关键字（语言保留字）
  final List<String> keywords;

  /// 内置函数 / 常用标准库符号
  final List<String> builtins;

  /// 注释的正则片段（可含多个分支）
  final String comment;

  /// 字符串字面量的正则片段
  final String string;

  /// 额外的高亮类别：Python 是装饰器，C 是预处理指令。
  /// 没有这类语法时留空 —— 会填一个永不匹配的片段占位，保证组号不变。
  final String? extra;

  const LanguageSyntax({
    required this.keywords,
    required this.builtins,
    required this.comment,
    required this.string,
    this.extra,
  });

  /// 永不匹配的占位片段：要求一个字符既是空白又是非空白。
  /// 用它顶住组号，调用方按固定序号取色就不会错位。
  static const String _neverMatch = r'[^\s\S]';

  /// 把词表拼成正则的 `(?:a|b|c)` 片段
  static String _alt(List<String> words) =>
      '(?:${words.map(RegExp.escape).join('|')})';

  /// 组装后的完整高亮正则
  String get pattern => '($comment)'
      '|($string)'
      '|(${extra ?? _neverMatch})'
      r'|(\b\d[\w.]*\b)'
      '|(\\b${_alt(keywords)}\\b)'
      '|(\\b${_alt(builtins)}\\b)';

  /// 取某语言的语法描述。
  ///
  /// C / C++ 目前**还没有题库**，暂时回退到 Python 的描述；
  /// 接入时把这里改成返回 `c` / `cpp` 即可。
  static LanguageSyntax of(ProgrammingLanguage language) => switch (language) {
        ProgrammingLanguage.python => python,
        ProgrammingLanguage.c || ProgrammingLanguage.cpp => python,
      };

  // ------------------------------------------------------------------ Python

  /// Python：`#` 行注释、三引号字符串、`@装饰器`
  ///
  /// 字符串片段里的字面引号用 `\x22`(双) / `\x27`(单) 十六进制转义写，
  /// 免得在 Dart 源码里出现裸引号把字符串提前截断。
  static const LanguageSyntax python = LanguageSyntax(
    keywords: [
      'def', 'return', 'if', 'elif', 'else', 'for', 'while', 'import', 'from',
      'as', 'class', 'try', 'except', 'finally', 'raise', 'with', 'pass',
      'break', 'continue', 'lambda', 'yield', 'global', 'nonlocal', 'and',
      'or', 'not', 'in', 'is', 'None', 'True', 'False', 'del', 'assert',
      'async', 'await',
    ],
    builtins: [
      'print', 'len', 'range', 'int', 'str', 'float', 'bool', 'list', 'dict',
      'tuple', 'set', 'input', 'abs', 'sum', 'min', 'max', 'sorted',
      'reversed', 'enumerate', 'zip', 'map', 'filter', 'type', 'isinstance',
      'open', 'super', 'self', 'round', 'any', 'all', 'repr', 'format',
    ],
    comment: r'#[^\n]*',
    string: r'\x22\x22\x22[\s\S]*?\x22\x22\x22'
        r'|\x27\x27\x27[\s\S]*?\x27\x27\x27'
        r'|\x22(?:[^\x22\\\n]|\\.)*\x22'
        r'|\x27(?:[^\x27\\\n]|\\.)*\x27',
    extra: r'@\w+',
  );

  // --------------------------------------------------------------------- C

  /// C：`//` 与 `/* */` 注释、`#预处理指令`。
  ///
  /// 这一份已经写好但**还没接上**（`of()` 仍返回 Python）——
  /// 等 C 题库就位再切过来，届时请补一组高亮测试。
  static const LanguageSyntax c = LanguageSyntax(
    keywords: [
      'auto', 'break', 'case', 'char', 'const', 'continue', 'default', 'do',
      'double', 'else', 'enum', 'extern', 'float', 'for', 'goto', 'if',
      'inline', 'int', 'long', 'register', 'restrict', 'return', 'short',
      'signed', 'sizeof', 'static', 'struct', 'switch', 'typedef', 'union',
      'unsigned', 'void', 'volatile', 'while',
    ],
    builtins: [
      'printf', 'scanf', 'malloc', 'free', 'calloc', 'realloc', 'strlen',
      'strcpy', 'strcmp', 'strcat', 'memset', 'memcpy', 'fopen', 'fclose',
      'fgets', 'fprintf', 'sprintf', 'exit', 'atoi', 'atof', 'abs', 'pow',
      'sqrt', 'NULL',
    ],
    comment: r'//[^\n]*|/\*[\s\S]*?\*/',
    string: r'\x22(?:[^\x22\\\n]|\\.)*\x22|\x27(?:[^\x27\\\n]|\\.)*\x27',
    extra: r'^\s*#\s*\w+',
  );
}
