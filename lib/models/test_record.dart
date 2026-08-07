import 'problem.dart';

/// 一次测试的逐题作答项（用于历史回看）
class TestRecordItem {
  final int problemId;
  final String title;
  final String solution;
  final bool wasCorrect;
  final String myCode;

  const TestRecordItem({
    required this.problemId,
    required this.title,
    required this.solution,
    required this.wasCorrect,
    required this.myCode,
  });

  Map<String, dynamic> toJson() => {
        'problemId': problemId,
        'title': title,
        'solution': solution,
        'wasCorrect': wasCorrect,
        'myCode': myCode,
      };

  factory TestRecordItem.fromJson(Map<String, dynamic> json) => TestRecordItem(
        problemId: json['problemId'] as int,
        title: json['title'] as String? ?? '',
        solution: json['solution'] as String? ?? '',
        wasCorrect: json['wasCorrect'] as bool? ?? false,
        myCode: json['myCode'] as String? ?? '',
      );

  /// 从 [Problem] 便捷构造（保留我的代码 + 对错标志）
  factory TestRecordItem.fromProblem(
          Problem p, {required bool wasCorrect, required String myCode}) =>
      TestRecordItem(
        problemId: p.id,
        title: p.title,
        solution: p.solution,
        wasCorrect: wasCorrect,
        myCode: myCode,
      );
}

/// 一次测试的完整历史记录（做过的测试 + 得分 + 逐题回看）
class TestRecord {
  final DateTime timestamp;
  final int correctCount;
  final int totalCount;
  final List<TestRecordItem> items;

  const TestRecord({
    required this.timestamp,
    required this.correctCount,
    required this.totalCount,
    required this.items,
  });

  double get score =>
      totalCount == 0 ? 0 : correctCount / totalCount;
  bool get passed => score >= 0.8;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'correctCount': correctCount,
        'totalCount': totalCount,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory TestRecord.fromJson(Map<String, dynamic> json) => TestRecord(
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        correctCount: json['correctCount'] as int? ?? 0,
        totalCount: json['totalCount'] as int? ?? 0,
        items: (json['items'] as List? ?? [])
            .map((e) => TestRecordItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
