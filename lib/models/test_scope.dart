/// 测试出题范围（每个测试模式各存一份）
///
/// 用户的需求：给每种测试单独设定「从哪些大类里出题」和「出到哪个难度」，
/// 就像每种测试的倒计时时长单独设定一样。
library;

import 'problem.dart';

/// 难度档位 —— 累计式的「最高允许难度」。
///
/// 命名刻意用「难度一/二/三」而不是 easy/medium/hard，因为它是**累计**的，
/// 和题目自己的难度（简单/中等/困难）不是一回事：
///
/// - 难度一 = 绿 = 只出简单
/// - 难度二 = 绿 + 黄 = 简单 + 中等
/// - 难度三 = 绿 + 黄 + 红 = 全部难度
///
/// 用 easy/medium/hard 当名字会让人以为「难度二 = 只出中等」，正好理解反。
enum DifficultyTier {
  one(1, '难度一', '只出简单题'),
  two(2, '难度二', '简单 + 中等'),
  three(3, '难度三', '全部难度');

  const DifficultyTier(this.level, this.label, this.detail);

  /// 允许的最高难度级别（1/2/3）
  final int level;
  final String label;
  final String detail;

  /// 存下来的值可能失效或异常 —— 一律回落到「难度三」（不限制），
  /// 这样老数据/坏数据只会让范围更宽，不会让学生莫名其妙做不了题。
  static DifficultyTier fromLevel(int? level) {
    for (final t in values) {
      if (t.level == level) return t;
    }
    return DifficultyTier.three;
  }

  /// 这一档允许出现 [d] 这个难度吗
  bool allows(Difficulty d) => levelOf(d) <= level;

  /// 这一档**新引入**的那一级难度。
  ///
  /// 「这一档有没有意义」就看它：范围里要是压根没有困难题，
  /// 难度三和难度二能出的题一模一样，摆在那里只会误导人。
  Difficulty get introduces => difficultyOf(level);
}

/// 题目难度的级别：简单 1 / 中等 2 / 困难 3。
///
/// **不直接用 `Difficulty.index`**：那是枚举的声明顺序，哪天有人调整顺序，
/// 所有难度判断都会静默错掉。写死映射，改不了。
int levelOf(Difficulty d) => switch (d) {
      Difficulty.easy => 1,
      Difficulty.medium => 2,
      Difficulty.hard => 3,
    };

Difficulty difficultyOf(int level) => switch (level) {
      1 => Difficulty.easy,
      2 => Difficulty.medium,
      _ => Difficulty.hard,
    };

/// 分类 key 里的序号：`01_syntax` → 1；取不到返回 null。
///
/// 题库结构守卫（`test/bank_structure.dart`）保证 key 一定是 `NN_xxx` 格式。
int? categoryOrdinal(String key) {
  final m = RegExp(r'^(\d+)').firstMatch(key);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// 一门语言的分类个数。
///
/// 三门语言都是 12 个大类，且**教学阶段一一对应**（第 1 个是基础语法、
/// 第 9 个在 C 是指针、在 C++ 是指针与引用…）。出题范围按序号存就靠这个前提。
const int kCategoryCount = 12;

/// 全部大类（默认范围）
const Set<int> kAllOrdinals = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};

/// 一个测试模式的出题范围
class TestScope {
  /// 选中的大类**序号**（取值为 [kAllOrdinals]），至少一个。
  ///
  /// 为什么按序号而不是分类 key：三门语言的 key 并不一样 ——
  /// python 的第 1 个是 `01_syntax`，C / C++ 是 `01_basics`；C++ 的第 11 个是
  /// `11_stl`，另外两门是 `11_advanced`。序号对应的教学阶段却是一致的，
  /// 所以按序号存，切语言时同一序号落到同一阶段，显示名跟着当前语言走。
  final Set<int> ordinals;

  final DifficultyTier tier;

  const TestScope({required this.ordinals, required this.tier});

  /// 默认：全部大类 + 不限难度。
  ///
  /// 刻意等于「这个功能上线之前的行为」—— 老用户升级上来先什么都不变，
  /// 想限定范围的人自己去调。
  static const TestScope defaults = TestScope(
    ordinals: kAllOrdinals,
    tier: DifficultyTier.three,
  );

  /// 是不是默认范围（界面上要能一眼看出「我改过没有」）
  bool get isDefault =>
      tier == DifficultyTier.three && ordinals.length == kAllOrdinals.length;

  TestScope copyWith({Set<int>? ordinals, DifficultyTier? tier}) => TestScope(
        ordinals: ordinals ?? this.ordinals,
        tier: tier ?? this.tier,
      );

  /// 归一化：去掉越界序号、排序；空集合视为无效（调用方不该产生空集合，
  /// 兜底成「全部」比让学生做不了题好）
  static Set<int> normalizeOrdinals(Iterable<int> raw) {
    final cleaned = raw.where((o) => o >= 1 && o <= kCategoryCount).toSet();
    return cleaned.isEmpty ? kAllOrdinals : cleaned;
  }

  @override
  bool operator ==(Object other) =>
      other is TestScope &&
      other.tier == tier &&
      other.ordinals.length == ordinals.length &&
      other.ordinals.containsAll(ordinals);

  @override
  int get hashCode => Object.hash(tier, Object.hashAllUnordered(ordinals));
}
