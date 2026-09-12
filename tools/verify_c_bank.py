#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""C 题库自检：编译每道题的参考答案，跑它自己的测试用例，比对输出。

用法（项目根目录）：
    python3 tools/verify_c_bank.py            # 校验全部分类
    python3 tools/verify_c_bank.py 09_pointers  # 只校验某一个分类

为什么单独写这个而不是只靠 flutter test：
    编译 72 道题要反复迭代改代码，flutter test 每次启动要好几秒。
    这个脚本只调 clang，一轮几秒钟，写题时迭代快得多。
    Flutter 那边有一条同样的自检测试作为最终闸门（用真判题引擎跑），
    两边都要过。

比对规则**必须和判题引擎一致**（judge_engine.dart 的 _normalizeLines）：
    统一换行 → 去掉每行尾随空白 → 去掉首尾空行 → 全角/半角标点等价。
"""

import json
import glob
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BANK = os.path.join(ROOT, 'assets/problems/c')

# 全角/半角标点等价（与 judge_engine.dart 的 _normalizePunctuation 对齐）
PUNCT = {
    '，': ',', '。': '.', '！': '!', '？': '?', '：': ':', '；': ';',
    '（': '(', '）': ')', '【': '[', '】': ']', '“': '"', '”': '"',
    '‘': "'", '’': "'", '、': ',',
}


def normalize(s: str) -> str:
    for a, b in PUNCT.items():
        s = s.replace(a, b)
    s = s.replace('\r\n', '\n').replace('\r', '\n')
    lines = [re.sub(r'\s+$', '', l) for l in s.split('\n')]
    while lines and lines[0] == '':
        lines.pop(0)
    while lines and lines[-1] == '':
        lines.pop()
    return '\n'.join(lines)


def compile_one(src: str, workdir: str):
    """返回 (可执行文件路径, 错误信息)"""
    src_path = os.path.join(workdir, 'solution.c')
    exe_path = os.path.join(workdir, 'solution')
    with open(src_path, 'w', encoding='utf-8') as f:
        f.write(src)
    r = subprocess.run(
        ['clang', src_path, '-o', exe_path, '-std=c11', '-O0', '-lm'],
        capture_output=True, text=True, timeout=60,
    )
    if r.returncode != 0:
        return None, (r.stdout + r.stderr).strip()
    return exe_path, None


def run_case(exe: str, stdin: str, timeout=5):
    try:
        r = subprocess.run(exe, input=stdin, capture_output=True,
                           text=True, timeout=timeout)
        return r.stdout, r.returncode
    except subprocess.TimeoutExpired:
        return None, 'TIMEOUT'


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    files = sorted(glob.glob(os.path.join(BANK, '*.json')))
    if only:
        files = [f for f in files if only in f]
    if not files:
        print('没找到题库文件')
        return 1

    total = ok = 0
    failures = []

    for path in files:
        name = os.path.basename(path)
        with open(path, encoding='utf-8') as f:
            problems = json.load(f)
        print(f'\n══ {name}（{len(problems)} 题）══')

        # 结构自检
        for p in problems:
            for field in ('id', 'title', 'difficulty', 'description',
                          'input_format', 'output_format', 'sample_input',
                          'sample_output', 'test_cases', 'hints', 'solution',
                          'tutorial'):
                if field not in p:
                    failures.append(f'{name} 题 {p.get("id")} 缺字段 {field}')
            if not p.get('test_cases'):
                failures.append(f'{name} 题 {p.get("id")} 没有测试用例')
            if not p.get('solution', '').strip():
                failures.append(f'{name} 题 {p.get("id")} 没有参考答案')

        for p in problems:
            total += 1
            pid, title = p['id'], p['title']
            with tempfile.TemporaryDirectory() as wd:
                exe, err = compile_one(p['solution'], wd)
                if err:
                    print(f'  ✗ [{pid}] {title} —— 编译失败')
                    print('      ' + err.replace('\n', '\n      ')[:600])
                    failures.append(f'{name} [{pid}] {title}: 编译失败')
                    continue

                bad = None
                for i, tc in enumerate(p['test_cases']):
                    out, code = run_case(exe, tc['input'])
                    if out is None:
                        bad = f'用例 {i+1} 超时'
                        break
                    if normalize(out) != normalize(tc['output']):
                        bad = (f'用例 {i+1} 输出不符\n'
                               f'        输入: {tc["input"]!r}\n'
                               f'        期望: {tc["output"]!r}\n'
                               f'        实际: {out!r}\n'
                               f'        退出码: {code}')
                        break
                if bad:
                    print(f'  ✗ [{pid}] {title} —— {bad}')
                    failures.append(f'{name} [{pid}] {title}: 用例不过')
                else:
                    ok += 1
                    print(f'  ✓ [{pid}] {title}（{len(p["test_cases"])} 用例）')

    print(f'\n{"="*56}')
    print(f'结果：{ok}/{total} 题参考答案通过')
    if failures:
        print(f'\n未通过 {len(failures)} 项：')
        for f in failures:
            print(f'  · {f}')
        return 1
    print('全部通过 ✅')
    return 0


if __name__ == '__main__':
    sys.exit(main())
