/// 源码语法要求检查
///
/// ## 为什么需要这个文件
///
/// 判题只比对 stdout，可有些题目的输出**用不用那个语法完全一样**。
/// 真实案例（题库 901「用指针读取变量的值」）：期望输出是同一个数打两遍，
/// 于是下面这段**一个指针都没有**的代码照样判过：
///
/// ```c
/// int a;
/// scanf("%d", &a);
/// int b = a;                     // 普通拷贝，不是指针
/// printf("%d\n%d", a, b);        // 输出与 *p 版本一字不差
/// ```
///
/// 这不是判题引擎写错了，是「只比对输出」这种判题方式的固有边界 ——
/// 输出层面无从分辨，就只能到源码层面补一道检查。
///
/// ## 检查是启发式的，边界要说清楚
///
/// 这里是**关键字级别的文本分析**，不是编译器级的语义分析：
///
/// - **挡得住**：压根没用指针；声明了指针却从不使用（`int *p = &n;` 之后
///   仍然 `printf("%d", n)`）；只拿指针取了一个元素就改用数组下标。
/// - **挡不住**：蓄意伪装（例如声明指针后写一句永不会执行到的 `*p;`）。
///   要彻底堵住需要「只写函数 + 判题时注入自己的 main」那种题面改造，
///   那是另一件事，不在这个文件的范围里。
///
/// 每个检查都必须在题库参考答案上自证成立 —— `test/source_check_test.dart`
/// 会逐个跑一遍，避免出现「照抄参考答案还判不过」这种最坏的情况。
///
/// **入参约定**：所有检查收到的都是**已去掉注释和字符串字面量**的源码
/// （见 `LanguageRuntime.stripCommentsAndLiterals`）。这一步不能省：
/// 注释里写一句 `// int *p = &n;` 就会骗过最朴素的文本匹配，
/// 而这恰恰是最常见的误判来源。
library;

import '../models/problem.dart';

/// 一个具名检查：给一段（已清洗的）源码，判断它是否用上了某个语法
typedef SourceCheck = bool Function(String code);

/// 全部可用的检查。题库 JSON 里的 `check` 字段只能是这里的键。
///
/// 名字写成 `领域.动作` 而不是 `c_` / `cpp_` 前缀：指针在 C 和 C++ 里
/// 是同一套语法，两门语言共用同一个检查，没必要各写一份。
const Map<String, SourceCheck> kSourceChecks = {
  'pointer.use': pointerUse,
  'pointer.walk': pointerWalk,
  'reference.use': referenceUse,
};

/// 判断这批要求在 [code] 里有没有没被满足的。
///
/// [code] 必须是 `LanguageRuntime.stripCommentsAndLiterals` 处理过的源码。
/// 返回空列表 = 全部满足（或压根没有要求）。
///
/// 未知的检查名按「满足」处理。理由：题库里写错一个名字，代价应该是
/// **测试挂掉**（`unknownSourceChecks` 专门给测试用），而不是让所有学生
/// 莫名其妙判不过 —— 前者当场就能发现，后者要等用户来报。
List<SourceRequirement> unmetSourceRequirements(
  List<SourceRequirement> requirements,
  String code,
) {
  final unmet = <SourceRequirement>[];
  for (final req in requirements) {
    final check = kSourceChecks[req.check];
    if (check == null) continue; // 见上面的说明
    if (!check(code)) unmet.add(req);
  }
  return unmet;
}

/// 题库里引用了但**不存在**的检查名（给题库自检测试用的）。
///
/// 单独抽出来是为了让「题库写错检查名」这件事只在测试里暴露，不影响用户。
List<String> unknownSourceChecks(List<SourceRequirement> requirements) => [
      for (final r in requirements)
        if (!kSourceChecks.containsKey(r.check)) r.check,
    ];

// --------------------------------------------------------------- 具体检查

