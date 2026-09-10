#!/usr/bin/env python3
"""给 03_operators.json 的 6 题（301-306）加 runoob 风格详细教程。"""
import json

PATH = "assets/problems/python/03_operators.json"

tutorials = {
301: [
  {
    "title": "五种算术运算符",
    "body": "这一题把之前见过的算术运算符一次用全：\n加 +、减 -、乘 *、除 /、取余 %。\n\n其中除法 / 得到的是浮点数，取余 % 得到的是两数相除的余数。",
    "code": "a, b = 7, 3\nprint(a + b)   # 和\nprint(a - b)   # 差\nprint(a * b)   # 积\nprint(a / b)   # 商(浮点)\nprint(a % b)   # 余数",
    "output": "10\n4\n21\n2.3333333333333335\n1"
  },
  {
    "title": "商要求保留一位小数",
    "body": "题目要求商保留一位小数（7÷3 应输出 2.3 而非 2.333…）。\n用 f-string 的 {a / b:.1f} 格式化，.1f 表示保留 1 位小数。",
    "code": "a, b = map(int, input().split())\nprint(f\"{a / b:.1f}\")   # 7/3 -> 2.3",
    "output": "2.3"
  }
],
302: [
  {
    "title": "比较运算的结果是布尔值",
    "body": "比较运算符 > >= < <= == != 用来比较两个值的大小或是否相等。\n\n它们的结果不是数字，而是布尔值（boolean）：True（真）或 False（假）。",
    "code": "print(5 > 3)     # True\nprint(5 == 3)    # False\nprint(5 != 3)    # True(不等)",
    "output": "True\nFalse\nTrue"
  },
  {
    "title": "本题完整写法",
    "body": "按题目要求的顺序，依次 print 五个比较运算的结果即可。\n注意 == 是判断相等（两个等号），单个 = 是赋值，别搞混。",
    "code": "a, b = map(int, input().split())\nprint(a > b)\nprint(a >= b)\nprint(a < b)\nprint(a <= b)\nprint(a == b)",
    "output": "True\nTrue\nFalse\nFalse\nFalse"
  }
],
303: [
  {
    "title": "逻辑运算 and / or / not",
    "body": "逻辑运算符用来组合多个条件：\nand（与）：两边都真才为真。\nor（或）：只要一边为真即为真。\nnot（非）：取反，真变假、假变真。\n\n可以用「且」「或」「不」来记忆。",
    "code": "print(True and True)    # True\nprint(True and False)   # False\nprint(True or False)    # True\nprint(not True)         # False",
    "output": "True\nFalse\nTrue\nFalse"
  },
  {
    "title": "把判断组合起来",
    "body": "题目要判断 a 是否为正数（a > 0），再用逻辑运算与 b 组合。\n比如 a=5, b=-1：\n(a>0) and (b>0)：5>0 真 且 -1>0 假 → False\n(a>0) or (b>0)：5>0 真 → True\nnot (a>0)：5>0 真，取反 → False",
    "code": "a, b = map(int, input().split())\nprint(a > 0 and b > 0)\nprint(a > 0 or b > 0)\nprint(not a > 0)",
    "output": "False\nTrue\nFalse"
  }
],
304: [
  {
    "title": "幂运算用 **",
    "body": "要算 a 的 b 次方（a^b），Python 用双星号 **。\n比如 2 的 10 次方 = 2 ** 10 = 1024。\n\n注意不要用 ^——在 Python 里 ^ 是位运算（异或），不是幂。",
    "code": "print(2 ** 10)   # 1024\nprint(3 ** 3)    # 27\nprint(5 ** 0)    # 任何数的 0 次方 = 1",
    "output": "1024\n27\n1"
  }
],
305: [
  {
    "title": "/ 和 // 的区别",
    "body": "这是最容易混淆的一对运算符：\n/（一个斜杠）= 浮点除法，结果带小数。\n//（两个斜杠）= 整除，只保留整数部分（向下取整）。\n\n7 / 2 = 3.5，而 7 // 2 = 3。",
    "code": "print(7 / 2)    # 3.5\nprint(7 // 2)   # 3\nprint(7 % 2)    # 取余:1",
    "output": "3.5\n3\n1"
  },
  {
    "title": "浮点数的整除也有坑",
    "body": "7.0 / 2 的结果是 3.5（因为作了浮点除法）。\n当操作数里有一个是浮点数时，结果通常也是浮点数。\n\n这题正好让你对比：7/2 和 7.0/2 都是 3.5，但 7//2 是 3。",
    "code": "print(7.0 / 2)   # 浮点除法\nprint(7 // 2)    # 整除",
    "output": "3.5\n3"
  }
],
306: [
  {
    "title": "运算符的优先级",
    "body": "Python 和数学一样有运算优先级：\n先算幂 **，再算乘除 * / %，最后算加减 + -。\n同级从左到右。",
    "code": "# ** 最高,然后 * / %,最后 + -\nprint(2 + 3 * 4 ** 2)"
  },
  {
    "title": "一步步算",
    "body": "2 + 3 * 4 ** 2 的计算顺序：\n① 先算幂：4 ** 2 = 16\n② 再算乘法：3 * 16 = 48\n③ 最后加法：2 + 48 = 50\n\n所以结果是 50。想改变优先级就用小括号 ()。",
    "code": "print(2 + 3 * 4 ** 2)   # 50\nprint((2 + 3) * 4 ** 2)  # 用括号改变顺序:5*16=80",
    "output": "50\n80"
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
