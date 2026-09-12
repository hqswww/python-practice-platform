import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:python_practice/services/temp_workspace.dart';

/// 判题工作目录的选择逻辑。
///
/// 为什么要专门测：Windows 上用户名可能是中文，`%TEMP%` 就带非 ASCII 字符，
/// 而 MinGW 的 `as.exe` / `ld.exe` **不带 UTF-8 清单**（实测 w64devkit 2.9.1
/// 的 244 个 exe 里只有 8 个带，`gcc.exe` 有、`as.exe`/`ld.exe` 没有），
/// 整条编译链遇到这种路径可能直接失败 —— 报的却是「找不到文件」，
/// 和学生的代码毫无关系，极难自查。
///
/// [TempWorkspace.chooseRoot] 刻意做成纯函数，就是为了让本机（macOS）
/// 也测得着 Windows 那几条分支。
void main() {
  group('chooseRoot', () {
    test('非 Windows：原样返回系统临时目录（不做任何改动）', () {
      expect(
        TempWorkspace.chooseRoot(
          isWindows: false,
          systemTemp: '/home/笑/tmp',
          programData: r'C:\ProgramData',
          systemRoot: r'C:\Windows',
        ),
        '/home/笑/tmp',
        reason: 'Linux/macOS 的工具链原生支持 UTF-8 路径，不该被干预',
      );
    });

    test('Windows + 系统临时目录已是纯 ASCII：原样用（多数机器的行为不变）', () {
      expect(
        TempWorkspace.chooseRoot(
          isWindows: true,
          systemTemp: r'C:\Users\xiao\AppData\Local\Temp',
          programData: r'C:\ProgramData',
          systemRoot: r'C:\Windows',
        ),
        r'C:\Users\xiao\AppData\Local\Temp',
      );
    });

    test('Windows + 中文用户名：改用 %ProgramData% 下的 ASCII 目录', () {
      expect(
        TempWorkspace.chooseRoot(
          isWindows: true,
          systemTemp: r'C:\Users\笑\AppData\Local\Temp',
          programData: r'C:\ProgramData',
          systemRoot: r'C:\Windows',
        ),
        r'C:\ProgramData\code_workbook\tmp',
      );
    });

    test('Windows + 连 %ProgramData% 都非 ASCII：退到 %SystemRoot%\\Temp', () {
      expect(
        TempWorkspace.chooseRoot(
          isWindows: true,
          systemTemp: r'C:\Users\笑\AppData\Local\Temp',
          programData: r'C:\程序数据',
          systemRoot: r'C:\Windows',
        ),
        r'C:\Windows\Temp\code_workbook',
      );
    });

    test('Windows + 全都不行：退回系统临时目录（能判题但可能失败，好过判不了）', () {
      expect(
        TempWorkspace.chooseRoot(
          isWindows: true,
          systemTemp: r'C:\Users\笑\AppData\Local\Temp',
          programData: r'C:\程序数据',
          systemRoot: r'C:\窗户',
        ),
        r'C:\Users\笑\AppData\Local\Temp',
      );
    });

    test('Windows + 环境变量缺失：不崩，能退就退', () {
      expect(
        TempWorkspace.chooseRoot(
          isWindows: true,
          systemTemp: r'C:\Users\笑\AppData\Local\Temp',
          programData: null,
          systemRoot: r'C:\Windows',
        ),
        r'C:\Windows\Temp\code_workbook',
      );
      expect(
        TempWorkspace.chooseRoot(
          isWindows: true,
          systemTemp: r'C:\Users\笑\AppData\Local\Temp',
          programData: '',
          systemRoot: null,
        ),
        r'C:\Users\笑\AppData\Local\Temp',
      );
    });
  });

  group('isPureAscii', () {
    test('纯 ASCII 判真，含非 ASCII 判假', () {
      expect(TempWorkspace.isPureAscii(r'C:\Users\xiao\AppData\Local\Temp'), isTrue);
      expect(TempWorkspace.isPureAscii('/tmp/judge_abc'), isTrue);
      expect(TempWorkspace.isPureAscii(r'C:\Users\笑\AppData'), isFalse);
      expect(TempWorkspace.isPureAscii(r'C:\Users\Jürgen\AppData'), isFalse);
      expect(TempWorkspace.isPureAscii(''), isTrue);
    });
  });

  group('compilerEnv', () {
    test('三个临时目录变量都指向工作目录，且是纯 ASCII', () {
      final dir = Directory(r'/tmp/judge_abc');
      final env = TempWorkspace.compilerEnv(dir);
      // gcc 依次看 TMPDIR → TMP → TEMP，三个都设上最保险
      for (final k in ['TMPDIR', 'TMP', 'TEMP']) {
        expect(env[k], dir.path, reason: '$k 应指向工作目录');
        expect(TempWorkspace.isPureAscii(env[k]!), isTrue);
      }
    });
  });

  group('create（本机真实行为）', () {
    test('建出来的目录可写、能删，且是纯 ASCII 路径', () async {
      final dir = await TempWorkspace.create('judge_test_');
      try {
        expect(dir.existsSync(), isTrue);
        // 本机是 macOS，chooseRoot 会原样返回系统临时目录
        expect(TempWorkspace.isPureAscii(dir.path), isTrue,
            reason: '实际：${dir.path}');
        final f = File('${dir.path}/solution.c');
        await f.writeAsString('int main(void){return 0;}');
        expect(await f.readAsString(), contains('main'));
      } finally {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      }
      expect(dir.existsSync(), isFalse, reason: '用完要能清干净');
    });

    test('连续两次建出来的是不同目录（不会互相踩）', () async {
      final a = await TempWorkspace.create('judge_test_');
      final b = await TempWorkspace.create('judge_test_');
      try {
        expect(a.path, isNot(b.path));
      } finally {
        for (final d in [a, b]) {
          try {
            await d.delete(recursive: true);
          } catch (_) {}
        }
      }
    });
  });
}
