#!/usr/bin/env python3
"""给 06_strings.json 的 6 题（601-606）加详细教程（字符串，核心分类写详细）。"""
import json

PATH = "assets/problems/06_strings.json"

tutorials = {
601: [
  {
    "title": "len() 数长度",
    "body": "len() 函数返回字符串的长度，也就是它包含多少个字符。\n注意：空格也是一个字符，`abc def` 里有 7 个字符（中间的空格算 1 个）。\n\n汉字、字母、数字、空格都算一个字符。",
    "code": "s = input()\nprint(len(s))",
    "output": "5"
  },
  {
    "title": "输入本身是字符串",
    "body": "input() 读进来的本来就是字符串，所以不需要转换，直接 len(s) 就行。\n这题很简单，但要记住 len() 这个基础函数，后面经常用。",
    "code": "s = \"hello\"\nprint(len(s))   # 5",
    "output": "5"
  }
],
602: [
  {
    "title": "两行输入要读两次",
    "body": "这题输入分两行：第一行 a，第二行 b。\n每调用一次 input() 读一行，所以要用两次 input() 分别读 a 和 b。",
    "code": "s1 = input()   # 读第一行 Hello\ns2 = input()   # 读第二行 World\nprint(s1, s2)  # 空格分隔\nprint(s1 + s2) # 直接拼接,无空格",
    "output": "Hello World\nHelloWorld"
  },
  {
    "title": "用 + 拼接",
    "body": "字符串可以用 + 把两个拼成一个新字符串（a 在前）。\n注意：+ 拼接是「原样接上」，不会自动加空格或换行。所以 Hello + World = HelloWorld。",
    "code": "print(\"Hello\" + \"World\")   # HelloWorld\nprint(\"Hello\" + \" \" + \"World\")  # 想有空格得自己加",
    "output": "HelloWorld\nHello World"
  }
],
603: [
  {
    "title": "字符串也能用下标访问",
    "body": "字符串可以看成「一串字符」，每个字符有下标（索引），从 0 开始。\ns[0] 是第一个字符，s[-1] 是最后一个字符（负数从右边数）。",
    "code": "s = \"abcde\"\nprint(s[0])    # a\nprint(s[-1])   # e\nprint(s[1])    # b",
    "output": "a\ne\nb"
  },
  {
    "title": "切片反转：s[::-1]",
    "body": "切片是 s[起点:终点:步长]。步长如果是 -1，就表示「从后往前」取值。\n所以 s[::-1] 会把字符串倒过来，这是 Python 反转字符串最经典的写法。\n\n一个很妙的特性：反转后相同的叫回文，比如 madam 反转还是 madam。",
    "code": "s = \"abcde\"\nprint(s[::-1])   # edcba\n\nm = \"madam\"\nprint(m[::-1])   # madam(回文,反转不变)",
    "output": "edcba\nmadam"
  }
],
604: [
  {
    "title": "upper() 和 lower()",
    "body": "字符串方法可以转换大小写：\ns.upper() 把所有字母转成大写。\ns.lower() 把所有字母转成小写。\n非字母字符（空格、数字、符号）保持不变。\n\n注意这些方法不会改动原字符串，而是返回一个新字符串。",
    "code": "s = \"Hello World\"\nprint(s.upper())   # HELLO WORLD\nprint(s.lower())   # hello world",
    "output": "HELLO WORLD\nhello world"
  }
],
605: [
  {
    "title": "count() 数出现次数",
    "body": "字符串方法 s.count(子串) 返回子串在 s 里出现的次数。\nbanana 里 a 出现 3 次，所以 count('a') 返回 3。",
    "code": "s = \"banana\"\nprint(s.count(\"a\"))   # 3",
    "output": "3"
  },
  {
    "title": "忽略大小写：先统一再数",
    "body": "题目要求 A 和 a 都算。最简单的办法：先转成小写，再数 'a'。\n这样大写 A 也变成了小写 a，就一起被数到了。\n\nApple 转小写是 apple，数出 1 个 a。",
    "code": "s = input().lower()      # 读入并直接转小写\nprint(s.count('a'))",
    "output": "3"
  }
],
606: [
  {
    "title": "切片 s[起点:终点]",
    "body": "切片可以从字符串里截取一段：s[起点:终点]。\n注意终点是不包含的（左闭右开，和 range 一样）。\n\ns[0:3] 取下标 0、1、2 的三个字符。",
    "code": "s = \"abcdefghi\"\nprint(s[0:3])    # abc,下标0,1,2",
    "output": "abc"
  },
  {
    "title": "第 3 到第 6 个字符",
    "body": "下标从 0 开始，所以第 3 个字符的下标是 2。\n题目要第 3 到第 6 个字符（共 4 个）：下标 2 到 5。\n终点不包含，所以写成 s[2:6]。\n\nabcdefghi 里 cdef 正是第 3~6 个字符。",
    "code": "s = \"abcdefghi\"\nprint(s[2:6])    # cdef,下标2,3,4,5",
    "output": "cdef"
  },
  {
    "title": "负数下标取末尾",
    "body": "负下标从右往左数：s[-1] 是最后一个字符，s[-2] 是倒数第二个。\ns[-3:] 表示从倒数第 3 个开始到结尾，也就是最后 3 个字符。\n\n终点留空 s[-3:] 表示「到最后」。",
    "code": "s = \"abcdefghi\"\nprint(s[-3:])    # ghi,最后3个\nprint(s[-1])     # i,最后一个字符",
    "output": "ghi\ni"
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
