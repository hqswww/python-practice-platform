#!/usr/bin/env python3
"""应用图标生成器（macOS appiconset + Windows .ico）

用法：
    uv run --with pillow python tools/make_icons.py [源图] [--region 区域]

    --region  top-left（默认） 取左上正方形区域
              center           取中心正方形区域
              whole            整图补白成正方形

为什么要用 uv：
    本机没装 Pillow，而它只在这一步用得上。`uv run --with pillow` 会临时取一份，
    不往系统里装东西，也不污染项目依赖。

设计要点（踩过的坑）：
  1. **圆角遮罩来自 tools/icon_mask_1024.png**，那是从 Flutter 模板图标的
     alpha 通道提取的。Apple 的图标圆角是连续曲率（squircle），不是圆弧，
     手画很难和系统上其它 App 对齐——直接沿用模板最稳。
     ⚠️ 千万不要改成「读当前 app_icon_1024.png 的 alpha」：脚本跑第二遍时
     那张图已经是自己生成的产物了，遮罩会越缩越小。
  2. macOS 产出 7 张（16→1024），Windows 产出多尺寸 .ico，两者用同一份处理结果，
     保证双平台外观一致。
  3. .icns 不在这一步做：Xcode 从 asset catalog 编出来的只到 256×256，
     由 tools/build_macos.sh 在**签名之前**用 iconutil 重打完整阶梯。
"""

import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit(
        "缺少 Pillow。请用：\n"
        "    uv run --with pillow python tools/make_icons.py\n"
    )

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SRC = os.path.expanduser('~/Documents/icon.png')
ICONSET = os.path.join(ROOT, 'macos/Runner/Assets.xcassets/AppIcon.appiconset')
MASK = os.path.join(ROOT, 'tools/icon_mask_1024.png')
ICO = os.path.join(ROOT, 'windows/runner/resources/app_icon.ico')

MAC_SIZES = (16, 32, 64, 128, 256, 512, 1024)
ICO_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]


def square_crop(img, region):
    """按指定策略把任意尺寸的图变成正方形"""
    w, h = img.size
    side = min(w, h)
    if region == 'top-left':
        return img.crop((0, 0, side, side))
    if region == 'center':
        return img.crop(((w - side) // 2, (h - side) // 2,
                         (w - side) // 2 + side, (h - side) // 2 + side))
    if region == 'whole':
        canvas = Image.new('RGB', (max(w, h), max(w, h)), (255, 255, 255))
        canvas.paste(img, ((max(w, h) - w) // 2, (max(w, h) - h) // 2))
        return canvas
    raise SystemExit(f'未知的 --region: {region}（可选 top-left / center / whole）')


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    region = 'top-left'
    if '--region' in sys.argv:
        region = sys.argv[sys.argv.index('--region') + 1]
    src_path = args[0] if args else DEFAULT_SRC

    if not os.path.exists(src_path):
        raise SystemExit(f'源图不存在: {src_path}')
    if not os.path.exists(MASK):
        raise SystemExit(
            f'缺少圆角遮罩 {MASK}\n'
            '可从 Flutter 模板恢复：重跑 flutter create --platforms=macos . '
            '后重新提取其 app_icon_1024.png 的 alpha 通道。'
        )

    src = Image.open(src_path).convert('RGB')
    print(f'源图: {src_path}  {src.size[0]}x{src.size[1]}  区域={region}')

    squared = square_crop(src, region).resize((1024, 1024), Image.LANCZOS)
    mask = Image.open(MASK).convert('L')
    print(f'遮罩: {mask.size}  不透明区域 {mask.getbbox()}')

    icon = squared.convert('RGBA')
    icon.putalpha(mask)

    for s in MAC_SIZES:
        icon.resize((s, s), Image.LANCZOS).save(
            os.path.join(ICONSET, f'app_icon_{s}.png'))
    print(f'✅ macOS: 写入 {len(MAC_SIZES)} 张 -> {os.path.relpath(ICONSET, ROOT)}')

    icon.save(ICO, format='ICO', sizes=ICO_SIZES)
    print(f'✅ Windows: 写入 {os.path.relpath(ICO, ROOT)} '
          f'({len(ICO_SIZES)} 个尺寸, {os.path.getsize(ICO)} bytes)')

    print('\n下一步：bash tools/build_macos.sh（会自动重打完整尺寸的 .icns）')


if __name__ == '__main__':
    main()
