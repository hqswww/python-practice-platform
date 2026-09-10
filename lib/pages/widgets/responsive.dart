import 'package:flutter/material.dart';

/// 窗口宽度断点
///
/// 桌面端窗口可以被任意拉伸，UI 必须跟着变。本项目约定：
///
/// - `< [twoPane]` → **窄**：单列。深层内容用 `Navigator.push` 进入新页面。
/// - `>= [twoPane]` → **宽**：左右分栏。左侧列表常驻，右侧显示当前项的详情。
///
/// 判定一律用 `>=` 比「最小宽度」，不要写成 `== 某宽度` 或按方向判断，
/// 否则窗口在断点附近来回拖动时布局会抖。
///
/// 之所以定 840：侧栏 [masterWidth] 固定占 280，右侧详情要留够约 560，
/// 再窄下去表单控件（SegmentedButton、Slider）会挤成一团。
abstract final class Breakpoints {
  /// 单列 / 左右分栏 的分界宽度
  static const double twoPane = 840;

  /// 更宽的屏才值得再切一栏（例如「列表 | 详情 | 预览」）
  static const double threePane = 1280;

  /// 列表栏的建议宽度
  static const double masterWidth = 280;
}

/// 当前可用宽度是否够放左右两栏
bool isTwoPaneWidth(double width) => width >= Breakpoints.twoPane;

/// 阅读类内容的最大宽度
///
/// 桌面窗口可以被拉到 1900+，但列表/表单跟着铺满会很难读：一行文字横跨
/// 整个屏幕，视线来回追踪成本极高。超过下面这些宽度就居中留白。
abstract final class ContentWidth {
  /// 题目列表、收藏、测试历史等常规列表
  static const double list = 900;

  /// 教程正文之类的长文
  static const double article = 760;

  /// 带代码编辑器 / 终端的宽工作区
  static const double workspace = 1160;

  /// 日志（行较长，需要横向空间）
  static const double log = 1100;
}

/// 把内容限制在 [maxWidth] 内并水平居中
///
/// 包在 `ListView` / `SingleChildScrollView` **外层**即可，不影响滚动：
/// ```dart
/// body: MaxWidthBody(child: ListView(...)),
/// ```
/// 高度约束会原样透传，所以滚动区仍能拿到有界高度。
class MaxWidthBody extends StatelessWidget {
  const MaxWidthBody({
    super.key,
    required this.child,
    this.maxWidth = ContentWidth.list,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        // 只限宽不限高：incoming 的高度约束会被 BoxConstraints.enforce 保留
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// 基于 `LayoutBuilder` 的自适应「主-详」分栏
///
/// 宽屏时把左栏（列表）与右栏（详情）并排；窄屏时**只渲染左栏** ——
/// 此时由调用方负责用 `Navigator.push` 让用户进到详情，本组件不接管导航。
///
/// 之所以只做布局、不管导航：窄屏「点进详情」在 Flutter 里是 push 一个新页面，
/// 宽屏是直接换右侧内容，两者的导航语义（返回栈、AppBar、手势返回）完全不同，
/// 硬塞进一个组件反而更难用。
///
/// 两个 builder 都收到 `isWide`，这样列表项才能按当前形态决定要不要画
/// 「>」箭头之类的提示 —— 避免组件内外各判一次宽度导致不一致。
class AdaptiveMasterDetail extends StatelessWidget {
  const AdaptiveMasterDetail({
    super.key,
    required this.masterBuilder,
    required this.detailBuilder,
    this.masterWidth = Breakpoints.masterWidth,
    this.showDivider = true,
  });

  /// 左栏：窄屏时它就是唯一内容
  final Widget Function(BuildContext context, bool isWide) masterBuilder;

  /// 右栏：仅在宽屏时被调用
  final Widget Function(BuildContext context, bool isWide) detailBuilder;

  /// 左栏固定宽度
  final double masterWidth;

  /// 两栏之间是否画分隔线
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = isTwoPaneWidth(constraints.maxWidth);
        final master = masterBuilder(context, wide);
        if (!wide) return master;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: masterWidth, child: master),
            if (showDivider) const VerticalDivider(width: 1),
            Expanded(child: detailBuilder(context, true)),
          ],
        );
      },
    );
  }
}
