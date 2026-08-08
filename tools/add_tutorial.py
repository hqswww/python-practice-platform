#!/usr/bin/env python3
"""给 101/102/103 题添加 runoob 风格 tutorial 字段（试水）。"""
import json, sys

PATH = "assets/problems/01_syntax.json"

with open(PATH, encoding="utf-8") as f:
    data = json.load(f)

tutorials = {
101: [
  {
    "title": "认识 print() 函数",
    "body": "print() 是 Python 中最常用的输出函数，它的作用是把内容显示到屏幕上。\n写法非常简单：先写 print，紧跟一对圆括号，圆括号里放你要输出的内容。\n\n下面这句代码就能在屏幕上打印出文字：",
    "code": "print(\"Hello, Python!\")",
    "output": "Hello, Python!"
  },
  {
    "title": "字符串要加引号",
    "body": "注意代码里的内容是放在英文双引号 \" \"（或单引号 ' '）里的。\n这种被引号包起来的文本叫做「字符串」（string）。\n\n如果忘了加引号，Python 会把 Hello 当成一个变量名，报 NameError 错误。",
    "code": "print(Hello, Python!)   # 错误! 没加引号\nprint(\"Hello, Python!\")  # 正确",
    "output": "Hello, Python!"
  },
  {
    "title": "程序就是一行行指令",
    "body": "Python 程序就是从上到下依次执行的指令集合。这里的 \"Hello, Python!\" 两端引号里面的逗号是普通字符，会原样输出。\n\n现在动手试试：把代码写进代码区，点击运行，看看结果是不是屏幕上出现了那一行文字。",
    "code": "print(\"Hello, Python!\")"
  }
],
102: [
  {
    "title": "什么是变量",
    "body": "变量就像一个「贴了标签的盒子」，你可以往里面放东西，并给它起个名字，方便之后取用。\n\n在 Python 里创建一个变量很简单：变量名 = 值。等号右边可以是文字（字符串）或数字。",
    "code": "name = \"小明\"   # 把字符串 \"小明\" 放进名为 name 的盒子\nage = 18          # 把整数 18 放进名为 age 的盒子"
  },
  {
    "title": "变量要先用再取",
    "body": "定义好变量后，之后用到变量名，Python 就会自动取出盒子里存的值。\n\nprint() 括号里放变量名，就会把变量的值打印出来。注意这里不能加引号——加了引号就变成输出文字“name”本身了。",
    "code": "print(name)     # 输出 name 里存的值,即 小明\nprint(\"name\")   # 输出字符串 name 这几个字符"
  },
  {
    "title": "连接字符串",
    "body": "可以把多个字符串用加号 + 拼在一起。\n但要小心：文本加号只对「字符串」有效。数字 age 是整数，不能直接和字符串拼接，需要先用 str() 把它转成字符串。",
    "code": "print(\"我的名字是\" + name)\nprint(\"我今年\" + str(age) + \"岁\")",
    "output": "我的名字是小明\n我今年18岁"
  }
],
103: [
  {
    "title": "用 input() 接收输入",
    "body": "上一题我们写死了名字，但程序常常需要读取用户输入。\ninput() 函数会等待你从键盘输入一行内容（按回车结束），并把输入的内容作为【字符串】返回。",
    "code": "name = input()"
  },
  {
    "title": "把输入存进变量",
    "body": "把 input() 的返回值赋给变量 name，之后就能反复使用了。\n需要提醒：input() 得到的永远是字符串，即使你输入的是数字 18，它也是字符串 \"18\"。",
    "code": "name = input()   # 输入 悟空\nprint(name)       # 输出 悟空"
  },
  {
    "title": "拼接实现完整输出",
    "body": "现在用字符串拼接，把欢迎语和名字拼成一句完整的话输出。",
    "code": "name = input()\nprint(\"欢迎，\" + name + \"！\")",
    "output": "欢迎，悟空！"
  }
],
104: [
  {
    "title": "input() 读进来的是字符串",
    "body": "上一题我们知道了变量，这一题有个坑必须注意：\n用 input() 读进来的内容，永远是【字符串】类型，即使你输入的是 3、5 这样的数字。\n\n而字符串是不能直接做加法运算的（\"3\" + \"5\" 得到的是 \"35\" 而不是 8）。",
    "code": "a = input()  # 输入 3\nb = input()  # 输入 5\nprint(a + b) # 输出 35! 因为字符串拼接,不是加法"
  },
  {
    "title": "用 int() 把字符串转成整数",
    "body": "要让它们做真正的加法，需要先用 int() 把字符串转成整数。\nint() 能识别字符串里的数字，转成一个可计算的整数。",
    "code": "a = input()\na = int(a)   # 把字符串 \"3\" 转成整数 3\nprint(a)     # 现在可以参与乘法、加法了"
  },
  {
    "title": "用 split() 一次拆开多个数据",
    "body": "题目说一行里有 a 和 b 两个数，中间用空格分隔：3 5\n可以用 input().split() 把这行按空格拆成多个部分，得到列表 [\"3\", \"5\"]。\n\n再配合 int() 转换，就能一行搞定了：",
    "code": "a, b = input().split()   # 把 \"3 5\" 拆成 a=\"3\", b=\"5\"\na = int(a)\nb = int(b)\nprint(a + b)             # 8",
    "output": "8"
  }
],
105: [
  {
    "title": "什么是浮点数",
    "body": "Python 里有两类常用的数字：整数（int）和浮点数（float）。\n\n浮点数就是带小数点的数，比如 3.5、-0.5、100.0。\n判断一个数是整数还是浮点数，最简单的方法就是看它带不带小数点。",
    "code": "print(3)     # 整数\nprint(3.0)   # 浮点数,带 .0"
  },
  {
    "title": "数字可以直接做运算",
    "body": "和数学一样，Python 支持加 + 减 - 乘 * 除 /。\n乘号用 *（不是 x），除号用 /。可以直接把算式放进 print() 里，Python 会先算出结果再输出。",
    "code": "print(3.5 * 2)   # 乘法,结果 7.0"
  },
  {
    "title": "为什么结果是 7.0 而不是 7",
    "body": "注意：1 个浮点数参与的运算，结果通常也是浮点数。\n3.5 是浮点数，所以 3.5 * 2 得到 7.0（带小数点）。\n\n如果你希望结果不带小数点，可以用 int() 把它转成整数。",
    "code": "print(3.5 * 2)      # 7.0\nprint(int(3.5 * 2))  # 7",
    "output": "7.0\n7"
  }
],
106: [
  {
    "title": "什么是格式化字符串",
    "body": "很多时候我们要把变量的值「塞」进一句话里输出。\n比如题目要求输出：本次共收到 42 份作业，其中 42 是会变的数字。\n\n如果直接拼接比较麻烦，Python 提供了一种更优雅的写法：f-string（格式化字符串）。",
    "code": "n = 42\nprint(f\"本次共收到 {n} 份作业\")   # 输出: 本次共收到 42 份作业"
  },
  {
    "title": "f-string 的写法",
    "body": "f-string 就是在字符串前加一个字母 f（或 F），然后在里面用大括号 { } 包住变量名。\n\nPython 会把 {变量} 替换成变量当前的值。是不是很像填空？",
    "code": "name = \"小明\"\nprint(f\"你好,{name}!\")     # 你好,小明!\nprint(f\"1 + 1 = {1 + 1}\")  # 1 + 1 = 2"
  },
  {
    "title": "本题完整解法",
    "body": "先读入整数 n（用 input 配合 int 转换），再用 f-string 输出作业数量。\n\n注意：f-string 里的 {n} 直接放变量名即可，不需要写 + 或 str()。",
    "code": "n = input()\nprint(f\"本次共收到 {n} 份作业\")",
    "output": "本次共收到 42 份作业"
  }
],
}
for item in data:
    if item["id"] in tutorials:
        item["tutorial"] = tutorials[item["id"]]
        print(f"已添加 tutorial → {item['id']} {item['title']}")

with open(PATH, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")

print("写入完成")