/// 指针**真的被用上了**：声明了指针变量，并且通过它访问过内存。
///
/// 判定分两步 —— 只做第一步（看有没有 `*`）是不够的，
/// `int *p = &n;` 里就有一个 `*`，可是它只是声明，指针本身从没被用过：
///
/// 1. 从声明里取出所有指针变量名（`int *p` / `char **argv` / `struct Node *next`）
/// 2. 其中**任意一个**满足任一「使用」形式即算通过：
///    - 解引用 `*p`（要排除 `int *p` 这种声明和 `a * p` 这种乘法，见 [hasDereference]）
///    - 下标 `p[i]`
///    - 步进 `p++` / `++p` / `p--` / `p += 1`
///    - 指针算术取值 `*(p + i)`
///
/// ⚠️ 少了最后一条就会误判：题库 806 的参考答案写的是 `*(p + i)`，
/// 它既不是 `*p`（星号后面跟的是括号）也不是 `p[i]` ——
/// 漏了这一种，连参考答案都判不过（这个 bug 真发生过，被题库自检测试抓住）。
bool pointerUse(String code) {
  final names = _pointerNames(code);
  if (names.isEmpty) return false;
  for (final name in names) {
    if (hasDereference(code, name)) return true;
    if (hasSubscript(code, name)) return true;
    if (hasPointerStep(code, name)) return true;
    if (hasPointerArithmeticFetch(code, name)) return true;
  }
  return false;
}

/// 指针**被用来逐元素遍历**了 —— [pointerUse] 的加强版。
///
/// 为什么要单独一个：`int *p = a; int max = p[0];` 然后循环里全用 `a[i]`，
/// 这是"取了一个元素就走人"，不算遍历，可它满足 [pointerUse]。
/// 用指针遍历的题（如 904「用指针遍历数组求和」）需要更严的判据：
///
/// - 指针做了步进（`p++` / `p += 1` / `++p` …），或
/// - 指针取值出现**两次以上**（`p[0]` + `p[i]`，或循环里多次 `*(p + i)`）
bool pointerWalk(String code) {
  for (final name in _pointerNames(code)) {
    if (hasPointerStep(code, name)) return true;
    // 出现两次以上才算「遍历」：只出现一次的是「取了一个元素」
    if (_matches(_subscriptPattern, code, name).length >= 2) return true;
    if (hasPointerArithmeticFetch(code, name)) return true;
  }
  return false;
}

/// 引用**真的被用上了**：声明了引用，并且这个名字在别处还出现过。
///
/// 为什么用「出现过两次以上」而不是找某个具体形式：引用的用法就是直接写名字
/// （`r = r * 3;`），文本上跟普通变量没有区别 —— 这也正是引用「是别名不是副本」
/// 这个知识点的本质。能查的只有「声明之后有没有真的用它」。
///
/// 声明处本身算一次，所以 ≥2 才说明至少用了一次。
bool referenceUse(String code) {
  for (final name in _referenceNames(code)) {
    if (RegExp('\\b${RegExp.escape(name)}\\b').allMatches(code).length >= 2) {
      return true;
    }
  }
  return false;
}

// ----------------------------------------------------------- 语法细节判定

/// 代码里有没有对 [name] 这个标识符的**解引用**。
///
/// 难点在于 `*` 有三种完全不同的含义，光看 `*name` 是分不出来的：
///
/// | 写法 | 含义 | 该不该算 |
/// |------|------|---------|
/// | `int *p` | 声明 | ❌ |
/// | `a * p`  | 乘法 | ❌ |
/// | `*p`     | 解引用 | ✅ |
///
/// 判据：看 `*` **前面那个字符**。
/// - 前面是运算符、分隔符、括号、行首 → 一元运算符，是解引用
///   （`; *p = 1`、`= *p`、`f(*p)`、`(*p)`、`[i] *p`…）
/// - 前面是**标识符的结尾**（字母数字下划线）→ 要看那个标识符是什么：
///   - 是 `return` / `case` / `sizeof` 这类**后面可以跟表达式**的关键字 → 解引用
///     （不特判的话 `return *p;` 会被当成乘法而漏判）
///   - 否则（`int`、`a`、`2`…）→ 声明或乘法，不算
///
/// 类型转换 `(int*)p` 走的是第二个分支（`*` 前是 `t`）→ 不算解引用，正确。
///
/// [name] 必须是已经从声明里取出来的指针变量名 —— 有了这个前提，
/// `(a) * p` 这种「括号后跟乘法」的歧义就不再重要（乘一个指针本身就是类型错误）。
bool hasDereference(String code, String name) {
  final pattern = RegExp('\\*\\s*${RegExp.escape(name)}\\b');
  for (final m in pattern.allMatches(code)) {
    var i = m.start - 1;
    while (i >= 0 && _isWhitespace(code.codeUnitAt(i))) {
      i--;
    }
    if (i < 0) return true; // 源码开头
    if (!_isWordChar(code.codeUnitAt(i))) return true; // 前面是运算符/分隔符
    // 前面是标识符：只有「后面能跟表达式」的关键字才算解引用
    if (_unaryKeywords.contains(_wordEndingAt(code, i))) return true;
  }
  return false;
}

