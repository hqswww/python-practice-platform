import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/data/problem_repository.dart';
import 'package:python_practice/models/problem.dart';
import 'package:python_practice/models/problem_category.dart';
import 'package:python_practice/models/programming_language.dart';
import 'package:python_practice/pages/widgets/language_syntax.dart';
import 'package:python_practice/services/c_runtime.dart';
import 'package:python_practice/services/judge_engine.dart';
import 'package:python_practice/services/language_runtime.dart';

/// C++ 的编译型判题链路。
///
/// C++ 与 C 共享同一套「编译一次、多用例复用产物」的流程（都继承
/// [CompiledLanguageRuntime]），差别在扩展名、编译器、标准版本与报错文案。
void main() {
  // 读 assets 必须先初始化测试 binding（普通 test() 不会自动做）
  TestWidgetsFlutterBinding.ensureInitialized();

  final compilerReady = CRuntime.isCompilerAvailable(ProgrammingLanguage.cpp);

  Problem cppProblem({
    required List<TestCase> cases,
    int id = 1,
    String title = 'C++ 题',
  }) =>
      Problem(
        id: id,
        title: title,
        difficulty: Difficulty.easy,
        description: '',
        inputFormat: '',
        outputFormat: '',
        sampleInput: '',
        sampleOutput: '',
        testCases: cases,
        hints: const [],
        language: ProgrammingLanguage.cpp,
      );

  group('C++ 运行时策略', () {
    test('runtimeFor(cpp) 返回 C++ 运行时（不再是 UnsupportedError）', () {
      final rt = runtimeFor(ProgrammingLanguage.cpp);
      expect(rt.language, ProgrammingLanguage.cpp);
      expect(rt.sourceFileName, 'solution.cpp');
      expect(rt.compileSpec(Directory.systemTemp, File('x')), isNotNull,
          reason: '编译型语言必须有编译步骤');
    });

    test('标准版本锁在 C++17（避免各家编译器默认标准不一）', () {
      final rt = runtimeFor(ProgrammingLanguage.cpp) as CppLanguageRuntime;
      expect(rt.stdFlag, '-std=c++17');
    });

    test('回归：C 与 C++ 不能解析到同一个编译器', () {
      // 踩过的坑：兜底路径列表原先是 C/C++ 共用的，macOS 上第一个候选是
      // /usr/bin/clang，于是 C++ 也被它命中 —— 用 C 编译器编 C++，
      // 标准库符号一个都链不上，报一屏 Undefined symbols，所有 C++ 题全挂。
      // 这个断言就是锁死「两者必须解析到不同的编译器」。
      final c = CRuntime.resolveCompiler(ProgrammingLanguage.c);
      final cpp = CRuntime.resolveCompiler(ProgrammingLanguage.cpp);
      expect(c, isNot(cpp),
          reason: 'C 解析到 $c，C++ 解析到 $cpp —— 两者必须不同');

      final name = cpp.split(Platform.pathSeparator).last;
      expect(
        name.contains('++') || name.contains('g++') || name.contains('c++'),
        isTrue,
        reason: 'C++ 应解析到 C++ 编译器，实际是 $name',
      );
    });

    test('C 与 C++ 是两个独立运行时，互不串台', () {
      final c = runtimeFor(ProgrammingLanguage.c);
      final cpp = runtimeFor(ProgrammingLanguage.cpp);
      expect(c.sourceFileName, 'solution.c');
      expect(cpp.sourceFileName, 'solution.cpp');
      expect(c.language, isNot(cpp.language));
    });

    test('C++ 有自己的一套错误提示（链接错误/名字找不到/类型不匹配）', () {
      final rt = runtimeFor(ProgrammingLanguage.cpp);
      expect(rt.explainRuntimeError('undefined reference to `foo()\'', ''),
          contains('链接错误'));
      expect(
          rt.explainRuntimeError("error: 'x' was not declared in this scope", ''),
          contains('名字找不到'));
      expect(rt.explainRuntimeError('error: no matching function for call', ''),
          contains('类型不匹配'));
    });

    test('崩溃提示沿用编译型公共逻辑，且带上语言名', () {
      final rt = runtimeFor(ProgrammingLanguage.cpp);
      final msg = rt.explainRuntimeError('Segmentation fault', '', exitCode: -11);
      expect(msg, contains('崩溃'));
      expect(msg, contains('C++'), reason: '提示里应写明是哪门语言');
    });

    test('编译错误清洗认得 .cpp 扩展名', () {
      final rt = runtimeFor(ProgrammingLanguage.cpp);
      final cleaned = rt.cleanDiagnostics(
        '/tmp/judge_x/solution.cpp:3:5: error: expected \';\'',
        Directory('/tmp/judge_x'),
      );
      expect(cleaned, contains('第 3 行（第 5 列）'));
      expect(cleaned.contains('/tmp/judge_x'), isFalse,
          reason: '不该把临时目录路径甩给学生');
    });
  });

  group('C++ 语法高亮', () {
    test('of(cpp) 用的是 C++ 的词表，不是 C 也不是 Python', () {
      final cpp = LanguageSyntax.of(ProgrammingLanguage.cpp);
      expect(cpp, LanguageSyntax.cpp);
      expect(cpp, isNot(LanguageSyntax.c));
      expect(cpp, isNot(LanguageSyntax.python));

      // C++ 特有词
      for (final kw in ['class', 'namespace', 'template', 'virtual']) {
        expect(cpp.pattern, contains(kw), reason: 'C++ 关键字 $kw 应在正则里');
      }
      // 常用标准库符号
      for (final bi in ['cout', 'cin', 'endl', 'vector', 'string']) {
        expect(cpp.pattern, contains(bi), reason: '内置符号 $bi 应在正则里');
      }
    });

    test('C 与 C++ 都识别 // 与 /* */ 注释', () {
      for (final syn in [LanguageSyntax.c, LanguageSyntax.cpp]) {
        final re = RegExp(syn.pattern, multiLine: true);
        expect(re.firstMatch('// x')!.group(1), '// x');
        expect(re.firstMatch('/* x */')!.group(1), '/* x */');
      }
    });

    test('组号顺序一致（错位会让关键字被涂成字符串颜色）', () {
      for (final syn in [
        LanguageSyntax.python,
        LanguageSyntax.c,
        LanguageSyntax.cpp,
      ]) {
        final re = RegExp(syn.pattern, multiLine: true);
        final kw = syn.keywords.firstWhere((k) => k == 'int' || k == 'def');
        expect(re.firstMatch(kw)!.group(5), kw,
            reason: '$kw 必须落在「关键字」那一组');
      }
    });
  });

  group('C++ 判题链路', () {
    final engine = JudgeEngine(timeoutMs: 8000, compileTimeoutMs: 30000);

    test('能编译并跑通：iostream 版的 A+B', () async {
      if (!compilerReady) return;
      const code = r'''
#include <iostream>
using namespace std;
int main() {
    int a, b;
    cin >> a >> b;
    cout << a + b << endl;
    return 0;
}
''';
      final r = await engine.judge(
        cppProblem(cases: [
          TestCase(input: '1 2\n', output: '3'),
          TestCase(input: '10 20\n', output: '30'),
        ]),
        code,
      );
      expect(r.allPassed, isTrue,
          reason: r.caseResults.map((c) => c.message).join('\n'));
    });

    test('std::string 与 STL 可用（说明标准库链接正常）', () async {
      if (!compilerReady) return;
      const code = r'''
#include <iostream>
#include <string>
#include <algorithm>
#include <vector>
using namespace std;
int main() {
    string s;
    cin >> s;
    reverse(s.begin(), s.end());
    cout << s << endl;
    vector<int> v = {3, 1, 2};
    sort(v.begin(), v.end());
    cout << v[0] << endl;
    return 0;
}
''';
      final r = await engine.judge(
        cppProblem(cases: [TestCase(input: 'abc\n', output: 'cba\n1')]),
        code,
      );
      expect(r.allPassed, isTrue,
          reason: r.caseResults.map((c) => c.message).join('\n'));
    });

    test('编译失败 → compileError，报错里带 C++ 的味道', () async {
      if (!compilerReady) return;
      const code = r'''
#include <iostream>
int main() {
    std::cout << "hi"    // 少了分号
    return 0;
}
''';
      final r = await engine.judge(
        cppProblem(cases: [TestCase(input: '', output: 'hi')]),
        code,
      );
      expect(r.isCompileFailure, isTrue);
      expect(r.caseResults.first.message, contains('第'));
    });
  });

  group('C++ 题库自检', () {
    // 与 C 那边同样的两条约束：
    // 1. rootBundle 同一文件只能加载一次 → 用缓存
    // 2. 一条测试别判完整个题库（会把 flutter_tools 的通道搞崩）→ 逐分类拆开
    List<ProblemCategory>? cache;
    Future<List<ProblemCategory>> allCats() async => cache ??=
        await ProblemRepository()
            .loadCategories(language: ProgrammingLanguage.cpp);

    const keys = [
      '01_basics', '02_datatype', '03_operators', '04_conditionals',
      '05_loops', '06_functions', '07_arrays', '08_pointers',
      '09_classes', '10_inheritance', '11_stl', '12_challenges',
    ];

    for (final key in keys) {
      test('$key 的参考答案全部判过', () async {
        if (!compilerReady) return;

        final cats = await allCats();
        final matched = cats.where((c) => c.key == key).toList();
        if (matched.isEmpty) return; // 分类还没写，跳过
        final problems = matched.first.problems;
        expect(problems.length, 6, reason: '$key 应有 6 道题');

        final engine = JudgeEngine(timeoutMs: 8000, compileTimeoutMs: 30000);
        for (final p in problems) {
          final r = await engine.judge(p, p.solution);
          expect(r.allPassed, isTrue,
              reason: '题 ${p.id}「${p.title}」参考答案没通过：'
                  '${r.caseResults.first.message}');
        }
      }, timeout: const Timeout(Duration(minutes: 3)));
    }

    group('源码语法要求：不用指针/引用不许过关', () {
      Future<Problem> find(int id) async {
        final cats = await allCats();
        return cats
            .firstWhere((c) => c.key == '08_pointers')
            .problems
            .firstWhere((p) => p.id == id);
      }

      test('801：直接 n = n * 2 必须判不过（没用到指针）', () async {
        if (!compilerReady) return;
        final p = await find(801);

        // 输出与指针版本一字不差，但一个指针都没有
        const withoutPointer = '''
#include <iostream>
using namespace std;
int main() {
    int n;
    cin >> n;
    n = n * 2;
    cout << n << endl;
    return 0;
}
''';
        final r = await JudgeEngine(timeoutMs: 5000).judge(p, withoutPointer);

        expect(r.outputAllPassed, isTrue, reason: '前提：输出确实全对');
        expect(r.allPassed, isFalse, reason: '没用指针却判过了');
        expect(r.unmetRequirements.map((e) => e.check), contains('pointer.use'));
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('802：直接 n = n * 3 必须判不过（没用到引用）', () async {
        if (!compilerReady) return;
        final p = await find(802);

        // 注意 `int copy = n; copy = copy - 1;` 是题目本来就要的，
        // 这里只是把「用引用改 n」换成了「直接改 n」
        const withoutReference = '''
#include <iostream>
using namespace std;
int main() {
    int n;
    cin >> n;
    n = n * 3;
    int copy = n;
    copy = copy - 1;
    cout << n << endl;
    cout << copy << endl;
    return 0;
}
''';
        final r = await JudgeEngine(timeoutMs: 5000).judge(p, withoutReference);

        expect(r.outputAllPassed, isTrue, reason: '前提：输出确实全对');
        expect(r.allPassed, isFalse, reason: '没用引用却判过了');
        expect(r.unmetRequirements.map((e) => e.check),
            contains('reference.use'));
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('804：在 main 里自己换、不碰引用参数 → 判不过', () async {
        if (!compilerReady) return;
        final p = await find(804);

        // 函数签名照题目写（判不了签名的真假），但函数体里一次都没碰 x、y
        const withoutReference = '''
#include <iostream>
using namespace std;
void swapByRef(int& x, int& y) {
    return;
}
int main() {
    int a, b;
    cin >> a >> b;
    int t = a;
    a = b;
    b = t;
    cout << a << endl;
    cout << b << endl;
    return 0;
}
''';
        final r = await JudgeEngine(timeoutMs: 5000).judge(p, withoutReference);

        expect(r.outputAllPassed, isTrue, reason: '前提：输出确实全对');
        expect(r.allPassed, isFalse, reason: '引用参数从没被用到却判过了');
      }, timeout: const Timeout(Duration(minutes: 2)));
    });
  });
}
