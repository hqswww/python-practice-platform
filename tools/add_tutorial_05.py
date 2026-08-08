#!/usr/bin/env python3
"""给 05_loops.json 的 6 题（501-506）加详细教程（循环，核心分类写详细）。"""
import json

PATH = "assets/problems/05_loops.json"

tutorials = {
501: [
  {
    "title": "for 循环是什么",
    "body": "循环就是「重复做某事」。for 循环会从一串东西里一个一个取出元素，对每个元素执行一遍缩进的代码。\n\n要做 1 到 n 的事情，需要先构造「1 到 n」这一串数字，这就要用到 range()。",
    "code": "# 先看看 range 能生成什么\nprint(list(range(1, 5)))    # [1, 2, 3, 4]\nprint(list(range(5)))       # [0, 1, 2, 3, 4]",
    "output": "[1, 2, 3, 4]\n[0, 1, 2, 3, 4]"
  },
  {
    "title": "range 左闭右开",
    "body": "range(a, b) 生成从 a 到 b-1 的数（不含 b），这叫「左闭右开」。\n所以想生成 1 到 n，要写 range(1, n+1)，而不是 range(1, n)。\n\n这是新手最容易踩的坑，记住：end 的值不会被包含。",
    "code": "range(1, 5)  # 1,2,3,4  （没有5!）\nrange(1, 6)  # 1,2,3,4,5\n\n# 想从1到n,写 range(1, n+1)\nfor i in range(1, n + 1):\n    print(i)"
  },
  {
    "title": "本题完整写法",
    "body": "读入 n，用 range(1, n+1) 生成 1 到 n，for 循环逐个输出。\n每个 print 默认换行，正好一行一个数。",
    "code": "n = int(input())\nfor i in range(1, n + 1):\n    print(i)",
    "output": "1\n2\n3\n4\n5"
  }
],
502: [
  {
    "title": "累加的三要素",
    "body": "累加求和是循环里最经典的套路，记住三件事：\n① 先准备一个「存结果的盒子」total，初始为 0。\n② 循环里不断把新数加进去。\n③ 循环结束后输出 total。\n\n初始为 0 很重要——如果初始是别的值，总和就偏了。",
    "code": "total = 0            # ①存结果的变量,从0开始\nfor i in range(1, 5):  # 1,2,3,4\n    total += i         # ②累加:total = total + i\nprint(total)          # ③输出\n# 1+2+3+4 = 10",
    "output": "10"
  },
  {
    "title": "+= 的简写",
    "body": "total += i 是 total = total + i 的简写「累加」。\n类似地还有 -=（累减）、*=（累乘）、/=（累除）。\n\n注意要让 total 参与自己，必须在前面初始化好（这里是 0）。",
    "code": "total = 0\ntotal = total + i   # 完整写法\n\ntotal = 0\ntotal += i          # 简写,等价",
    "output": ""
  },
  {
    "title": "本题完整写法",
    "body": "读入 n，从 1 累加到 n。n=100 时结果是 5050（当年高斯心算出的那个数~）。",
    "code": "n = int(input())\ntotal = 0\nfor i in range(1, n + 1):\n    total += i\nprint(total)",
    "output": "5050"
  }
],
503: [
  {
    "title": "循环里套判断",
    "body": "「输出偶数」可以这样想：把 1 到 n 都过一遍，是偶数才输出。\n所以循环里用一个 if 判断：if i % 2 == 0，是的话才 print。\n\n这是「遍历 + 筛选」的模式：循环里带条件，只对满足条件的元素操作。",
    "code": "n = int(input())\nfor i in range(1, n + 1):\n    if i % 2 == 0:\n        print(i)",
    "output": "2\n4\n6\n8\n10"
  },
  {
    "title": "更聪明：range 第三步",
    "body": "range 还能指定步长：range(起点, 终点, 步长)。\nrange(2, n+1, 2) 直接从 2 开始、每次加 2，天然就是所有偶数！\n\n这样就不用 if 判断了，一步到位。",
    "code": "n = int(input())\nfor i in range(2, n + 1, 2):   # 从2开始,每次+2\n    print(i)",
    "output": "2\n4\n6\n8\n10"
  }
],
504: [
  {
    "title": "嵌套循环",
    "body": "乘法表是个「二维」结构：有行、每行有多个式子。\n一个 for 循环管一维，所以需要两个 for 嵌套：\n外层循环控制「第几行」，内层循环控制「这一行里的每个式子」。\n\n外层每走一步，内层会把一整轮都走完。循环套循环就叫嵌套循环。",
    "code": "for i in range(1, 4):       # 外层:第i行\n    for j in range(1, i+1):  # 内层:这一行的第j个式子(1..i)\n        print(j, 'x', i, '=', j*i)   # 先不管排版,只打印",
    "output": "1 x 1 = 1\n1 x 2 = 2\n2 x 2 = 4\n1 x 3 = 3\n2 x 3 = 6\n3 x 3 = 9"
  },
  {
    "title": "内层范围为什么是 1..i",
    "body": "乘法表第 i 行，式子左边从 1 乘到 i（对角线 j*i）。\n所以内层范围是 range(1, i+1)，上限跟着外层 i 走。\n\n比如第 3 行：1x3、2x3、3x3，内层 j 从 1 到 3。",
    "code": "for i in range(1, 4):\n    for j in range(1, i + 1):\n        print(f\"{j}x{i}={j*i}\", end=\" \")  # end=' ' 不换行,用空格分隔\n    print()   # 一行结束,换行",
    "output": "1x1=1 \n1x2=2 2x2=4 \n1x3=3 2x3=6 3x3=9 "
  },
  {
    "title": "控制换行：end 参数",
    "body": "print() 默认末尾换行。想在一行里输出多个式子，可用 end=\" \" 让 print 末尾变成空格而不是换行。\n\n一行里的式子都打印完，再用一个空的 print() 换行，开始下一行。",
    "code": "print(\"a\", end=\" \")\nprint(\"b\", end=\" \")\nprint()          # 换行\nprint(\"c\")",
    "output": "a b c"
  },
  {
    "title": "本题完整写法",
    "body": "用列表收集每行的式子，最后用 \" \".join(row) 用空格拼成一行输出。\n这样能精确控制格式（式子和式子之间恰一个空格）。",
    "code": "for i in range(1, 10):\n    row = []\n    for j in range(1, i + 1):\n        row.append(f\"{j}x{i}={j*i}\")\n    print(\" \".join(row))",
    "output": "1x1=1\n1x2=2 2x2=4\n1x3=3 2x3=6 3x3=9"
  }
],
505: [
  {
    "title": "读入一组数",
    "body": "题目输入分两行：第一行 n（几个数），第二行是 n 个数。\n第一行用 int(input())，第二行用 input().split() 拆开再转 int。\n\n列表推导式 list(map(int, input().split())) 会把一行数字一次性转成整数列表。",
    "code": "n = int(input())                     # 第一行:个数\nnums = list(map(int, input().split()))  # 第二行:数字列表\nprint(nums)",
    "output": "[3, -2, 5, 0, -8, 10]"
  },
  {
    "title": "遍历+计数",
    "body": "遍历整个列表，遇到大于 0 的数就给计数器加 1。\n计数器初始为 0，这又是一处「先初始化」的套路。",
    "code": "count = 0\nfor x in nums:\n    if x > 0:\n        count += 1\nprint(count)",
    "output": "3"
  },
  {
    "title": "本题完整写法",
    "body": "把两部分合起来，就是完整的解法。",
    "code": "n = int(input())\nnums = list(map(int, input().split()))\ncount = 0\nfor x in nums:\n    if x > 0:\n        count += 1\nprint(count)",
    "output": "3"
  }
],
506: [
  {
    "title": "累乘：和累加几乎一样",
    "body": "阶乘是一路乘过去：1 × 2 × … × n。\n和累加（502）几乎一模一样，只是把加法换成乘法，把初始 0 换成初始 1。\n\n因为乘以 0 会变成 0，所以累乘的「盒子」要初始为 1。",
    "code": "result = 1              # 累乘初始为1(不是0!)\nfor i in range(1, 6):    # 1,2,3,4,5\n    result *= i          # result = result * i\nprint(result)            # 1*2*3*4*5 = 120",
    "output": "120"
  },
  {
    "title": "边界情况：0! = 1",
    "body": "数学上规定 0! = 1。\n这道题的妙处：如果 n = 0，range(1, 1) 是空的，循环一次都不执行，result 保持初始的 1。\n\n正好符合 0! = 1，所以「初始为 1」顺便就处理了这个边界。",
    "code": "n = 0\nresult = 1\nfor i in range(1, n + 1):   # range(1,1) 空的\n    result *= i              # 不执行\nprint(result)  # 1",
    "output": "1"
  },
  {
    "title": "本题完整写法",
    "body": "读入 n，累乘即可。n ≤ 10，结果不会太大。",
    "code": "n = int(input())\nresult = 1\nfor i in range(1, n + 1):\n    result *= i\nprint(result)",
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