/// 下标访问 `p[i]` / `p [i]`
bool hasSubscript(String code, String name) =>
    _matches(_subscriptPattern, code, name).isNotEmpty;

bool hasPointerStep(String code, String name) =>
    _matches(_stepPattern, code, name).isNotEmpty;

/// `*(p + i)` —— 指针算术取值（`p[i]` 的另一种写法）
bool hasPointerArithmeticFetch(String code, String name) =>
    _matches(_arithFetchPattern, code, name).isNotEmpty;

final RegExp _subscriptPattern = RegExp(r'\b%N%\b\s*\[');

final RegExp _stepPattern =
    RegExp(r'(?:\+\+|--)\s*%N%|\b%N%\b\s*(?:\+\+|--|\+=|-=)');

final RegExp _arithFetchPattern = RegExp(r'\*\s*\(\s*%N%\b');

/// 把 [template] 里的 `%N%` 换成转义后的 [name] 再匹配
Iterable<RegExpMatch> _matches(RegExp template, String code, String name) =>
    RegExp(template.pattern.replaceAll('%N%', RegExp.escape(name)))
        .allMatches(code);

/// 取出源码里所有指针变量的名字。
///
/// 只认**看起来像类型名的东西**后面跟 `*`，否则 `a * b` 这种乘法会被
/// 误当成 `a` 类型、`b` 指针。类型名的白名单见 [_typeWord]。
List<String> _pointerNames(String code) => _declaredNames(code, _pointerDecl);

/// 取出源码里所有引用变量的名字（`int& r`）。
List<String> _referenceNames(String code) => _declaredNames(code, _referenceDecl);

List<String> _declaredNames(String code, RegExp decl) {
  final names = <String>{};
  for (final m in decl.allMatches(code)) {
    final name = m.group(1);
    if (name != null && name.isNotEmpty) names.add(name);
  }
  return names.toList();
}

/// 基础类型名（含 `size_t` 这类 `_t` 结尾的、以及 `FILE`/`Node` 这类首字母
/// 大写的自定义类型）。**小写的自定义类型名认不出来** —— 这是启发式的
/// 代价：多认就必然把 `a * b` 也认成声明，那比漏认危险得多
/// （漏认只是少挡一种写法，误认会让乘法被当成指针声明）。
const String _typeWord =
    r'(?:void|int|char|short|long|float|double|bool|auto|size_t|wchar_t|'
    r'FILE|[A-Z]\w*|\w+_t)';

final RegExp _pointerDecl =
    RegExp('\\b$_typeWord\\s*(?:const\\s+)?\\*+\\s*([A-Za-z_]\\w*)');

final RegExp _referenceDecl =
    RegExp('\\b$_typeWord\\s*(?:const\\s+)?&\\s*([A-Za-z_]\\w*)');

/// 后面可以直接跟一个表达式的关键字：这些词后面出现 `*x` 是一元解引用。
const Set<String> _unaryKeywords = {
  'return', 'case', 'sizeof', 'else', 'do', 'while', 'if', 'switch',
  'goto', 'throw', 'new', 'delete', 'and', 'or', 'not',
  'co_return', 'co_await', 'co_yield',
};

bool _isWhitespace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

bool _isWordChar(int c) =>
    (c >= 0x30 && c <= 0x39) || // 0-9
    (c >= 0x41 && c <= 0x5A) || // A-Z
    (c >= 0x61 && c <= 0x7A) || // a-z
    c == 0x5F; // _

/// 取出源码里 [end] 位置（含）结束的那个标识符
String _wordEndingAt(String code, int end) {
  var start = end;
  while (start > 0 && _isWordChar(code.codeUnitAt(start - 1))) {
    start--;
  }
  return code.substring(start, end + 1);
}
