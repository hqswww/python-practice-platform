import 'dart:async';

import 'package:flutter/foundation.dart' show LicenseRegistry, LicenseEntryWithLineBreaks;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'data/problem_repository.dart';
import 'models/problem_category.dart';
import 'pages/learn_page.dart';
import 'pages/practice_page.dart';
import 'pages/setup_wizard_page.dart';
import 'pages/test_page.dart';
import 'pages/mine_page.dart';
import 'services/error_log_service.dart';
import 'services/settings_service.dart';
import 'services/language_service.dart';
import 'services/update_service.dart';
import 'pages/widgets/update_dialog.dart';
import 'theme.dart';

/// 全局设置服务单例（供各页面读取/修改）
// main.dart 顶部不再重复定义，统一用 services/settings_service.dart 里的全局 settings

/// 把本应用自己的 MIT 许可证注册进 Flutter 的许可证登记表。
///
/// **不做这一步，「关于 → 第三方许可证」里就看不到本项目的许可证** ——
/// 那个页面只列 pub 依赖的许可证，自己这份不在其中，用户会以为项目没有开源许可。
/// 读的是打包进来的仓库根目录 LICENSE，和 GitHub 上那份是同一个文件。
void _registerOwnLicense() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('LICENSE');
    yield LicenseEntryWithLineBreaks(const ['编程练习册'], text.trim());
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerOwnLicense();
  // 先挂全局错误收集（越早越好，能捞到启动期异常）
  errorLog.installGlobalHandlers();
  await settings.load();
  // 恢复上次选的语言。必须在加载题库之前 —— 题库会按语言过滤
  await languageService.load();

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
          title: '编程练习册',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(
            brightness: Brightness.light,
            seedColor: settings.accentColor,
          ),
          darkTheme: buildAppTheme(
            brightness: Brightness.dark,
            seedColor: settings.accentColor,
          ),
          themeMode: settings.themeMode, // 主题模式可切换
          // 首次运行先走向导：这台机器上有没有编译器/解释器，直接决定学生能不能
          // 做题，值得在第一次打开时说清楚。
          //
          // 不需要在这里 setState 切换 —— 向导完成时会 settings.setSetupWizardDone(true)，
          // 而外面这层 ListenableBuilder 监听的就是 settings，自然重建到这里。
          home: shouldShowSetupWizard()
              ? SetupWizardPage(onFinished: () {})
              : const HomePage(),
        );
      },
    );
  }
}

/// 主框架：底部 NavigationBar 切换三个板块（练习/测试/设置）
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.updateServiceOverride});

  /// 覆盖更新检查服务（**只给测试用**）。
  ///
  /// 启动时的「有新版就弹窗」是这个功能唯一没法用单元测试直接覆盖的一环
  /// （它挂在首帧回调上），所以留一个注入口 —— 否则只能靠「发个真 Release
  /// 再手工打开应用看看」来验证，那种验证没人会每次改完都跑。
  final UpdateService? updateServiceOverride;

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
    _loadCategoriesForCurrentLanguage();
    // 切语言要重新加载题库：三个主板块的内容都是按语言划分的。
    // 用监听而不是在切换回调里 setState，是因为语言还可能被别处改
    // （比如启动时从偏好恢复）。
    languageService.addListener(_loadCategoriesForCurrentLanguage);
    // 检查更新放在**首帧之后**：它要联网，绝不能拖慢启动，
    // 也不能跟首屏的题库加载抢；失败时更是悄无声息。
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  /// 启动时检查一次更新，有新的就问用户要不要去下载。
  ///
  /// 三层「不打扰」：设置里可以整体关掉；同一个版本被跳过就不再提示；
  /// 检查失败（断网、限流、接口挂了）完全静默。
  Future<void> _checkUpdate() async {
    if (!settings.autoCheckUpdate) return;

    final result =
        await (widget.updateServiceOverride ?? updateService).check();
    if (!mounted || !result.hasUpdate) return;

    final info = result.update!;
    // 同一个版本只提示一次 —— 用户点过「跳过这个版本」就别再烦他。
    // 注意只跳过这一个版本，下个版本照常提示。
    if (info.version == settings.skippedUpdateVersion) return;

    final action = await showUpdateDialog(context, info);
    if (action == UpdateDialogAction.skipVersion) {
      await settings.setSkippedUpdateVersion(info.version);
    }
  }

  @override
  void dispose() {
    languageService.removeListener(_loadCategoriesForCurrentLanguage);
    super.dispose();
  }

  /// 按当前语言重新加载题库。
  ///
  /// **必须按语言过滤**：不过滤会把所有语言的分类混在一起显示
  /// （练 Python 时冒出 C 的分类）。
  void _loadCategoriesForCurrentLanguage() {
    setState(() {
      _categoriesFuture =
          ProblemRepository().loadCategories(language: languageService.value);
    });
  }

  void _onDestinationSelected(int i) {
    if (i == _currentIndex) return;
    setState(() {
      _currentIndex = i;
      _navTransition++; // 触发过渡动画 key 变化
    });
  }

  Future<void> _reload() async {
    _loadCategoriesForCurrentLanguage();
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
                    appBar: AppBar(title: Text('${languageService.value.displayName} 练习平台')),
                    body: const Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Scaffold(
                    appBar: AppBar(title: Text('${languageService.value.displayName} 练习平台')),
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
            MinePage(
              onResetProgress: _reload,
              // 从别的 tab 切回来要重算：用户可能刚做完题
              isActive: _currentIndex == 3,
            ),
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
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
