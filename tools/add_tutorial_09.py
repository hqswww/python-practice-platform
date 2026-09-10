#!/usr/bin/env python3
"""给 09_dicts.json 的 6 题（901-906）加详细教程（字典，核心分类写详细）。"""
import json

PATH = "assets/problems/python/09_dicts.json"

tutorials = {
901: [
  {
    "title": "字典是什么",
    "body": "字典（dict）用键值对（key: value）存数据，用花括号 { } 表示。\n它像一本「通讯录」：用「键」去查「值」。\n\nd = {'name': 'Alice', 'age': 20}，两个键值对：\n键是 name，值 Alice；键是 age，值 20。",
    "code": "d = {'name': 'Alice', 'age': 20}\nprint(d['name'])   # 用键取对应的值\nprint(d['age'])    # 20",
    "output": "Alice\n20"
  },
  {
    "title": "用 d[键] 取值",
    "body": "访问字典的值用 字典名[键]。\n注意：如果这个键不存在，程序会报 KeyError 错误。\n本题保证输入的键都在字典里，所以直接 d[key] 就行，但要记住这个坑。",
    "code": "d = {'name': 'Alice', 'age': 20, 'city': 'Beijing'}\nkey = input()      # 输入 name\ntry:\n    print(d[key])\nexcept KeyError:\n    print(\"键不存在\")",
    "output": "Alice"
  }
],
902: [
  {
    "title": "给字典加新键",
    "body": "直接对不存在的键赋值，就能给字典添加新的键值对。\n比如 d['c'] = 3，给 d 加一个 'c': 3。",
    "code": "d = {'a': 1, 'b': 2}\nd['c'] = 3\nprint(d)   # 新加了 c",
    "output": "{'a': 1, 'b': 2, 'c': 3}"
  },
  {
    "title": "覆盖已有键的值",
    "body": "对已存在的键赋值，不是新增，而是「覆盖」旧值。\nd['a'] = 10 会把原来 a 对应的 1 改成 10。\n\n所以：赋值的键不存在→新增；存在→修改。同一个语法，两种行为。",
    "code": "d = {'a': 1, 'b': 2}\nd['a'] = 10\nd['c'] = 3\nprint(d)",
    "output": "{'a': 10, 'b': 2, 'c': 3}"
  },
  {
    "title": "本题完整写法",
    "body": "先赋 'c'（新增），再赋 'a'（覆盖），最后 print(d)。\n注意题目输入 x y 两个数，分别用于这两个键。",
    "code": "d = {'a': 1, 'b': 2}\nx, y = map(int, input().split())\nd['c'] = x     # 新增 c\nprint(d)",
    "output": "{'a': 1, 'b': 2, 'c': 3}"
  }
],
903: [
  {
    "title": "items() 遍历键值对",
    "body": "想要同时拿到键和值，用字典的 .items() 方法。\nfor k, v in d.items() 会依次取出每一对键值，k 是键、v 是值。",
    "code": "d = {'apple': 3, 'banana': 5}\nfor k, v in d.items():\n    print(k, v)",
    "output": "apple 3\nbanana 5"
  },
  {
    "title": "按 键:值 格式输出",
    "body": "题目要求输出 apple:3 这样的格式（英文冒号、无空格）。\n用 f-string 格式化：f\"{k}:{v}\"。\n\nPython 3.7+ 的字典会保持键的插入顺序，所以输出顺序和定义时一致。",
    "code": "d = {'apple': 3, 'banana': 5, 'cherry': 2}\nfor k, v in d.items():\n    print(f\"{k}:{v}\")",
    "output": "apple:3\nbanana:5\ncherry:2"
  }
],
904: [
  {
    "title": "用字典计数",
    "body": "统计每个单词出现次数，用字典把「单词 → 次数」存起来。\n关键技巧：count.get(w, 0) 表示「取当前次数，没有就当作 0」，然后 +1。\n这样第一次遇到的单词从 0 变成 1，之后的每次再加。",
    "code": "words = \"apple banana apple\".split()\ncount = {}\nfor w in words:\n    count[w] = count.get(w, 0) + 1\nprint(count)   # {'apple': 2, 'banana': 1}",
    "output": "{'apple': 2, 'banana': 1}"
  },
  {
    "title": "get 的默认值参数",
    "body": "count.get(w, 0) 的第二个参数 0 是「默认值」：如果键 w 不存在，就返回 0。\n这样第一次遇到某个单词时，能安全地从 0 开始计数，不会报 KeyError。",
    "code": "count = {}\nprint(count.get('banana', 0))   # 还没有,返回默认0\ncount['banana'] = 1\nprint(count.get('banana', 0))   # 现在有,返回1",
    "output": "0\n1"
  },
  {
    "title": "用集合去重保序",
    "body": "题目要求按第一次出现的顺序输出每个单词。\n复用之前的「去重保序」技巧：用一个 set 记录已输出的单词，遍历原词表，第一次见到才输出。\n\n遍历 words 时，第一次见到的 w 才打印，且次数从 count 字典里查。",
    "code": "words = input().split()\ncount = {}\nfor w in words:\n    count[w] = count.get(w, 0) + 1\nseen = set()\nfor w in words:\n    if w not in seen:\n        seen.add(w)\n        print(w, count[w])",
    "output": "apple 2\nbanana 1"
  }
],
905: [
  {
    "title": "合并字典",
    "body": "题目要把两个字典合并：d1 和 d2。重复的键 'b' 以 d2 的值为准（3）。\n\n做法：先复制 d1 得一个结果，再用 update(d2) 把 d2 并进去——同名键会被 d2 覆盖。",
    "code": "d1 = {'a': 1, 'b': 2}\nd2 = {'b': 3, 'c': 4}\nres = dict(d1)      # 复制 d1\nres.update(d2)      # 并入 d2,重复键 b 用 d2 的 3\nprint(res)",
    "output": "{'a': 1, 'b': 3, 'c': 4}"
  },
  {
    "title": "Python 3.9+ 的合并符 |",
    "body": "新版本 Python 还有一个更简洁的合并语法：d1 | d2。\n它返回一个新字典，右侧的 d2 覆盖左侧同名项。\n不过 update() 更通用（老版本也支持），两种都要会。",
    "code": "d1 = {'a': 1, 'b': 2}\nd2 = {'b': 3, 'c': 4}\nprint(d1 | d2)   # 新版本可用",
    "output": "{'a': 1, 'b': 3, 'c': 4}"
  }
],
906: [
  {
    "title": "多行输入用 sys.stdin",
    "body": "这题输入有多行（每一行是一个 键 值），数量不固定，读到最后结束。\n用 for line in sys.stdin 逐行读取，直到文件结束会自动停。\n记得 .strip() 去掉行尾换行符，空行跳过。",
    "code": "import sys\nfor line in sys.stdin:\n    line = line.strip()\n    if not line:\n        continue\n    k, v = line.split()\n    print(k, v)",
    "output": "alice 90\nbob 85"
  },
  {
    "title": "找最大的值（同值取最先）",
    "body": "逐个比较：用一个变量记录当前最大和它的键。\n关键点：只有「严格大于」才更新。\n这样当出现相同最大值时，保持第一次遇到的不变，正好满足「同值取最先出现」。",
    "code": "best_key = None\nbest_val = -1\nfor k, v in [['alice',90],['bob',85],['carol',90]]:\n    if v > best_val:     # 严格大于才更新\n        best_val = v\n        best_key = k\nprint(best_key)   # alice(不是carol)",
    "output": "alice"
  },
  {
    "title": "本题完整写法",
    "body": "把多行读取和最大值比较合起来。\n注意 v 是字符串，要先 int(v) 转整数再比较。",
    "code": "import sys\nbest_key = None\nbest_val = -1\nfor line in sys.stdin:\n    line = line.strip()\n    if not line:\n        continue\n    k, v = line.split()\n    v = int(v)\n    if v > best_val:\n        best_val = v\n        best_key = k\nprint(best_key)",
    "output": "alice"
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
