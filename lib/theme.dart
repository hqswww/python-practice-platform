/// 应用主题（Material 3）
///
/// 单独一个文件是为了**测试能拿到真的那份主题**。
/// `test/theme_contrast_test.dart` 要在浅色/深色两套主题下检查文字与底色的
/// 对比度，而它必须用界面实际使用的那份主题 —— 在测试里另抄一份的话，
/// 改了 `main.dart` 里的颜色而测试还按旧副本判，等于没测。
library;

import 'package:flutter/material.dart';

/// 构建主题。[seedColor] 是用户在设置页选的强调色种子。
ThemeData buildAppTheme({
  required Brightness brightness,
  required Color seedColor,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // 全局默认字体：捆绑的更纱黑体（简体），保证 Linux/Windows 中文渲染一致
    fontFamily: 'SarasaGothicSC',
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
    ),
    // ⚠️ filled: true 是**全局**的，会连「自己画了深色底」的输入框一起刷
    // （交互终端的输入栏就中过招：浅色模式下被刷成浅灰底 + 写死的白字 = 看不见）。
    // 自带底色的输入框必须显式写 `filled: false` 才能豁免。
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.light
          ? Colors.grey.shade100
          : Colors.grey.shade900,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 3,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
