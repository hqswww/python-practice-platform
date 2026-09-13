import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/models/problem.dart';
import 'package:python_practice/models/programming_language.dart';
import 'package:python_practice/services/language_runtime.dart';
import 'package:python_practice/services/source_check.dart';

/// 源码语法要求检查（source_check.dart）。
///
/// 这套检查要解决的是一个具体、已发生的漏洞：题库 901「用指针读取变量的值」
/// 的期望输出是同一个数打两遍，于是**一个指针都没有**的代码照样判过。
///
/// ⚠️ 这些检查是**启发式**的文本分析，所以每条规则都要把
/// 「该算」「不该算」两面都钉住 —— 只测正面会让误判悄悄溜过去，
/// 而误判的代价是学生照抄参考答案都判不过。
void main() {
  const cLike = SourceStripper.cLike;
  const python = SourceStripper.python;

  group('注释与字面量清洗：C / C++', () {
    test('行注释被去掉', () {
      expect(cLike('int a; // int *p = &a;\nprintf("%d", a);'),
          isNot(contains('*p')));
    });

    test('块注释被去掉，且不吞掉后面的代码', () {
      const code = 'int *p = &n; /* 注释里写 *p */ printf("%d", *p);';
      final out = cLike(code);
      expect(out, isNot(contains('注释里写')));
      expect(out, contains('printf'));
      expect(out, contains('*p'), reason: '注释之后的真实解引用必须留下');
    });

    test('未闭合的块注释不会让清洗崩掉', () {
      expect(() => cLike('int a; /* 没关掉'), returnsNormally);
    });

    test('字符串字面量被去掉（里面的星号不算代码）', () {
      expect(cLike('printf("\\*p 是解引用");'), isNot(contains('*p')));
    });

    test('字符串里的转义引号不会提前结束', () {
      final out = cLike(r'printf("他说\"*p\"好"); int x = 1;');
      expect(out, contains('int x = 1'), reason: '转义序列处理错会把后面的代码全吃掉');
    });

    test('字符字面量被去掉', () {
      final out = cLike("char c = '*'; int y = 2;");
      expect(out, isNot(contains('*')));
      expect(out, contains('int y = 2'));
    });

    test("C++14 的数字分隔符 1'000 不会被当成字符字面量", () {
      // 不特判的话 `'` 会把 `'000'` 当字符字面量，把中间的代码一起删掉
      final out = cLike("int n = 1'000'000; int *p = &n; *p = 2;");
      expect(out, contains('*p'), reason: '数字分隔符吃掉了后面的代码');
      expect(out, contains("1'000'000"),
          reason: '数字本身应原样保留，不然学生的代码看着像被改了');
    });

    test('换行被保留（行号不能错位）', () {
      const code = 'int a;\n/* 注释\n   跨两行 */\nint b;';
      expect('\n'.allMatches(cLike(code)).length,
          '\n'.allMatches(code).length);
    });
  });

  group('注释与字面量清洗：Python', () {
    test('# 注释被去掉', () {
      expect(python('x = 1  # print(*p)'), isNot(contains('*p')));
    });

    test('三引号字符串（文档字符串）被去掉', () {
      final out = python('"""文档里提到 *p"""\nx = 1');
      expect(out, isNot(contains('*p')));
      expect(out, contains('x = 1'));
    });

    test('单引号三引号也能处理', () {
      expect(python("'''*p'''\ny = 2"), isNot(contains('*p')));
    });

    test('普通字符串里的内容被去掉', () {
      expect(python('print("*p")'), isNot(contains('*p')));
    });

    test('字符串里的转义引号不会提前结束', () {
      final out = python(r'print("他说\"*p\"好"); x = 1');
      expect(out, contains('x = 1'));
    });
  });

  group('是不是「解引用」——同一颗星号有三种含义', () {
    test('声明 int *p 不算解引用', () {
      expect(hasDereference('int *p;', 'p'), isFalse);
    });

    test('声明带初始化 int *p = &n; 也不算', () {
      expect(hasDereference('int *p = &n;', 'p'), isFalse);
    });

    test('乘法 a * p 不算', () {
      expect(hasDereference('c = a * p;', 'p'), isFalse);
    });

    test('常量在前面的乘法 2 * p 不算', () {
      expect(hasDereference('c = 2 * p;', 'p'), isFalse);
    });

    test('等号右边 / 函数实参 / 行首 / 括号里的 *p 算', () {
      expect(hasDereference('c = *p;', 'p'), isTrue);
      expect(hasDereference('printf("%d", *p);', 'p'), isTrue);
      expect(hasDereference('*p = 1;', 'p'), isTrue);
      expect(hasDereference('f(*p);', 'p'), isTrue);
      expect(hasDereference('if ((*p) > 0) {}', 'p'), isTrue);
    });

    test('return *p 算 —— 这是最容易漏的一个', () {
      // `return` 以字母结尾，按「前面是标识符就不算」的规则会被误杀
      expect(hasDereference('return *p;', 'p'), isTrue);
    });

    test('类型转换 (int*)p 不算解引用', () {
      expect(hasDereference('q = (int*)p;', 'p'), isFalse);
    });

    test('类型转换 (char *)p 不算解引用', () {
      expect(hasDereference('q = (char *)p;', 'p'), isFalse);
    });

    test('同名的另一个变量不会被误算（按整词匹配）', () {
      expect(hasDereference('int p2 = 1;', 'p'), isFalse);
    });
  });

  group('检查一：pointer.use（真的用上了指针）', () {
    test('完全没用指针 → 不通过（这就是上报的那个漏洞）', () {
      const cheat = 'int a; scanf("%d", &a); int b = a; printf("%d\\n%d", a, b);';
      expect(pointerUse(cLike(cheat)), isFalse);
    });

    test('注释掉的那行指针代码救不了它（必须先清洗）', () {
      const cheat = '''
#include <stdio.h>
int main(void) {
    int a;
    //int *p = &a;
    scanf("%d", &a);
    int b = a;
    //printf("%d\\n%d", a, *p);
    printf("%d\\n%d", a, b);
    return 0;
}
''';
      // 不清洗的话，注释里的 `*p` 会让它蒙混过关
      expect(pointerUse(cheat), isTrue, reason: '前提：原文里确实有 *p，所以必须清洗');
      expect(pointerUse(cLike(cheat)), isFalse, reason: '清洗后应当判不过');
    });

    test('声明了指针却从没用它 → 不通过', () {
      expect(pointerUse('int n; int *p = &n; printf("%d\\n", n);'), isFalse);
    });

    test('真的解引用了 → 通过', () {
      expect(pointerUse('int n; int *p = &n; printf("%d\\n", *p);'), isTrue);
    });

    test('通过下标 p[i] 使用 → 通过', () {
      expect(pointerUse('int *p = a; int x = p[0];'), isTrue);
    });

    test('通过步进 p++ 使用 → 通过', () {
      expect(pointerUse('int *p = a; for (; p < a + n; p++) s += *p;'), isTrue);
    });

    test('函数参数里的指针也算声明', () {
      const code = 'void swap(int *x, int *y) { int t = *x; *x = *y; *y = t; }';
      expect(pointerUse(code), isTrue);
    });

    test('指针参数从没用过 → 不通过', () {
      expect(
          pointerUse('void f(int *x) { int t = 1; } int main() { return 0; }'),
          isFalse);
    });

    test('双指针 char **argv 能认出来', () {
      expect(pointerUse('int main(int argc, char **argv) { putchar(**argv); }'),
          isTrue);
    });

    test('乘法不会被当成指针声明', () {
      // `a * b` 里的 `a` 不是类型名，不能把 b 当成指针变量
      expect(pointerUse('int c = a * b; int d = c * 2;'), isFalse);
    });
  });

  group('检查二：pointer.walk（用指针遍历，而不只是取一个元素）', () {
    test('只取了一个元素、其余用数组下标 → 不通过', () {
      const code = '''
int *p = a;
int max = p[0];
for (int i = 1; i < n; i++) { if (a[i] > max) max = a[i]; }''';
      expect(pointerUse(code), isTrue, reason: '前提：它确实用到了指针');
      expect(pointerWalk(code), isFalse, reason: '但没有用它遍历');
    });

    test('p[i] 出现在循环里两次及以上 → 通过', () {
      const code = '''
int *p = a;
int max = p[0];
for (int i = 1; i < n; i++) { if (p[i] > max) max = p[i]; }''';
      expect(pointerWalk(code), isTrue);
    });

    test('p++ 步进 → 通过', () {
      expect(
          pointerWalk('for (int *p = a; p < a + n; p++) sum += *p;'), isTrue);
    });

    test('*(p + i) 形式 → 通过', () {
      expect(
          pointerWalk(
              'int *p = a; for (int i = 0; i < n; i++) s += *(p + i);'),
          isTrue);
    });
  });

  group('检查三：reference.use（C++ 引用真的被用了）', () {
    test('声明引用并改它 → 通过', () {
      expect(referenceUse('int n; int& r = n; r = r * 3;'), isTrue);
    });

    test('声明了引用但只碰普通变量 → 不通过', () {
      expect(referenceUse('int n; int& r = n; n = n * 3;'), isFalse);
    });

    test('完全没用引用 → 不通过', () {
      expect(referenceUse('int n; n = n * 3;'), isFalse);
    });

    test('引用参数在函数体里被读写 → 通过', () {
      const code = 'void swapByRef(int& x, int& y) { int t = x; x = y; y = t; }';
      expect(referenceUse(code), isTrue);
    });

    test('逻辑与 && 不会被当成引用声明', () {
      expect(referenceUse('bool ok = a && b;'), isFalse);
    });

    test('按位与 a & b 不会被当成引用声明', () {
      // `a` 不是类型名，所以 `a & b` 不构成「声明了一个引用 b」
      expect(referenceUse('int c = a & b;'), isFalse);
    });

    test('取地址 &n 不会被当成引用声明', () {
      expect(referenceUse('int *p = &n; printf("%d", *p);'), isFalse);
    });
  });

  group('汇总：unmetSourceRequirements', () {
    const req = SourceRequirement(
      check: 'pointer.use',
      label: '用指针',
      hint: '改用 *p',
    );

    test('没有要求 → 空', () {
      expect(unmetSourceRequirements(const [], 'int a;'), isEmpty);
    });

    test('满足 → 空', () {
      expect(
          unmetSourceRequirements(const [req], 'int *p = &n; *p = 1;'), isEmpty);
    });

    test('不满足 → 原样返回（拿去展示给学生）', () {
      final unmet = unmetSourceRequirements(const [req], 'int a;');
      expect(unmet, hasLength(1));
      expect(unmet.first.label, '用指针');
    });

    test('未知检查名按「满足」处理，不能因此判学生不过', () {
      // 题库里写错了名字 —— 代价应该是测试挂掉（见 unknownSourceChecks），
      // 而不是让所有学生莫名其妙判不过
      const bad = SourceRequirement(check: 'no.such', label: 'x', hint: 'y');
      expect(unmetSourceRequirements(const [bad], 'anything'), isEmpty);
    });

    test('unknownSourceChecks 能把写错的名字挑出来', () {
      const bad = SourceRequirement(check: 'no.such', label: 'x', hint: 'y');
      expect(unknownSourceChecks(const [bad]), ['no.such']);
      expect(unknownSourceChecks(const [req]), isEmpty);
    });
  });

  group('跟运行时接得上', () {
    test('C / C++ 走同一套清洗', () {
      const code = 'int *p = &n; // *q\n';
      expect(runtimeFor(ProgrammingLanguage.c).stripCommentsAndLiterals(code),
          isNot(contains('*q')));
      expect(runtimeFor(ProgrammingLanguage.cpp).stripCommentsAndLiterals(code),
          isNot(contains('*q')));
    });

    test('Python 的运行时也实现了清洗（将来加 Python 要求时不会被注释骗）', () {
      expect(
          runtimeFor(ProgrammingLanguage.python)
              .stripCommentsAndLiterals('x = 1  # *p\n'),
          isNot(contains('*p')));
    });
  });
}
