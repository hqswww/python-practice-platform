import 'package:flutter_test/flutter_test.dart';

import 'package:python_practice/models/programming_language.dart';

import 'bank_structure.dart';

/// C++ 题库的结构守卫。规则与 C 一致，共用实现见 `bank_structure.dart`。
///
/// 单独一个文件是必须的：rootBundle 在同一个测试文件里只能加载一次。
void main() {
  test('C++ 题库结构符合规格', () async {
    await verifyBankStructure(ProgrammingLanguage.cpp);
  });
}
