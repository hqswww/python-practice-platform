#!/usr/bin/env python3
"""给 07_lists.json 的 6 题（701-706）加详细教程（列表，核心分类写详细）。"""
import json

PATH = "assets/problems/python/07_lists.json"

tutorials = {
701: [
  {
    "title": "把一行数字转成列表",
    "body": "要处理「一行、空格分隔的若干整数」，标准套路是：\n① input() 读整行\n② .split() 按空格拆成一个个字符串\n③ map(int, ...) 把每个字符串转成整数\n④ list(...) 包成列表\n\n记住这行「万能公式」：list(map(int, input().split()))",
    "code": "s = input()\nprint(s)                 # 原始字符串\nprint(s.split())         # 拆成字符串列表\nnums = list(map(int, s.split()))  # 转成整数列表\nprint(nums)",
    "output": "1 2 3 4 5\n['1', '2', '3', '4', '5']\n[1, 2, 3, 4, 5]"
  },
  {
    "title": "sum() 直接求和",
    "body": "对整型列表求和，Python 内置了 sum() 函数，传进列表就返回总和。\n负数也会被正确相加，比如 -1-2-3 = -6。",
    "code": "nums = list(map(int, input().split()))\nprint(sum(nums))",
    "output": "15"
  }
],
702: [
  {
    "title": "初始列表",
    "body": "这题一开始就有一个固定列表 [1, 2, 3]，要定义在代码里。\n如果列表里的元素都是同类型（这里是整数），就很好处理。",
    "code": "lst = [1, 2, 3]\nprint(lst)   # [1, 2, 3]",
    "output": "[1, 2, 3]"
  },
  {
    "title": "append() 末尾添加",
    "body": "list.append(x) 把元素 x 添加到列表末尾。\n[1,2,3].append(4) 后变成 [1,2,3,4]。\n它是在原列表上直接修改（不用重新赋值回去）。",
    "code": "lst = [1, 2, 3]\nlst.append(4)\nprint(lst)   # [1, 2, 3, 4]",
    "output": "[1, 2, 3, 4]"
  },
  {
    "title": "pop(0) 删除第一个",
    "body": "list.pop(下标) 删除并返回指定下标的元素。\npop(0) 删除下标 0 的元素，也就是第一个。\n\n删除后列表会前移：[1,2,3,4] 删第一个 → [2,3,4]。",
    "code": "lst = [1, 2, 3, 4]\nremoved = lst.pop(0)   # 删除并取出第一个\nprint(removed)   # 1\nprint(lst)       # [2, 3, 4]",
    "output": "1\n[2, 3, 4]"
  }
],
703: [
  {
    "title": "列表也能 [::-1]",
    "body": "和字符串一样，列表也可以用切片 [::-1] 反转，得到一个新列表。\n[1,2,3,4][::-1] → [4,3,2,1]。",
    "code": "nums = [1, 2, 3, 4]\nrev = nums[::-1]\nprint(rev)   # [4, 3, 2, 1]",
    "output": "[4, 3, 2, 1]"
  },
  {
    "title": "按空格拼接输出",
    "body": "题目要求输出 4 3 2 1 这样「空格分隔」的形式，不是 [4, 3, 2, 1]。\n要用 ' '.join(列表) —— 但 join 只接受字符串列表。\n所以先把每个数 map(str) 转成字符串，再 join。",
    "code": "rev = [4, 3, 2, 1]\nprint(' '.join(map(str, rev)))",
    "output": "4 3 2 1"
  }
],
704: [
  {
    "title": "遍历加判断",
    "body": "统计大于 0 的个数：用一个 count 计数器（初始 0），遍历每个数，大于 0 就加一。\n注意 0 本身不算正数，所以判断条件是 x > 0。",
    "code": "nums = list(map(int, input().split()))\ncount = 0\nfor x in nums:\n    if x > 0:\n        count += 1\nprint(count)",
    "output": "3"
  },
  {
    "title": "更 Pythonic：列表推导 + sum",
    "body": "进阶写法：用列表推导式挑出大于 0 的元素，再取个数。\n[x for x in nums if x > 0] 生成「所有正数组成的新列表」，len() 就是个数。\n等价于 sum(x > 0 for x in nums)（True 会按 1 计）。",
    "code": "nums = [1, -2, 3, -4, 5]\nprint(len([x for x in nums if x > 0]))   # 3\n# 或:\nprint(sum(x > 0 for x in nums))          # 3",
    "output": "3\n3"
  }
],
705: [
  {
    "title": "max() 找最大值",
    "body": "max(列表) 返回列表里的最大值。\n如果列表 [3,7,1,7,2]，最大值是 7。",
    "code": "nums = [3, 7, 1, 7, 2]\nprint(max(nums))   # 7",
    "output": "7"
  },
  {
    "title": "index() 找位置",
    "body": "list.index(值) 返回该值第一次出现的下标（从 0 开始）。\n注意是「第一次」出现的位置。比如 7 在 [3,7,1,7,2] 里第一次在下标 1。\n\n用 m = max(nums) 拿到最大值，再用 nums.index(m) 找它的位置。",
    "code": "nums = [3, 7, 1, 7, 2]\nm = max(nums)\nprint(m, nums.index(m))   # 7 1\n\n# 验证:下标1是第一个7\nprint(nums[1])   # 7",
    "output": "7 1\n7"
  }
],
706: [
  {
    "title": "去重但保持顺序",
    "body": "去重通常想到 set()，但 set 会打乱顺序。题目要求「按第一次出现顺序」，所以不能用 set。\n\n正确做法：建一个空列表 seen，遍历原列表，只有「没出现过」的元素才加进去。\n用 x not in seen 判断是否已存在。",
    "code": "seen = []\nfor x in [1, 2, 1, 3, 2, 4]:\n    if x not in seen:\n        seen.append(x)\nprint(seen)   # [1, 2, 3, 4]",
    "output": "[1, 2, 3, 4]"
  },
  {
    "title": "为什么 not in 就能去重",
    "body": "第一次遇到 1，seen 里没有，加入 → [1]。\n再遇到 1，seen 里已有，跳过。\n遇到 2 加入 → [1,2]，再遇 2 跳过…… \n\n每个元素第一次出现时被加入，之后重复的都被「拦住」，所以既去重又保持了第一次出现的相对顺序。",
    "code": "nums = list(map(int, input().split()))\nseen = []\nfor x in nums:\n    if x not in seen:\n        seen.append(x)\nprint(' '.join(map(str, seen)))",
    "output": "1 2 3 4"
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
