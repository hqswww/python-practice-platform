#!/usr/bin/env python3
"""给 02_datatype.json 的 6 题（201-206）加 runoob 风格详细教程。"""
import json

PATH = "assets/problems/python/02_datatype.json"

tutorials = {
201: [
  {
    "title": "整数的四则运算",
    "body": "Python 里整数（int）可以直接做加减乘除。\n加 +、减 -、乘 *、除 /。\n\n注意：除法 / 得到的结果是浮点数（带小数点），而 // 是整除，只保留整数部分。",
    "code": "print(10 + 3)   # 加\nprint(10 - 3)   # 减\nprint(10 * 3)   # 乘\nprint(10 / 3)   # 真除法,结果是浮点\nprint(10 // 3)  # 整除,向下取整",
    "output": "13\n7\n30\n3.3333333333333335\n3"
  },
  {
    "title": "整除 // 是向下取整",
    "body": "// 整除有一个容易踩的坑：它对负数是「向下取整」。\n在 Python 里，-7 // 2 的结果是 -4（而不是 -3），因为 -3.5 向下取整是 -4。\n\n多数现代语言和 Python 的行为一致，C/C++ 的整除是向零取整，注意区别。",
    "code": "print(7 // 2)    # 3\nprint(-7 // 2)   # -4,向下取整",
    "output": "3\n-4"
  },
  {
    "title": "本题完整解法",
    "body": "读入两个整数，分别输出和、差、积、整除商。\nmap(int, input().split()) 可以把输入的一行数字一次性转成整数。",
    "code": "a, b = map(int, input().split())\nprint(a + b)\nprint(a - b)\nprint(a * b)\nprint(a // b)",
    "output": "13\n7\n30\n3"
  }
],
202: [
  {
    "title": "读入小数用 float()",
    "body": "上一题我们用 int() 转整数。\n这一题输入是小数（如 3.14159），要用 float() 转成浮点数（float）。\n\nfloat() 能把 \"3.14159\" 这样的字符串转成浮点数。",
    "code": "n = input()       # 得到字符串 \"3.14159\"\nn = float(n)      # 转成浮点数 3.14159"
  },
  {
    "title": "保留两位小数",
    "body": "要输出保留两位小数，用 f-string 的格式化：{变量:.2f}。\n.2f 表示保留 2 位小数，f 表示按浮点数格式。\n\n它还会自动补零：5.0 会变成 5.00。",
    "code": "n = 3.14159\nprint(f\"{n:.2f}\")   # 3.14\nn2 = 5.0\nprint(f\"{n2:.2f}\")  # 5.00",
    "output": "3.14\n5.00"
  },
  {
    "title": "浮点数的小误差",
    "body": "计算机用二进制存浮点数，有些小数无法精确表示，会产生微小误差。\n比如 2.675 这样的小数，直接格式化可能出现意外结果（得到 2.67 而非四舍五入的 2.68）。\n\n这是浮点数的固有限制，初学者了解即可，不影响本题通过。",
    "code": "print(f\"{2.675:.2f}\")   # 可能输出 2.67"
  }
],
203: [
  {
    "title": "商和余数",
    "body": "除法有两个相关运算：\n商 = a // b（整除）\n余数 = a % b（取模/取余）\n\n比如 17 除以 5，商是 3，余数是 2，因为 3×5+2=17。",
    "code": "print(17 // 5)   # 商 3\nprint(17 % 5)    # 余数 2",
    "output": "3\n2"
  },
  {
    "title": "一次输出两个值",
    "body": "print() 里可以放多个值，用逗号分隔，输出时用空格隔开。\n这样就能把商和余数一次输出成一行：",
    "code": "a, b = map(int, input().split())\nprint(a // b, a % b)",
    "output": "3 2"
  }
],
204: [
  {
    "title": "代入公式",
    "body": "这题就是把华氏温度 F 代入摄氏温度公式：C = (F - 32) × 5 / 9。\n把公式原样翻译成 Python 表达式即可。要注意括号的对应。",
    "code": "f = float(input())\nc = (f - 32) * 5 / 9"
  },
  {
    "title": "保留一位小数",
    "body": "题目要求保留一位小数，用 f-string 的 {c:.1f}。\n.1f 保留 1 位小数。\n\n32 华氏度是水的冰点，代入得 0.0，输出正确。",
    "code": "f = float(input())\nc = (f - 32) * 5 / 9\nprint(f\"{c:.1f}\")",
    "output": "37.8"
  }
],
205: [
  {
    "title": "交换的常规写法",
    "body": "要交换 a 和 b 的值，很多语言需要一个中间变量 temp 帮个忙：\n先把 a 存到 temp，再把 b 赋给 a，最后把 temp 赋给 b。",
    "code": "temp = a\na = b\nb = temp"
  },
  {
    "title": "Python 的一行交换",
    "body": "Python 有一个超方便的特性：可以直接 a, b = b, a 完成交换。\n右边的 b, a 会先打包成元组 (b, a)，再按顺序分别赋给 a 和 b。\n完全不需要中间变量，非常优雅。",
    "code": "a, b = input().split()\na, b = b, a   # 一行交换\nprint(a, b)"
  }
],
206: [
  {
    "title": "求平均值",
    "body": "平均值 = 总和 / 个数。\n先把输入读成列表，用 sum() 求和，用 len() 求个数，两者相除。\n\n注意要用 /（真除法，得浮点数），不要用 //。",
    "code": "nums = list(map(int, input().split()))\ntotal = sum(nums)\ncount = len(nums)\navg = total / count"
  },
  {
    "title": "保留两位小数",
    "body": "用 f-string 的 {avg:.2f} 保留两位小数。\n85、90、80 的平均数是 85.0，输出成 85.00。",
    "code": "nums = list(map(int, input().split()))\navg = sum(nums) / len(nums)\nprint(f\"{avg:.2f}\")",
    "output": "85.00"
  }
],
}

with open(PATH, encoding="utf-8") as f:
    data = json.load(f)

for item in data:
    if item["id"] in tutorials:
        item["tutorial"] = tutorials[item["id"]]
        print(f"已添加 tutorial → {item['id']} {item['title']}")

with open(PATH, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")

print("写入完成")
