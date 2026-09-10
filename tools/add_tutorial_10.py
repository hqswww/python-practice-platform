#!/usr/bin/env python3
"""给 10_functions.json 的 6 题（1001-1006）加详细教程（函数，核心分类写详细）。"""
import json

PATH = "assets/problems/python/10_functions.json"

tutorials = {
1001: [
  {
    "title": "函数是什么",
    "body": "函数是一段「有名字、能反复调用」的代码。把要重复做的事写进函数，需要时叫它一声就行。\n\n定义用 def，格式是：\ndef 函数名(参数):\n    【缩进】要做的代码\n\n参数就是传给函数的「输入」，函数根据它干活。",
    "code": "def greet(name):          # 定义函数,参数叫 name\n    print(f\"Hello, {name}!\")   # 函数体(缩进)\n\ngreet(\"Alice\")   # 调用函数\nprint(\"还是正常往下走\")",
    "output": "Hello, Alice!\n还是正常往下走"
  },
  {
    "title": "函数体要缩进",
    "body": "函数内部的所有代码都要缩进（4 个空格），这是 Python 表示「这些代码属于这个函数」的方式。\n缩进结束后（回到顶格），就说明函数定义完了。\n\n定义一个函数本身不会执行它，必须「调用」才会运行。",
    "code": "def greet(name):\n    print(f\"Hello, {name}!\")   # 缩进=函数体\n\n# 下面是顶格,不属于函数了\ngreet(input())   # 调用时才执行",
    "output": "Hello, Alice!"
  }
],
1002: [
  {
    "title": "return 和 print 的区别",
    "body": "函数里最常见的一个迷惑点：print 和 return 完全不同。\nprint 是把东西「显示到屏幕」；return 是把结果「交还给调用处」。\n\n函数运算完交还结果用 return。调用函数的地方（如 print(add(a,b))）拿到这个结果继续处理。",
    "code": "def add(a, b):\n    return a + b      # 把结果交还\n\nresult = add(3, 5)    # result 拿到 8\nprint(result)         # 再打印",
    "output": "8"
  },
  {
    "title": "return 会立刻结束函数",
    "body": "return 一旦执行，函数立刻结束，后面的代码不会跑了。\n这常用于「先判断特殊情况，满足就直接返回」。\n\n本题 add 很简单，直接 return a+b 即可。",
    "code": "def add(a, b):\n    return a + b\n    print(\"这句话不会执行\")   # return 之后到不了\n\na, b = map(int, input().split())\nprint(add(a, b))",
    "output": "8"
  }
],
1003: [
  {
    "title": "返回布尔值",
    "body": "函数不一定要返回数字/字符串，也可以返回布尔值 True/False。\n判断 n 是否为偶数：n % 2 == 0（余数为 0 就是偶数）。\n这个比较运算的结果本身就是 True 或 False，直接 return 即可。",
    "code": "def is_even(n):\n    return n % 2 == 0\n\nprint(is_even(4))   # True\nprint(is_even(7))   # False",
    "output": "True\nFalse"
  },
  {
    "title": "return 一个表达式",
    "body": "return 后面可以直接跟一个表达式，Python 会先算好再返回。\nreturn n % 2 == 0 等价于：先算 n%2 得余数，再和 0 比得布尔值，最后返回。",
    "code": "n = int(input())\nprint(is_even(n))\nprint(type(is_even(4)))   # 返回的是 bool",
    "output": "True\n<class 'bool'>"
  }
],
1004: [
  {
    "title": "默认参数",
    "body": "函数定义时，可以给参数一个「默认值」：def repeat(text, times=2)。\n这样调用时：\n· 传 times → 用你传的\n· 不传 times → 自动用默认值 2\n\n默认参数让函数更灵活，有些参数不填也能用。",
    "code": "def repeat(text, times=2):\n    return text * times\n\nprint(repeat(\"ab\"))        # 用默认 times=2\nprint(repeat(\"ab\", 3))     # 覆盖成 3",
    "output": "abab\nababab"
  },
  {
    "title": "字符串乘整数=重复",
    "body": "text * times 中，字符串乘以整数会把字符串重复 times 次！\nab * 2 → abab。这是 Python 很实用的特性。\n\n本题调用 repeat(s) 不传第二个参数，就用默认的 2，让字符串重复 2 次。",
    "code": "print(\"ab\" * 2)     # abab\nprint(\"hi\" * 3)     # hihihi\n\ns = input()\nprint(repeat(s))     # 重复2次",
    "output": "abab\nhihihi"
  }
],
1005: [
  {
    "title": "一次返回多个值",
    "body": "Python 函数可以用 return 返回多个值（用逗号分隔），它们会被打包成一个元组。\n调用处可以用多个变量同时接收：a, b = min_max(nums)，a 拿第一个、b 拿第二个。\n\n这就是「拆包」——之前学过的元组拆包在这里用上了。",
    "code": "def min_max(nums):\n    return min(nums), max(nums)   # 返回(最小值,最大值)\n\nnums = [3, 1, 4, 1, 5]\nmn, mx = min_max(nums)   # 拆包接收\nprint(mn, mx)   # 1 5",
    "output": "1 5"
  },
  {
    "title": "min 和 max",
    "body": "Python 内置 min() 取最小值、max() 取最大值，直接传列表即可。\n这题把它们包进函数里返回，是「多返回值」的练习。",
    "code": "nums = list(map(int, input().split()))\na, b = min_max(nums)\nprint(a, b)",
    "output": "1 5"
  }
],
1006: [
  {
    "title": "递归是什么",
    "body": "递归就是「函数调用自己」。\n阶乘有天然的递归关系：n! = n × (n-1)!。\n要算 5!，可以先算 4!（5! = 5 × 4!），算 4! 又依赖 3!…… 一路拆下去。\n\n递归写起来简洁，但必须有「出口」防止无限递归。",
    "code": "def factorial(n):\n    return n * factorial(n - 1)   # ❌想想这会有问题吗?\n\n# 会无限调用,永远停不下来!因为没有出口",
    "output": ""
  },
  {
    "title": "基线条件（出口）",
    "body": "递归必须有「基线条件」（也叫边界/出口）：满足时不再调用自己，直接返回。\n阶乘的基线条是 0! = 1。\n\nfactorial(5) → 5 × factorial(4)\n→ 5 × 4 × factorial(3)\n→ 5 × 4 × 3 × factorial(2)\n→ 5 × 4 × 3 × 2 × factorial(1)\n→ 5 × 4 × 3 × 2 × 1 × factorial(0)\n→ factorial(0) 命中基线，返回 1，开始回退相乘。",
    "code": "def factorial(n):\n    if n == 0:      # ⭐基线条件\n        return 1\n    return n * factorial(n - 1)   # 递归\n\nprint(factorial(5))   # 120",
    "output": "120"
  },
  {
    "title": "追踪小例子",
    "body": "看一个小的：factorial(3)。\n第一层：3 ≠ 0，返回 3 × factorial(2)\n第二层：2 ≠ 0，返回 2 × factorial(1)\n第三层：1 ≠ 0，返回 1 × factorial(0)\n第四层：0 == 0，返回 1（到底了）\n\n然后一层层回退：1×1=1 → 2×1=2 → 3×2=6。所以 factorial(3)=6。\nn=0 时直接返回 1（0!=1），也是边界。",
    "code": "def factorial(n):\n    if n == 0:\n        return 1\n    return n * factorial(n - 1)\n\nn = int(input())\nprint(factorial(n))",
    "output": "120"
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
