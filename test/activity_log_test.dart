import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:python_practice/models/programming_language.dart';
import 'package:python_practice/services/progress_service.dart';

/// 练习活动记录。
///
/// 它是「练习趋势 / 活跃度 / 连续天数」的唯一数据来源 —— 其它进度都只存
/// 「做没做过」，没有时间维度。所以几个容易错的性质要钉住：
/// 只在「未解决 → 已解决」那一次计数、按语言分开、连续天数不该因为
/// 「今天还没做」就归零。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProgrammingLanguage py = ProgrammingLanguage.python;
  ProgrammingLanguage c = ProgrammingLanguage.c;

  group('计数语义', () {
    test('首次做对记一次', () async {
      final p = ProgressService();
      await p.markSolved(py, 101);
      expect(await p.activityOn(py, DateTime.now()), 1);
    });

    test('同一道题反复判题不会灌水', () async {
      // 学生改一版判一次是常态；每判一次都记的话「今天做了 20 题」是假的
      final p = ProgressService();
      await p.markSolved(py, 101);
      await p.markSolved(py, 101);
      await p.markSolved(py, 101);
      expect(await p.activityOn(py, DateTime.now()), 1);
    });

    test('同一道题做对过的状态下再判也不算新的一天', () async {
      final p = ProgressService();
      await p.markSolved(py, 101);
      expect(await p.activityOn(py, DateTime.now()), 1);
    });

    test('多道题累加', () async {
      final p = ProgressService();
      for (final id in [101, 102, 103]) {
        await p.markSolved(py, id);
      }
      expect(await p.activityOn(py, DateTime.now()), 3);
    });

    test('不同语言分开统计', () async {
      final p = ProgressService();
      await p.markSolved(py, 101);
      await p.markSolved(c, 101);
      final now = DateTime.now();
      expect(await p.activityOn(py, now), 1);
      expect(await p.activityOn(c, now), 1);
      expect((await p.activityByDay(py))[DateTime(now.year, now.month, now.day)],
          1);
    });
  });

  group('按天读取', () {
    test('activityByDay 只返回有记录的日子', () async {
      final p = ProgressService();
      await p.markSolved(py, 101);
      final days = await p.activityByDay(py);
      expect(days, hasLength(1));
      expect(days.values.single, 1);
    });

    test('没有记录时是空的', () async {
      expect(await ProgressService().activityByDay(py), isEmpty);
      expect(await ProgressService().activeDayCount(py), 0);
    });

    test('days 参数只取最近 N 天', () async {
      // 直接往存储里塞几天前的记录（没法把系统时间往回拨）
      final old = DateTime.now().subtract(const Duration(days: 30));
      SharedPreferences.setMockInitialValues({
        'activity_python_${_tag(old)}': 5,
      });
      final p = ProgressService();
      await p.markSolved(py, 101);
      expect((await p.activityByDay(py, days: 7)).length, 1,
          reason: '30 天前那条不该出现在「最近 7 天」里');
      expect((await p.activityByDay(py)).length, 2, reason: '不带 days 应当都给');
    });
  });

  group('连续练习天数', () {
    test('没有记录 → 0', () async {
      expect(await ProgressService().streakDays(py), 0);
    });

    test('只有今天 → 1', () async {
      final p = ProgressService();
      await p.markSolved(py, 101);
      expect(await p.streakDays(py), 1);
    });

    test('连续三天 → 3', () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        for (var i = 0; i < 3; i++)
          'activity_python_${_tag(now.subtract(Duration(days: i)))}': 1,
      });
      expect(await ProgressService().streakDays(py), 3);
    });

    test('今天还没做、昨天做了 → 仍然算连续（不能早上打开就归零）', () async {
      final yd = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'activity_python_${_tag(yd)}': 2,
        'activity_python_${_tag(yd.subtract(const Duration(days: 1)))}': 2,
      });
      expect(await ProgressService().streakDays(py), 2);
    });

    test('中间断一天就断签', () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'activity_python_${_tag(now)}': 1,
        // 昨天缺
        'activity_python_${_tag(now.subtract(const Duration(days: 2)))}': 1,
      });
      expect(await ProgressService().streakDays(py), 1);
    });
  });

  group('合并（导入用）', () {
    test('同日取较大值，而不是相加 —— 同一个文件导两次不该翻倍', () async {
      final p = ProgressService();
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);

      await p.markSolved(py, 101); // 今天 = 1
      expect(await p.mergeActivity(py, {day: 1}), 0, reason: '没有变大，返回 0');
      expect(await p.activityOn(py, day), 1);

      expect(await p.mergeActivity(py, {day: 5}), 1);
      expect(await p.activityOn(py, day), 5);
      // 再合一次同样的数据，值不变
      expect(await p.mergeActivity(py, {day: 5}), 0);
      expect(await p.activityOn(py, day), 5);
    });

    test('更小的值不会把本地记录改小', () async {
      final p = ProgressService();
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      await p.mergeActivity(py, {day: 8});
      await p.mergeActivity(py, {day: 2});
      expect(await p.activityOn(py, day), 8);
    });
  });

  group('历史清理', () {
    test('超过保留期的记录会被清掉（写入时顺手清）', () async {
      final tooOld = DateTime.now()
          .subtract(Duration(days: ProgressService.activityKeepDays + 10));
      final fresh = DateTime.now().subtract(const Duration(days: 5));
      SharedPreferences.setMockInitialValues({
        'activity_python_${_tag(tooOld)}': 3,
        'activity_python_${_tag(fresh)}': 2,
      });
      final p = ProgressService();
      await p.markSolved(py, 101); // 触发一次清理

      final days = await p.activityByDay(py);
      expect(days.keys.any((d) => d.isAtSameMomentAs(
          DateTime(tooOld.year, tooOld.month, tooOld.day))), isFalse,
          reason: '过期记录应当被清掉，否则键会无限增长');
      expect(days.keys.any((d) => d.isAtSameMomentOfDay(fresh)), isTrue,
          reason: '没到期的记录不能误删');
      expect(days[DateTime(tooOld.year, tooOld.month, tooOld.day)], isNull);
    });
  });
}

String _tag(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

extension on DateTime {
  bool isAtSameMomentOfDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}
