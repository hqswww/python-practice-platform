#!/usr/bin/env python3
"""把 docs/releases/*.md 合成 assets/CHANGELOG.md（应用内「关于 → 更新日志」看的）。

为什么要生成而不是手写两份：
  每次发版都会写一份 docs/releases/<版本>.md（GitHub Release 的正文就是它）。
  应用里要看的更新日志是同一批内容 —— 手抄一份必然漂移，
  而漂移是静默的（没人会发现应用里的日志少了一版）。
  所以定成：docs/releases/ 是唯一手写来源，assets/CHANGELOG.md 是生成物。

用法：
    python3 tools/build_changelog.py            # 生成/覆盖
    python3 tools/build_changelog.py --check    # 只检查是否最新（发布闸门用，落后则退出码 1）
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RELEASES_DIR = ROOT / "docs" / "releases"
OUT = ROOT / "assets" / "CHANGELOG.md"

HEADER = """# 更新日志

本文件由 `tools/build_changelog.py` 从 `docs/releases/` 生成，**不要手改**。
每个版本的完整说明见项目仓库的 Releases 页面。

"""


def parse_version(name: str) -> tuple[int, ...]:
    """从文件名里取出可比较的版本号：v1.5.1 → (1, 5, 1)。取不到就排最后。"""
    m = re.search(r"v?(\d+)\.(\d+)\.(\d+)", name)
    if not m:
        return (0, 0, 0)
    return tuple(int(g) for g in m.groups())


def build() -> str:
    files = sorted(RELEASES_DIR.glob("*.md"), key=lambda p: parse_version(p.name), reverse=True)
    if not files:
        raise SystemExit(f"❌ {RELEASES_DIR} 里一个 .md 都没有，没法生成更新日志")

    parts = [HEADER]
    for i, f in enumerate(files):
        body = f.read_text(encoding="utf-8").strip()
        if not body:
            raise SystemExit(f"❌ {f.name} 是空的")
        if i > 0:
            # 版本之间空一行 + 分隔线：应用侧按「行首 # 」切版本小节，
            # 分隔线只是让纯文本读起来有段落感（显示前会被清掉）
            parts.append("\n---\n\n")
        parts.append(body + "\n")
    return "".join(parts)


def main() -> int:
    generated = build()

    if "--check" in sys.argv:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != generated:
            print(f"❌ {OUT.relative_to(ROOT)} 与 docs/releases/ 不一致，跑一下：")
            print("   python3 tools/build_changelog.py")
            return 1
        print(f"✅ {OUT.relative_to(ROOT)} 是最新的")
        return 0

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(generated, encoding="utf-8")
    n = len(list(RELEASES_DIR.glob("*.md")))
    print(f"✅ 已生成 {OUT.relative_to(ROOT)}（{n} 个版本，{len(generated)} 字）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
