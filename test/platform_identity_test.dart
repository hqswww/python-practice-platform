import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 三平台的应用身份一致性。
///
/// 这类漂移**不会让任何代码报错**，只会让用户看到不一致的东西 —— 实际就发生过：
/// Linux 的窗口标题和可执行文件名一直是 Flutter 模板塞进去的 Dart 包名
/// `python_practice`，而 macOS / Windows 早就叫 `code_workbook` / 「编程练习册」了，
/// 直到要出 Linux 包时才被发现。
///
/// 这些断言读的是 CMake / Xcode / GTK 的配置文件，编译期不会校验它们，
/// 只能靠测试兜住。
void main() {
  /// 只看**生效的行**：注释里提到某个写法（比如解释它为什么被改掉）不该让测试挂掉。
  /// 这个坑当场踩过一次 —— 一句「原来这里写的是 com.example」差点把测试弄挂。
  String codeOnly(String text) => text
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('#'))
      .join('\n');

  String read(String path) {
    final f = File(path);
    expect(f.existsSync(), isTrue, reason: '找不到 $path（测试的工作目录应是项目根目录）');
    return f.readAsStringSync();
  }

  group('可执行文件名三平台一致', () {
    test('都是 code_workbook', () {
      expect(read('linux/CMakeLists.txt'),
          contains('set(BINARY_NAME "code_workbook")'),
          reason: 'Linux 的 BINARY_NAME 决定用户拿到的可执行文件名');
      expect(read('windows/CMakeLists.txt'),
          contains('set(BINARY_NAME "code_workbook")'));
      expect(read('macos/Runner/Configs/AppInfo.xcconfig'),
          contains('PRODUCT_NAME = code_workbook'));
    });

    test('Linux 窗口标题不再是 Dart 包名', () {
      final cc = read('linux/runner/my_application.cc');
      expect(cc, isNot(contains('"python_practice"')),
          reason: '标题栏上出现下划线英文包名很难看，且与 macOS 不一致');
      expect(cc, contains('编程练习册'));
    });
  });

  group('绝不能改的标识（改了会伤到用户数据）', () {
    test('macOS Bundle ID —— 它是用户进度的定位键', () {
      // ~/Library/Preferences/<BundleID>.plist 以及沙盒外的
      // ~/Library/Application Support/<BundleID>/ 都按这个 id 存。
      // 改了 id，老用户的进度、错题、收藏、成就不是丢了，而是**找不到**了
      // —— 表现和丢数据一模一样。
      expect(read('macos/Runner/Configs/AppInfo.xcconfig'),
          contains('PRODUCT_BUNDLE_IDENTIFIER = com.sakiri.python-practice'));
    });

    test('Linux APPLICATION_ID 与 macOS Bundle ID 用同一个字符串', () {
      // .desktop 入口、单实例、StartupWMClass 都按它找应用；
      // 两边不一致会让任务栏图标对不上窗口。
      expect(read('linux/CMakeLists.txt'),
          contains('set(APPLICATION_ID "com.sakiri.python-practice")'),
          reason: '注意是连字符，不是下划线');
    });

    test('Dart 包名 python_practice —— 21 个文件 import 它', () {
      expect(read('pubspec.yaml'), contains('name: python_practice'),
          reason: '改包名要同步改所有 import 和平台脚手架，收益为零');
    });

    test('Windows 安装包的 AppId —— 和 Bundle ID 是同一类东西', () {
      // Inno 用它识别「这是不是同一个应用」：升级安装、卸载、控制面板条目都认它。
      // 改了等于变成另一个软件 —— 老用户装新版会得到两份并存，卸载也清不掉旧的。
      final iss = read('tools/windows_installer.iss');
      // Inno 里 `{` 是常量起始符，要写字面花括号得写 `{{`。
      // 所以规范写法是 `AppId={{GUID}` —— 开头双括号、结尾单括号，
      // 展开后有效值是 `{GUID}`。末尾允许 `}` 或 `}}`，免得被写法差异绊住。
      final m = RegExp(r'#define AppId "\{\{([0-9A-Fa-f-]{36})\}\}?')
          .firstMatch(iss);
      expect(m, isNotNull, reason: '没找到 AppId 定义，格式可能被改坏了');
      expect(m!.group(1)!.toUpperCase(), 'CCAA5D7C-47D3-4F51-AF55-A566213C04E3');
    });
  });

  group('安装包', () {
    test('Inno 脚本引用的中文语言包确实在仓库里', () {
      // 语言包不是 Inno Setup 官方自带，所以随仓库带（MIT，见 tools/inno/README.md）。
      // 少了它 ISCC 会直接编译失败。
      expect(File('tools/inno/ChineseSimplified.isl').existsSync(), isTrue,
          reason: '缺语言包，ISCC 会报 MessagesFile 找不到');
      expect(File('tools/inno/LICENSE').existsSync(), isTrue,
          reason: 'MIT 许可要求保留版权声明');
      expect(read('tools/windows_installer.iss'),
          contains(r'inno\ChineseSimplified.isl'));
    });

    test('Inno 脚本引用的图标存在', () {
      expect(read('tools/windows_installer.iss'),
          contains(r'SetupIconFile=..\windows\runner\resources\app_icon.ico'));
      expect(File('windows/runner/resources/app_icon.ico').existsSync(), isTrue);
    });

    test('安装包是免管理员的（和绿色版一个精神）', () {
      expect(read('tools/windows_installer.iss'),
          contains('PrivilegesRequired=lowest'));
    });

    test('macOS 打包产出 dmg，且做成拖拽安装的形式', () {
      final sh = read('tools/build_macos.sh');
      expect(sh, contains('hdiutil create'), reason: '没有 dmg 生成步骤');
      expect(sh, contains('ln -s /Applications'),
          reason: 'dmg 里要有指向 /Applications 的落点，否则没法拖拽安装');
      expect(sh, contains('首次打开请先读我.txt'),
          reason: 'Gatekeeper 那步得让最终用户看得到，不能只写在构建输出里');
    });

    test('dmg 里把 .app 改成中文名（磁盘名/Finder 名/说明文案三处一致）', () {
      expect(read('tools/build_macos.sh'),
          contains('APP_NAME="编程练习册.app"'));
    });

    test('zip 刻意保留 ASCII 名（ditto 写 zip 不设 UTF-8 标志位）', () {
      final sh = read('tools/build_macos.sh');
      // 防止有人「顺手统一一下」把 zip 也改成中文名 ——
      // 那会让 Windows/Linux 的解压工具按 CP437 解出乱码。
      expect(sh, contains(r'--keepParent "$APP" "$ZIP"'),
          reason: 'zip 应从原始 ASCII 名的产物打包；改中文名会引入 zip 编码乱码');
      expect(RegExp(r'keepParent "\$STAGE/\$APP_NAME"').hasMatch(sh), isFalse,
          reason: 'zip 不该用改名后的副本');
    });
  });

  test('build_linux.sh 有平台护栏（Flutter 桌面版不能交叉编译）', () {
    final sh = read('tools/build_linux.sh');
    expect(sh, contains('uname -s'), reason: '护栏要按 uname 判断');
    expect(sh, contains('只能在 Linux 上运行'));
  });

  group('PowerShell 脚本的编码', () {
    // 这条是中文的命门，而且**极易被静默破坏**：任何一次用普通 UTF-8 编辑器
    // 存盘都会把 BOM 丢掉，而本机（macOS/Linux）完全看不出问题 ——
    // 只有中文 Windows 用户会看到满屏乱码，甚至脚本直接语法报错。
    const scripts = ['tools/install_mingw.ps1', 'tools/build_windows.ps1'];

    test('都必须是 UTF-8 with BOM', () {
      for (final path in scripts) {
        final bytes = File(path).readAsBytesSync();
        expect(bytes.length, greaterThan(3), reason: '$path 是空文件？');
        expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF],
            reason: '$path 少了 UTF-8 BOM。\n'
                'Windows PowerShell 5.1 读无 BOM 的 .ps1 时按系统 ANSI 代码页\n'
                '（中文系统 = GBK）解码，UTF-8 的中文会变成乱码；更糟的是乱码\n'
                '字节里可能撞出引号，使整个脚本语法报错。BOM 是 5.1 判断编码\n'
                '的唯一可靠依据。修法：\n'
                '  python3 -c "p=\'$path\';d=open(p,\'rb\').read();'
                'open(p,\'wb\').write(b\'\\xef\\xbb\\xbf\'+d)"');
      }
    });

    test('都显式把控制台输出设成 UTF-8', () {
      for (final path in scripts) {
        expect(read(path), contains('[Console]::OutputEncoding'),
            reason: '$path 没设控制台输出编码，中文会按控制台代码页编码而变花');
      }
    });
  });

  group('Windows 版本资源（exe 属性页里显示的内容）', () {
    // Windows 上一个字都不会自己报错：exe 照样能编出来、照样能跑，
    // 只有用户右键看「属性 → 详细信息」时才会发现名字不对或是一串问号。
    test('StringTable 的代码页必须是 04b0（Unicode），不能是模板默认的 04e4', () {
      final rc = read('windows/runner/Runner.rc');
      expect(rc, contains('"040904b0"'),
          reason: '内容含中文，代码页却声明成 1252 —— 微软对 StringTable.szKey 的\n'
              '定义是「低四位表示 the code page for which the data is formatted」，\n'
              '并要求 Unicode 内容用 0x04b0。声明与内容不一致，读到的可能就是乱码');
      expect(rc, isNot(contains('"040904e4"')),
          reason: '04e4 = 1252（Windows-1252），装不下中文');
      expect(rc, contains('"Translation", 0x409, 1200'),
          reason: 'VarFileInfo 的代码页要和 StringTable 一致');
    });

    test('含中文的值必须是宽字符 L"..."，否则不会以 UTF-16 存进资源', () {
      final rc = read('windows/runner/Runner.rc');
      expect(rc, contains('L"编程练习册"'));
      // 反面：窄字符的中文就是这个 bug 的样子
      expect(rc, isNot(contains(r'"编程练习册" "\0"')),
          reason: '窄字符声明配合 1252 代码页是修复前的写法');
    });

    test('不再有 com.example 占位符（会出现在 exe 属性页和关于框里）', () {
      // 只看**生效的行**：注释里提到不算，否则一句「原来这里是 com.example」
      // 的说明就会把测试弄挂（这个坑当场踩过一次）。
      String stripComments(String text) => text
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      expect(stripComments(read('windows/runner/Runner.rc')),
          isNot(contains('com.example')));
      expect(stripComments(read('macos/Runner/Configs/AppInfo.xcconfig')),
          isNot(contains('com.example')));
    });

    test('CompanyName / ProductName 是用户进度的定位键（Windows 版）', () {
      // ⚠️ 这两项不只是「属性页里好看」：Windows 的 shared_preferences
      // 把数据写进 %APPDATA%\<CompanyName>\<ProductName>\，路径就是从
      // exe 的版本资源里读的。改了它，老用户下次启动会**找不到自己的进度**
      // （不是丢失，是换了个新目录，看起来跟丢失一样）。
      //
      // 和 macOS 的 PRODUCT_BUNDLE_IDENTIFIER 是同一类东西 ——
      // 而且自动更新功能承诺「覆盖安装不会丢进度」，前提就是它不变。
      final rc = read('windows/runner/Runner.rc');
      expect(rc, contains('VALUE "CompanyName", "com.sakiri"'),
          reason: '改了它，Windows 用户的进度目录会跟着变');
      expect(rc, contains('VALUE "ProductName", L"编程练习册"'),
          reason: '中文必须用宽字符，否则版本资源里存进去的是乱码，'
              '进度目录名也就跟着乱（而且两次可能不一样）');
    });
  });

  group('已签名的包不能被自己改坏', () {
    // 捆绑的 Python 默认会往**自己的安装目录**写 __pycache__/*.pyc，而它就在
    // .app 里面 —— 跑一次程序就等于改一次应用包，签名随即报
    // 「a sealed resource is missing or invalid」。
    // 应用侧靠 python_runtime.dart 的环境变量挡住（那条有独立测试）；
    // 这里守的是**直接调用解释器的那些脚本**，它们拿不到应用的环境变量。
    //
    // 说明：这是绊线不是证明 —— 它只能发现「有人把这段删了」，
    // 真正的验证是连着跑三次 tools/verify_macos.sh 都该是 14/14。
    test('verify_macos.sh 调捆绑解释器时带 -B', () {
      final sh = read('tools/verify_macos.sh');
      expect(sh, contains('PYB=(-X utf8 -B)'),
          reason: '这是给捆绑解释器用的统一参数数组');
      expect(sh, contains('PYTHONDONTWRITEBYTECODE=1'),
          reason: '双保险：环境变量也设上');
    });

    test('build_macos.sh 的自检也不写字节码', () {
      final sh = read('tools/build_macos.sh');
      expect(sh, contains('PYTHONDONTWRITEBYTECODE=1'),
          reason: '构建期跑一次解释器就会把 .pyc 打进包并封存');
    });
  });

  group('build_linux.sh 的产物路径（在真 Linux 上跑出来的 bug）', () {
    // 实际发生的事：脚本用 `uname -m` 得到的 x86_64 去拼 Flutter 的构建目录
    //   BUNDLE_DIR="build/linux/${ARCH_TAG}/release/bundle"
    // 而 Flutter 用的是**它自己的**架构名 `x64` / `arm64` —— 两个写法不是一套。
    // 于是路径永远不存在，接着被一个宽松的兜底 `find ... -name bundle` 接住，
    // 捞到了几天前 `flutter run` 留下的 build/linux/x64/**debug**/bundle。
    // 之后每一步都"成功"，只是打出来的是个旧 debug 程序；最后卡在
    // 「可执行文件不在预期位置」，因为那个旧产物里还叫 python_practice。
    test('不许用 uname 的架构名去拼 Flutter 的构建目录', () {
      final code = codeOnly(read('tools/build_linux.sh'));
      expect(code, isNot(contains('build/linux/\${ARCH_TAG}')),
          reason: 'Flutter 的构建目录是 build/linux/x64/... 或 arm64/...，'
              '跟 uname -m 的 x86_64 / aarch64 不是一套写法；'
              'ARCH_TAG 只该用来给分发包命名');
    });

    test('只在 release 目录里找产物，不给 debug 产物兜底的机会', () {
      final code = codeOnly(read('tools/build_linux.sh'));
      expect(code, contains('build/linux/*/release/bundle'),
          reason: '产物路径要从 release 目录里找');
      expect(code, isNot(contains('-name bundle')),
          reason: '`find -name bundle` 会把 build/linux/<arch>/debug/bundle 也捞进来 —— '
              '那是 `flutter run` 留下的旧产物，而且后面每一步都会"成功"，'
              '根本看不出打错了东西。宁可直接失败');
    });
  });

  group('Shell 脚本', () {
    final scripts = (Directory('tools')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.sh'))
            .map((f) => f.path)
            .toList()
          ..sort());

    test('能找到脚本（防止路径写错导致下面几条空跑）', () {
      expect(scripts.length, greaterThanOrEqualTo(5), reason: '实际：$scripts');
    });

    test('都能被 bash 解析 —— 语法错误不该等到运行时才发现', () {
      for (final s in scripts) {
        final r = Process.runSync('bash', ['-n', s]);
        expect(r.exitCode, 0, reason: '$s 有语法错误：\n${r.stderr}');
      }
    });

    test('都带「用真正的 bash 重跑自己」的守卫', () {
      // 用户实际踩过：`sh tools/build_macos.sh` 报
      // 「syntax error near unexpected token `<'」，位置在第 284 行的进程替换。
      // bash 是**边解析边执行**的，所以前几步会正常跑完、错误在中途突然冒出来，
      // 看起来像「跑到一半随机坏掉」。守卫本身是 POSIX 语法、能被 sh 执行，
      // 于是它能在解析器走到那些 bash 专有构造之前把自己换成 bash。
      for (final s in scripts) {
        expect(File(s).readAsStringSync(), contains('CODE_WORKBOOK_BASH'),
            reason: '$s 缺少 bash 重跑守卫。\n'
                '· macOS 的 /bin/sh 是 bash 的 POSIX 模式 → 进程替换直接语法报错\n'
                '· Linux 的 /bin/sh 往往是 dash → `[[ ]]` 会变成 command not found\n'
                '（不能用 BASH_VERSION 判断：sh 本身就是 bash 时它照样有值）');
      }
    });
  });
}
