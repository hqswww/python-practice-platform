import 'dart:async';

import 'package:flutter/material.dart';

import 'data/problem_repository.dart';
import 'models/problem_category.dart';
import 'pages/learn_page.dart';
import 'pages/practice_page.dart';
import 'pages/test_page.dart';
import 'pages/settings_page.dart';
import 'services/error_log_service.dart';
import 'services/settings_service.dart';

/// 全局设置服务单例（供各页面读取/修改）
// main.dart 顶部不再重复定义，统一用 services/settings_service.dart 里的全局 settings

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 先挂全局错误收集（越早越好，能捞到启动期异常）
  errorLog.installGlobalHandlers();
  await settings.load();

  // runZonedGuarded 兜底：捕获 Zone 内异步/微任务异常（Dart 层最全的一层）
  await runZonedGuarded(() async {
    runApp(const PythonPracticeApp());
  }, (error, stackTrace) {
    errorLog.logError(
      '未捕获的异步异常: $error',
      source: LogSource.uncaught,
      error: error,
      stackTrace: stackTrace,
    );
  });
}

class PythonPracticeApp extends StatelessWidget {
  const PythonPracticeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'Python 练习平台',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: settings.themeMode, // 主题模式可切换
          home: const HomePage(),
        );
      },
    );
  }

  /// Material 3 主题构建
  ThemeData _buildTheme(Brightness brightness) {
    // 强调色可由用户在设置页选择（默认清新绿）
    final scheme = ColorScheme.fromSeed(
      seedColor: settings.accentColor,
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
}

/// 主框架：底部 NavigationBar 切换三个板块（练习/测试/设置）
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  int _navTransition = 0; // 切页时自增，触发顶部过渡动画

  // 题库数据（懒加载一次，供练习页回退刷新使用）
  Future<List<ProblemCategory>>? _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = ProblemRepository().loadCategories();
  }

  void _onDestinationSelected(int i) {
    if (i == _currentIndex) return;
    setState(() {
      _currentIndex = i;
      _navTransition++; // 触发过渡动画 key 变化
    });
  }

  Future<void> _reload() async {
    setState(() {
      _categoriesFuture = ProblemRepository().loadCategories();
    });
    await _categoriesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 切页过渡动画：轻微缩放 + 淡入（保留 IndexedStack 状态）
      body: TweenAnimationBuilder<double>(
        key: ValueKey(_navTransition),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          return Opacity(
            opacity: 0.6 + 0.4 * t,
            child: Transform.scale(
              scale: 0.99 + 0.01 * t,
              alignment: Alignment.topCenter,
              child: child,
            ),
          );
        },
        child: IndexedStack(
          index: _currentIndex,
          children: [
            // 学习（第一个）
            FutureBuilder<List<ProblemCategory>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('学习笔记')),
                    body: const Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('学习笔记')),
                    body: Center(child: Text('加载题库失败: ${snapshot.error}')),
                  );
                }
                final categories = snapshot.data ?? [];
                return LearnPage(categories: categories);
              },
            ),
            // 练习
            FutureBuilder<List<ProblemCategory>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Python 练习平台')),
                    body: const Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Python 练习平台')),
                    body: Center(child: Text('加载题库失败: ${snapshot.error}')),
                  );
                }
                final categories = snapshot.data ?? [];
                return PracticePage(categories: categories);
              },
            ),
            // 测试
            const TestPage(),
            // 设置
            SettingsPage(onResetProgress: _reload),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '学习',
          ),
          NavigationDestination(
            icon: Icon(Icons.code),
            selectedIcon: Icon(Icons.code),
            label: '练习',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: '测试',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
