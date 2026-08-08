#!/usr/bin/env python3
"""给 04_conditionals.json 的 6 题（401-406）加详细教程（核心分类，写更详细）。"""
import json

PATH = "assets/problems/04_conditionals.json"

tutorials = {
401: [
  {
    "title": "条件判断 if 是什么",
    "body": "程序不只会从头到尾执行，还要「根据情况做不同的事」。\nif 语句就是 Python 里的「如果……就……」：满足条件就执行里面的代码。\n\n基本写法：\nif 条件：\n    【缩进】要执行的代码\n\n注意两个关键点：①条件后面要写冒号 :；②满足条件执行的代码要缩进（用 4 个空格）。缩进是 Python 的分组方式，非常重要。",
    "code": "n = 4\nif n % 2 == 0:\n    print(\"偶数\")    # 满足条件才会执行这里",
    "output": "偶数"
  },
  {
    "title": "if / else 二选一",
    "body": "else 是「否则」：条件不成立时，执行 else 下面的代码。\n\nif / else 构成了「二选一」：一个条件，两条路，必走其一。",
    "code": "n = 7\nif n % 2 == 0:\n    print(\"偶数\")\nelse:\n    print(\"奇数\")    # n%2!=0 时执行这里",
    "output": "奇数"
  },
  {
    "title": "用余数判断奇偶",
    "body": "判断一个数奇偶，最简单的办法是看它除以 2 的余数：\n余数为 0 → 偶数（能被 2 整除）\n余数为 1 → 奇数\n\n用 % 运算符：n % 2 == 0 就是「能被 2 整除」。\n注意余数判断对负数也适用，0 被当作偶数。",
    "code": "n = int(input())\nif n % 2 == 0:\n    print(\"偶数\")\nelse:\n    print(\"奇数\")",
    "output": "偶数"
  }
],
402: [
  {
    "title": "思路：比较后选一个",
    "body": "要求输出较大的那个数。核心思路：\n如果 a > b，就输出 a；否则（a <= b）输出 b。\n\n注意：a == b 时走 else 输出 b，结果和 a 一样，所以没问题。",
    "code": "a, b = map(int, input().split())\nif a > b:\n    print(a)\nelse:\n    print(b)",
    "output": "9"
  },
  {
    "title": "偷懒方案：max()",
    "body": "其实 Python 内置了求最大值的函数 max()，一次能传多个参数：\n\n一行就能搞定，不用写 if。但学习阶段还是建议先理解 if 的写法。",
    "code": "a, b = map(int, input().split())\nprint(max(a, b))   # 内置函数直接求最大",
    "output": "9"
  }
],
403: [
  {
    "title": "多分支：if / elif / else",
    "body": "当有多个互斥的判断时，用 elif（else if 的缩写，意思是「否则如果」）。\n\n写法是一连串：\nif 条件1: …\nelif 条件2: …\nelif 条件3: …\nelse: …\n\nPython 会从上到下检查，遇到第一个成立的条件就执行它，后面的都不看了。",
    "code": "score = 85\nif score >= 90:\n    print(\"A\")\nelif score >= 80:\n    print(\"B\")     # 85>=90 不成立,但 85>=80 成立,输出 B\nelse:\n    print(\"E\")",
    "output": "B"
  },
  {
    "title": "关键技巧：判断顺序要讲究",
    "body": "多分支最怕范围重叠。比如成绩分段 90/80/70/60 分界。\n\n如果写成 `elif score >= 60` 在前、`>=90` 在后，那么 95 分也会先命中 >=60 输出 D，就错了。\n\n正确做法：从高分到低分依次判断（90 → 80 → 70 → 60），这样 95 先命中 >=90 输出 A。因为条件一旦命中就停止，后面的高分条件才能拦住高分。",
    "code": "# 从高往低判断,否则会被低分条件提前拦住\nif score >= 90:\n    print(\"A\")\nelif score >= 80:\n    print(\"B\")\nelif score >= 70:\n    print(\"C\")\nelif score >= 60:\n    print(\"D\")\nelse:\n    print(\"E\")",
    "output": "B"
  }
],
404: [
  {
    "title": "闰年的规则",
    "body": "闰年判断是世界通用规则，用逻辑说清楚：\n「能被 4 整除，但不能被 100 整除」——这是一般规则。\n「或者能被 400 整除」——这是例外，比如 2000 年。\n\n所以两个条件用 or 连接：\n能被400整除 → 闰年；否则，能被4整除且不能被100整除 → 闰年。",
    "code": "# 规则用括号让逻辑更清晰\n(year % 4 == 0 and year % 100 != 0) or year % 400 == 0"
  },
  {
    "title": "拆开理解 and / or",
    "body": "用几个例子验证：\n2024：能被4整除(✔)、不能被100整除(✔) → 闰年\n2023：不能被4整除 → 不是闰年\n2000：能被4整除、但能被100整除，前半句 ✘；但能被400整除 ✔ → 闰年\n1900：能被4整除、被100整除，前半句 ✘；不能被400整除 ✘ → 不是闰年\n\n这就是为什么闰年规则要带上「或能被400整除」这个例外。",
    "code": "year = int(input())\nif (year % 4 == 0 and year % 100 != 0) or year % 400 == 0:\n    print(\"yes\")\nelse:\n    print(\"no\")",
    "output": "yes"
  }
],
405: [
  {
    "title": "三选一判断",
    "body": "正数、负数、零，三种情况互斥，用 if / elif / else 分成三路：\nif n > 0 → 正数\nelif n < 0 → 负数\nelse → 零（既不是正也不是负）\n\n注意先判断 n > 0，再 elif n < 0，最后 else 兜底（剩下的只能是非正非负，即 0）。",
    "code": "n = int(input())\nif n > 0:\n    print(\"正数\")\nelif n < 0:\n    print(\"负数\")\nelse:\n    print(\"零\")",
    "output": "正数"
  }
],
406: [
  {
    "title": "用 and 组合多个条件",
    "body": "三个数取最大，可以把「a 最大」翻译成：a 同时 >= b 且 >= c。\n两个条件用 and 连接：\n\nif a >= b and a >= c → a 最大\nelif b >= a and b >= c → b 最大\nelse → c 最大",
    "code": "a, b, c = map(int, input().split())\nif a >= b and a >= c:\n    print(a)\nelif b >= a and b >= c:\n    print(b)\nelse:\n    print(c)   # 剩下只能是 c 最大",
    "output": "8"
  },
  {
    "title": "更简单的方案：max()",
    "body": "和 402 一样，Python 的 max() 可以一次传任意多个参数，直接返回最大。\n\n一行解决，适合偷懒；但理解上面 if 的写法对逻辑能力更有帮助。",
    "code": "a, b, c = map(int, input().split())\nprint(max(a, b, c))",
    "output": "8"
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
