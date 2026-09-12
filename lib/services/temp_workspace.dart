/// 判题 / 运行用的临时工作目录。
///
/// ## 为什么不直接用 `Directory.systemTemp`
///
/// Windows 上用户名很可能是中文，于是 `%TEMP%` 就是
/// `C:\Users\笑\AppData\Local\Temp` —— **路径里带非 ASCII 字符**。
///
/// 而 MinGW 工具链对这种路径的支持是**残缺的**：实测 w64devkit 2.9.1 的
/// `bin` 下 244 个 exe 里只有 8 个带 `<activeCodePage>UTF-8</activeCodePage>`
/// 清单 —— `gcc.exe` / `g++.exe` 有，**`as.exe` / `ld.exe` 没有**。
/// 汇编器和链接器仍按系统 ANSI 代码页解析路径，于是「路径含中文」时
/// 整条编译链可能在汇编或链接那一步失败。
///
/// 这种失败的可怕之处在于**报错完全指不到原因**：它说的是「找不到文件」，
/// 学生会以为自己的代码有问题，老师也想不到是用户名的事。
/// 参见 niXman/mingw-builds-binaries#61（一位中文开发者报的同一问题，
/// 受影响版本涵盖 MinGW-w64 11.2 / 12.2 / 13.2）。
///
/// ## 怎么办
///
/// 与其指望每个工具链都把清单打全（那不受我们控制），不如**让整条链根本
/// 看不到非 ASCII 路径**：判题的工作目录只放纯 ASCII 的位置；
/// 编译时再把 `TMPDIR`/`TEMP`/`TMP` 也指过去，这样 gcc 产生的中间文件
/// （`.s` / `.o`）同样落在 ASCII 路径下。
///
/// ## 其它平台
///
/// Linux / macOS 的路径本来就是 UTF-8，工具链原生支持，**不做任何改动** ——
/// 只有 Windows 会走到下面那套候选逻辑。
library;

import 'dart:io';

abstract final class TempWorkspace {
  /// 根目录下自己那层目录名。放在 `%ProgramData%` 下而不是用户目录，
  /// 正是为了绕开中文用户名。
  static const String _dirName = 'code_workbook';

  /// 判断字符串是否**纯 ASCII**（非 ASCII 字符就是我们要躲的东西）
  static bool isPureAscii(String s) => !s.contains(RegExp(r'[^\x00-\x7F]'));

  /// 选出工作目录的根。
  ///
  /// **纯函数**，不碰文件系统 —— Windows 分支在本机（macOS）永远跑不到，
  /// 只有这样才测得着。
  ///
  /// 规则：
  /// 1. 系统临时目录本身就是纯 ASCII（绝大多数机器）→ 原样用它，行为不变
  /// 2. 否则依次尝试其它 ASCII 候选（`%ProgramData%` → `%SystemRoot%\Temp`）
  /// 3. 全都不行 → 退回系统临时目录（有风险，但总比判不了题好）
  static String chooseRoot({
    required bool isWindows,
    required String systemTemp,
    String? programData,
    String? systemRoot,
  }) {
    if (!isWindows) return systemTemp;
    if (isPureAscii(systemTemp)) return systemTemp;

    // Windows 路径用反斜杠；这段本来就只在 Windows 上生效
    const sep = r'\';
    final candidates = <String>[
      if (programData != null && programData.isNotEmpty)
        '$programData$sep$_dirName${sep}tmp',
      if (systemRoot != null && systemRoot.isNotEmpty)
        '$systemRoot${sep}Temp$sep$_dirName',
    ];
    for (final c in candidates) {
      if (isPureAscii(c)) return c;
    }
    return systemTemp;
  }

  /// 在选好的根下建一个工作目录（判题 / 交互运行各用各的）。
  ///
  /// 建不出来（权限、组策略）就退回系统临时目录 —— 那时又有了中文路径的风险，
  /// 但「能判题但可能失败」好过「直接判不了」。
  static Future<Directory> create(String prefix) async {
    final root = chooseRoot(
      isWindows: Platform.isWindows,
      systemTemp: Directory.systemTemp.path,
      programData: Platform.environment['ProgramData'],
      systemRoot: Platform.environment['SystemRoot'],
    );
    try {
      final dir = Directory(root);
      if (!dir.existsSync()) await dir.create(recursive: true);
      return await dir.createTemp(prefix);
    } catch (_) {
      return Directory.systemTemp.createTemp(prefix);
    }
  }

  /// 编译型语言要覆盖的环境变量：把编译器的临时文件也钉在 ASCII 路径下。
  ///
  /// 只给**编译**这一步用。原因：
  /// - gcc 会把汇编结果写成临时 `.s` 再交给 `as`，`as` 不带 UTF-8 清单，
  ///   这正是最可能出问题的一环
  /// - 链接产物落在工作目录里（已经是 ASCII），不需要额外处理
  ///
  /// 刻意**不**给 Python 用：那会把学生自己代码的临时目录也改掉，
  /// 而 Python 本来就不需要（它原生支持 UTF-8 路径）。
  static Map<String, String> compilerEnv(Directory workDir) => {
        // gcc 依次看 TMPDIR → TMP → TEMP，三个都设上最保险
        'TMPDIR': workDir.path,
        'TMP': workDir.path,
        'TEMP': workDir.path,
      };
}
