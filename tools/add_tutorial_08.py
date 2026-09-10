#!/usr/bin/env python3
"""给 08_tuples_sets.json 的 6 题（801-806）加详细教程。"""
import json

PATH = "assets/problems/python/08_tuples_sets.json"

tutorials = {
801: [
  {
    "title": "元组是什么",
    "body": "元组（tuple）和列表很像，都是能装多个元素的容器，用圆括号 ( ) 括起来。\n最大的区别：元组创建后里面的元素不能修改（不可变），列表可以改。\n\n能读取、能取长度，但不能增删改。",
    "code": "t = (10, 20, 30, 40, 50)\nprint(len(t))   # 长度\nprint(t[-1])    # 最后一个元素",
    "output": "5\n50"
  },
  {
    "title": "下标的用法和列表一样",
    "body": "元组也用下标访问，规则和字符串/列表一致：\n下标从 0 开始，t[0] 是第一个元素。\n负数下标从右数：t[-1] 是最后一个。\n所以这题直接用 t[-1]。",
    "code": "t = (10, 20, 30, 40, 50)\nprint(t[0])     # 10\nprint(t[-1])    # 50\nprint(t[1:3])   # 切片也能用:(20, 30)",
    "output": "10\n50\n(20, 30)"
  }
],
802: [
  {
    "title": "打包成元组",
    "body": "把若干值放进圆括号就得到一个元组。\na, b, c = map(...) 是「拆包」（把一个元组/序列拆给多个变量）。\n反过来，把多个变量装进一个元组 t = (a, b, c) 就是「打包」。\n\nprint(元组) 会按 (a, b, c) 的形式输出。",
    "code": "a, b, c = map(int, input().split())   # 拆包\nprint((a, b, c))                        # 打包成元组\n# 输入 1 2 3 -> 输出 (1, 2, 3)",
    "output": "(1, 2, 3)"
  },
  {
    "title": "交换两个变量",
    "body": "第二行要求输出交换 a、b 之后的结果：2 1 3。\n前面学过直接 a, b = b, a 就能交换，然后按 b, a, c 的顺序 print。",
    "code": "a, b, c = map(int, input().split())\na, b = b, a        # 交换 a 和 b\nprint(b, a, c)     # 现在 b 是原a,a是原b",
    "output": "2 1 3"
  }
],
803: [
  {
    "title": "集合 set 自动去重",
    "body": "集合（set）是一种容器，特点是：元素不重复。\n把列表转成集合 set(列表)，重复的元素会被自动去掉。\n再用 len() 数个数，就是「不同单词的数量」。",
    "code": "words = [\"apple\", \"banana\", \"apple\", \"orange\"]\nprint(set(words))     # 去重后的集合\nprint(len(set(words)))  # 3",
    "output": "{'orange', 'banana', 'apple'}\n3"
  },
  {
    "title": "注意集合是无序的",
    "body": "集合不保证顺序，所以 set(words) 打印出来顺序可能乱。\n但这题只数个数（len），不要求输出顺序，所以没问题。\n\n需要顺序时（如之前的去重保序题）就不能用 set，得手动遍历。",
    "code": "words = input().split()\nprint(len(set(words)))"
  }
],
804: [
  {
    "title": "集合三种运算",
    "body": "集合支持数学里的集合运算：\n交集 & ：两个集合共有的元素\n并集 | ：两个集合合起来的所有元素\n差集 - ：属于前者但不属于后者的元素\n\n直接写运算符就能算。",
    "code": "setA = {1, 2, 3, 4}\nsetB = {3, 4, 5, 6}\nprint(setA & setB)   # 交集 {3,4}\nprint(setA | setB)   # 并集 {1,2,3,4,5,6}\nprint(setA - setB)   # 差集 {1,2}",
    "output": "{3, 4}\n{1, 2, 3, 4, 5, 6}\n{1, 2}"
  },
  {
    "title": "用文字记住运算符",
    "body": "三个运算符对应三种集合操作，用英文记忆：\n& 像 and（都要有）→ 交集\n| 像 or（有就行）→ 并集\n- 减号 → 差集（减去重叠部分）\n\nsetA - setB 是「setA 里有但 setB 没有的」：1、2。",
    "code": "print({1,2,3,4} - {3,4,5,6})   # 1,2"
  }
],
805: [
  {
    "title": "in 判断元素在不在",
    "body": "in 运算符判断一个元素是否存在于某个容器（列表/元组/集合/字符串）里。\n结果是布尔值 True（在）或 False（不在）。\n\n`x in [2,3,5,7]` 检查 x 是否在列表里。",
    "code": "x = int(input())\nprint(x in [2, 3, 5, 7])\n\n# 5 -> True, 4 -> False",
    "output": "True"
  },
  {
    "title": "也可以配 not in",
    "body": "not in 正好相反，判断「不在」里面。\n之前列表去重（706）就是用 x not in seen 来判断「还没见过」。\n\n这题只需 in，直接 print 结果即可。",
    "code": "print(4 not in [2, 3, 5, 7])   # True(4不在)\nprint(2 in [2, 3, 5, 7])        # True",
    "output": "True\nTrue"
  }
],
806: [
  {
    "title": "list 和 tuple 互相转换",
    "body": "list(元组) 能把元组转成列表，tuple(列表) 能把列表转成元组。\n\n读入的整数列表先按列表输出，再用 tuple() 转元组输出。",
    "code": "nums = list(map(int, input().split()))\nprint(nums)          # [1, 2, 3]\nprint(tuple(nums))   # (1, 2, 3)",
    "output": "[1, 2, 3]\n(1, 2, 3)"
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
