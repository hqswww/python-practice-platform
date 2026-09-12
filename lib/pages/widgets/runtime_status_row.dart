import 'package:flutter/material.dart';

import '../../models/programming_language.dart';
import '../../services/language_runtime.dart';

/// 运行时自检结果那一行。
///
/// 设置页和首次运行向导共用 —— 两处必须给出一致的说法，否则用户会困惑
/// 「为什么向导说没问题、设置页说找不到」。
///
/// 为什么值得单独摆出来：环境缺件的失败发生在**判题时**，而那时学生已经写完
/// 代码了 —— 明明代码是对的，却弹一句「运行环境有问题」，最打击人。
class RuntimeStatusRow extends StatelessWidget {
  const RuntimeStatusRow({
    super.key,
    required this.language,
    required this.status,
  });

  final ProgrammingLanguage language;

  /// null 表示还没检测过（显示占位）
  final RuntimeStatus? status;

  @override
  Widget build(BuildContext context) {
    final st = status;
    if (st == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('正在检测…', style: TextStyle(fontSize: 12)),
      );
    }

    final ok = st.available;
    final color = ok ? Colors.green : Colors.orange;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle_outline : Icons.error_outline,
                  size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                ok ? '已就绪' : '未找到${language.compiled ? '编译器' : '解释器'}',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 不可用时给出「怎么补」，可用时给出「实际用的是哪一个」——
          // 装了多个版本时（系统 python3 vs Homebrew python3）这句很关键。
          SelectableText(
            ok ? '实际使用：${st.resolved}' : (st.hint ?? ''),
            style: TextStyle(fontSize: 12, height: 1.5, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }
}
