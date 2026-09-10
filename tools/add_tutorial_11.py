#!/usr/bin/env python3
"""给 11_advanced.json 的 6 题（1101-1106）加详细教程（进阶：推导式/lambda/异常/矩阵转置/多行计数）。"""
import json

PATH = "assets/problems/python/11_advanced.json"

tutorials = {
1101: [
  {
    "title": "列表推导式是什么",
    "body": "列表推导式（list comprehension）是一种「一行生成新列表」的简洁写法。\n基本形式：\n[表达式 for 变量 in 列表]\n\n它等价于一个 for 循环 + append。把原本好几行的逻辑压成一行。",
    "code": "nums = [1, 2, 3, 4]\nsq = [x * x for x in nums]   # 每个 x 算平方\nprint(sq)\n\n# 等价写法(用普通循环)\nsq2 = []\nfor x in nums:\n    sq2.append(x * x)\nprint(sq2)",
    "output": "[1, 4, 9, 16]\n[1, 4, 9, 16]"
  },
  {
    "title": "读入列表再推导",
    "body": "先把输入转成整数列表（万能公式），再套推导式求平方。\n注意负数平方也是正数：-1 的平方是 1。",
    "code": "nums = list(map(int, input().split()))\nsq = [x * x for x in nums]\nprint(sq)",
    "output": "[1, 4, 9, 16]"
  }
],
1102: [
  {
    "title": "带条件的推导式",
    "body": "推导式还能加一个 if 条件：\n[表达式 for 变量 in 列表 if 条件]\n只有满足条件的元素才会被处理，相当于在循环里跳过不符合的。",
    "code": "nums = [1, 2, 3, 4, 5, 6]\n# 只保留 x 能被2整除的(x%2==0)\neven = [x for x in nums if x % 2 == 0]\nprint(even)   # [2, 4, 6]",
    "output": "[2, 4, 6]"
  },
  {
    "title": "对比普通写法",
    "body": "带 if 的推导式等价于：\nresult = []\nfor x in nums:\n    if x % 2 == 0:\n        result.append(x)\n\n推导式把「遍历 + 判断 + 收集」一步到位，更简洁。",
    "code": "nums = list(map(int, input().split()))\neven = [x for x in nums if x % 2 == 0]\nprint(even)",
    "output": "[2, 4, 6]"
  }
],
1103: [
  {
    "title": "读多行名单",
    "body": "输入若干行 '名字 分数'。用 sys.stdin 逐行读，把每一行解析成 (名字, 分数) 二元组存进列表。\n分数要 int() 转成整数，方便后面排序。",
    "code": "import sys\npairs = []\nfor line in sys.stdin:\n    line = line.strip()\n    if not line:\n        continue\n    name, score = line.split()\n    pairs.append((name, int(score)))\nprint(pairs)",
    "output": "[('bob', 80), ('alice', 95), ('carol', 80)]"
  },
  {
    "title": "lambda 匿名函数",
    "body": "sorted/list.sort 可以指定一个 key 函数，决定「按什么排」。\nlambda 就是一行的匿名函数：lambda 参数: 表达式。\n\nkey=lambda p: (-p[1], p[0]) 会对每个元素 p（一个二元组）返回一个排序键 (-分数, 名字)。",
    "code": "pairs = [('bob', 80), ('alice', 95), ('carol', 80)]\n# 按 (-分数, 名字) 排序:-分数(降序);同分按名字(升序)\nfor name, _ in pairs:\n    print(name)",
    "output": "alice\nbob\ncarol"
  },
  {
    "title": "巧妙之处：用负数实现降序",
    "body": "Python 的 sorted 默认是升序。想让分数高的排前面（降序），\n一个技巧是取负：key 返回 -分数，分数越大负值越小，就越靠前。\n\n分数相同时，key 的第二个元素是名字（字典序），x<y 排前面，正好满足「同分按名字」。\n所以 key=lambda p: (-p[1], p[0]) 一次搞定两个排序规则。",
    "code": "pairs.sort(key=lambda p: (-p[1], p[0]))\nfor name, _ in pairs:\n    print(name)",
    "output": "alice\nbob\ncarol"
  }
],
1104: [
  {
    "title": "try / except 处理错误",
    "body": "有时候程序可能出错，比如把 'abc' 转整数 int('abc') 会报 ValueError。\n用 try/except 可以「兜住」错误：\ntry 里的代码出错时，不崩溃，跳到 except 分支处理。\n\n结构：\ntry:\n    可能出错的代码\nexcept 错误类型:\n    出错时执行的代码",
    "code": "try:\n    n = int('abc')      # 这会出错!\nexcept ValueError:\n    print('转整数失败')\nprint('程序没有崩溃,继续执行')",
    "output": "转整数失败\n程序没有崩溃,继续执行"
  },
  {
    "title": "本题完整写法",
    "body": "尝试把输入转成整数：成功输出 OK: 数值；失败（ValueError）输出 Error。\n注意：'3.14' 也不是合法的整数格式（int() 只认整数串），所以也会走 except 输出 Error。",
    "code": "try:\n    n = int(input())\n    print(f\"OK: {n}\")\nexcept ValueError:\n    print(\"Error\")",
    "output": "OK: 123"
  }
],
1105: [
  {
    "title": "二维列表（矩阵）",
    "body": "二维列表就是「列表里套列表」，用来表示矩阵/表格。\n读 3 行，每行是 3 个整数组成的一个小列表，3 个小列表组成一个大列表。\n\ngrid[行][列] 访问元素：grid[0][1] 是第一行第二列。",
    "code": "grid = []\nfor _ in range(3):\n    grid.append(list(map(int, input().split())))\n# 输入 1 2 3 / 4 5 6 / 7 8 9\nprint(grid[0])    # 第一行 [1, 2, 3]\nprint(grid[1][2]) # 第二行第三个 6",
    "output": "[1, 2, 3]\n6"
  },
  {
    "title": "转置：行变列",
    "body": "转置就是把矩阵的行和列互换，比如原第 1 行 [1,2,3] 变成新矩阵的第 1 列（1,4,7）。\n\nPython 有个极简写法：zip(*grid)。\n*grid 把 grid 里的 3 行「拆开」传给 zip，zip 把每个位置（第 i 列）组合成新元组，正好是转置的列。",
    "code": "grid = [[1,2,3],[4,5,6],[7,8,9]]\nfor row in zip(*grid):\n    print(row)\n# (1,4,7) (2,5,8) (3,6,9) 即转置",
    "output": "(1, 4, 7)\n(2, 5, 8)\n(3, 6, 9)"
  },
  {
    "title": "用 join 输出",
    "body": "zipped 出来的是元组，要按 '1 4 7'（空格分隔）输出。\n用 ' '.join(map(str, row)) 把每行转成字符串再接空格，再 print。",
    "code": "grid = []\nfor _ in range(3):\n    grid.append(list(map(int, input().split())))\nfor row in zip(*grid):\n    print(' '.join(map(str, row)))",
    "output": "1 4 7\n2 5 8\n3 6 9"
  }
],
1106: [
  {
    "title": "读未知行数的输入",
    "body": "输入行数不确定（可能 3 行也可能 2 行），直到输入结束。\n用 for line in sys.stdin 逐行读，输入结束自动停。\n每行可能不止一个数，所以每行 split 后还有多个整数。",
    "code": "import sys\nfor line in sys.stdin:\n    line = line.strip()\n    if not line:\n        continue\n    nums = list(map(int, line.split()))\n    print(nums)   # 看每行有多少个数",
    "output": "[1, 2]\n[3]\n[4, 5, 6]"
  },
  {
    "title": "累加个数和总和",
    "body": "准备两个累加器：个数和总和。\n每行：个数 += len(nums)（这行几个数），总和 += sum(nums)。\n最后把总数和总和一起输出。",
    "code": "import sys\ntotal_count = 0\ntotal_sum = 0\nfor line in sys.stdin:\n    line = line.strip()\n    if not line:\n        continue\n    nums = list(map(int, line.split()))\n    total_count += len(nums)\n    total_sum += sum(nums)\nprint(total_count, total_sum)",
    "output": "6 21"
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
