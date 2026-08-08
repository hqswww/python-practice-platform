#!/usr/bin/env python3
"""给 12_challenges.json 的 6 题（1201-1206）加详细教程（综合挑战：质数/斐波那契/回文/元音/数根/最大公约数）。"""
import json

PATH = "assets/problems/12_challenges.json"

tutorials = {
1201: [
  {
    "title": "质数的定义",
    "body": "质数（素数）是只能被 1 和它本身整除的正整数。\n2、3、5、7 是质数；1 不是质数（规定）。\n\n先处理边界：小于 2 的数直接不是质数，输出 False。",
    "code": "n = int(input())\nif n < 2:\n    print(False)   # 0 和 1 不是质数"
  },
  {
    "title": "从 2 试到 sqrt(n)",
    "body": "判断 n 是否质数：从 2 开始，看有没有能整除 n 的数。\n关键优化：只需要试到 sqrt(n) 就够。因为若 n = a×b，a、b 中必有一个 ≤ sqrt(n)。\n所以从 2 试到根号 n，有能整除的就是合数。\n\n用 math.isqrt(n)（整数平方根）或 int(n**0.5) 作为上界。",
    "code": "import math\nn = int(input())\nif n < 2:\n    print(False)\nelse:\n    is_prime = True\n    for i in range(2, int(math.isqrt(n)) + 1):\n        if n % i == 0:      # 被 i 整除 -> 不是质数\n            is_prime = False\n            break           # 找到一个就够,提前结束\n    print(is_prime)",
    "output": "True"
  },
  {
    "title": "为什么用 isqrt",
    "body": "isqrt(n) 返回 floor(sqrt(n))，是函数到 `int(n ** 0.5)`：\n它是整数平方根，用浮点 **0.5 对大数可能丢精度，isqrt 更精确。\n\n验证：n=9，isqrt(9)=3，检查 i=2、3。i=3 时 9%3==0，是合数 → False。",
    "code": "import math\nprint(math.isqrt(25))    # 5\nprint(math.isqrt(17))    # 4(向下取整)\nprint(17 ** 0.5)         # 4.123(浮点)",
    "output": "5\n4\n4.123105625617661"
  }
],
1202: [
  {
    "title": "斐波那契规律",
    "body": "斐波那契数列：第 1、2 项都是 1，之后每一项是前两项之和：\n1, 1, 2, 3, 5, 8, 13, …\n\n（1+1=2，1+2=3，2+3=5，3+5=8…）",
    "code": "a, b = 1, 1\nprint(a, b)   # 前两项都是 1\n# 下一项 = a+b = 2,然后整体前移"
  },
  {
    "title": "滚动更新 a, b = b, a + b",
    "body": "经典技巧：用两个变量滚动推进。\na, b = b, a + b 同时更新：\n新的 a 变成原来的 b；新的 b 变成原来的 a+b（下一项）。\n\n过程：\na=1,b=1 → a=1,b=2 → a=2,b=3 → a=3,b=5 …",
    "code": "a, b = 1, 1\nfor _ in range(6):\n    print(a, end=\" \")\n    a, b = b, a + b   # 同时更新\n# 输出 1 1 2 3 5 8",
    "output": "1 1 2 3 5 8"
  },
  {
    "title": "收集后一次输出",
    "body": "题目要求空格分隔、末尾无多余空格。用列表收集每一项，最后 ' '.join(map(str, fib)) 拼接。",
    "code": "n = int(input())\nfib = []\na, b = 1, 1\nfor _ in range(n):\n    fib.append(a)\n    a, b = b, a + b\nprint(' '.join(map(str, fib)))",
    "output": "1 1 2 3 5 8"
  }
],
1203: [
  {
    "title": "回文的定义",
    "body": "回文是正读反读都一样的字符串。比如 'abcba'、'madam'。\n判断方法就是：字符串等于它的反转。\n反转用切片 s[::-1]（之前学过）。",
    "code": "s = \"abcba\"\nprint(s == s[::-1])   # True\n\ns = \"hello\"\nprint(s == s[::-1])   # False",
    "output": "True\nFalse"
  },
  {
    "title": "忽略空格和大小写",
    "body": "题目要求忽略空格和大小写。步骤：\n① 去掉所有空格：s.replace(' ', '')\n② 统一小写：s.lower()\n\n'A man a plan a canal Panama' 去掉空格、转小写后是 'amanaplanacanalpanama'，判断它是否回文。",
    "code": "import re\ns = input()\ns = re.sub(r'\\s+', '', s).lower()   # 去所有空白+小写\nprint(s == s[::-1])",
    "output": "True"
  },
  {
    "title": "用正则去掉所有空白",
    "body": "replace(' ', '') 只能去掉普通空格。\n题目保证只含字母和空格，所以用 re.sub(r'\\s+', '', s) 去掉所有空白（含制表符等）更稳妥，但前者也够用。",
    "code": "s = \"A man a plan a canal Panama\"\nclean = s.replace(' ', '').lower()\nprint(clean)\nprint(clean == clean[::-1])   # True",
    "output": "amanaplanacanalpanama\nTrue"
  }
],
1204: [
  {
    "title": "转小写 + 逐个判断",
    "body": "元音字母是 a, e, i, o, u，要忽略大小写。\n先 .lower() 统一小写，然后遍历每个字符，判断它是否在元音集合里。\n\n用集合 set('aeiou') 存元音，ch in 集合 判断是 O(1)。",
    "code": "s = input().lower()\nvowels = set('aeiou')\ncount = 0\nfor ch in s:\n    if ch in vowels:\n        count += 1\nprint(count)",
    "output": "3"
  },
  {
    "title": "一行写法：sum 推导式",
    "body": "进阶写法：sum(1 for ch in s if ch in 'aeiou')。\n生成器里对每个元音字符产出 1，sum 累加就是元音个数。\n和上面的循环等价，但更简洁。",
    "code": "s = input().lower()\nprint(sum(1 for ch in s if ch in 'aeiou'))\n\n# 'Hello World' -> e,o,o 共3个",
    "output": "3"
  }
],
1205: [
  {
    "title": "数根是什么",
    "body": "这题是求「数根」（digital root）：反复把各位数字相加，直到只剩一位。\n38 → 3+8=11 → 1+1=2。12345 → 1+2+3+4+5=15 → 1+5=6。\n\n最简单的做法是 while 循环一次次加，直到一位数。",
    "code": "n = 38\n# 用 str(n) 拆成字符,再把每个字符转 int 相加\nprint(sum(map(int, str(n))))   # 3+8=11,再循环",
    "output": "11"
  },
  {
    "title": "循环到一位数",
    "body": "朴素解法：n >= 10 时，求它的各位和，重复。\n各位和用 sum(map(int, str(n)))：str(n) 变字符串，map(int,...) 每个字符转数字，sum 相加。",
    "code": "n = int(input())\nwhile n >= 10:\n    n = sum(map(int, str(n)))\nprint(n)\n# 38 -> 11 -> 2",
    "output": "2"
  },
  {
    "title": "更妙的数学技巧（取模）",
    "body": "数学里有公式：n 的数根 = n % 9（除了 0 和 9 的倍数特例）。\n因为 9 有个性质：一个数 mod 9 的余数等于它的各位数字和 mod 9。\n\n规律：\n· n == 0 → 数根 0\n· n % 9 == 0（如 9、18、27…）→ 数根 9\n· 否则 → n % 9\n\n这题虽然可以用 while 硬解，但了解取模技巧能开阔思路。",
    "code": "n = int(input())\nif n == 0:\n    print(0)\nelif n % 9 == 0:\n    print(9)\nelse:\n    print(n % 9)",
    "output": "2"
  }
],
1206: [
  {
    "title": "最大公约数是什么",
    "body": "最大公约数 G(greatest common divisor) 是能同时整除两个数的最大整数。\n12 和 18 的公约数有 1、2、3、6，最大是 6。\n7 和 13 没有公共因子，最大公约数是 1。",
    "code": "# 12 和 18 的公约数\nprint([i for i in range(1, 13) if 12%i==0 and 18%i==0])   # [1,2,3,6]",
    "output": "[1, 2, 3, 6]"
  },
  {
    "title": "辗转相除法（欧几里得）",
    "body": "经典算法：用余数不断替换。\nwhile b != 0: a, b = b, a % b\n等到 b 变成 0 时，a 就是最大公约数。\n\n过程（12, 18）：\n12,18 → 18,12 → 12,6 → 6,0 → a=6 ✅",
    "code": "def gcd(a, b):\n    while b != 0:\n        a, b = b, a % b\n    return a\n\nprint(gcd(12, 18))   # 6\nprint(gcd(7, 13))    # 1",
    "output": "6\n1"
  },
  {
    "title": "或用 math.gcd",
    "body": "Python 内置了 math.gcd(a, b)，一行搞定。\n不过建议先理解辗转相除法的原理，再偷懒用内置函数。",
    "code": "import math\na, b = map(int, input().split())\nprint(math.gcd(a, b))",
    "output": "6"
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
