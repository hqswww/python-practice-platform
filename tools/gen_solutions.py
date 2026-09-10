#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批量生成题目参考代码(solution 字段) + 自动验证通过 test_cases。
用法: python3 gen_solutions.py <start_id> <end_id>
会先打印每题答案是否通过全部用例,再把通过的 solution 写回 JSON。
"""
import json, glob, subprocess, sys, os, tempfile

ANSWERS = {}

def _code(id_, code):
    global ANSWERS
    ANSWERS[id_] = code

# ============ 01_syntax ============
_code(101, '''# 最简单的程序:用 print 输出一行文字
print("Hello, Python!")''')

_code(102, '''# 定义两个变量,再分两行输出
name = "小明"
age = 18
# print 输出每个变量,默认换行
print("我的名字是" + name)
print("我今年" + str(age) + "岁")''')

_code(103, '''# 用 input() 读入一行输入(得到的是字符串)
name = input()
# 字符串用 + 连接
print("欢迎，" + name + "！")''')

_code(104, '''# input() 读到的是字符串,要先转成整数才能相加
a, b = input().split()   # 用空格把"3 5"拆成 ["3","5"]
a = int(a)               # 字符串 -> 整数
b = int(b)
print(a + b)''')

_code(105, '''# 浮点数运算:3.5 是浮点,乘 2 结果仍带 .0
print(3.5 * 2)  # 输出 7.0''')

_code(106, '''# 用 f-string 格式化输出,f"{变量}" 会把变量塞进字符串
n = input()
print(f"本次共收到 {n} 份作业")''')

# ============ 02_datatype ============
_code(201, '''# 读取两个整数,分别做四则运算
a, b = map(int, input().split())  # map 把两个值转成 int
print(a + b)   # 加
print(a - b)   # 减
print(a * b)   # 乘
print(a // b)  # 整除(//)只保留整数部分''')

_code(202, '''# 保留两位小数:用 f-string 格式化 {:.2f}
n = float(input())
# .2f 会补足到两位小数,如 5.0 -> 5.00
print(f"{n:.2f}")''')

_code(203, '''# 余数用 %,整除用 //
a, b = map(int, input().split())
print(a // b, a % b)''')

_code(204, '''# 由摄氏温度算华氏温度:C = (F - 32) * 5 / 9
f = float(input())
c = (f - 32) * 5 / 9
# 保留 1 位小数
print(f"{c:.1f}")''')

_code(205, '''# 交换两个变量:用 Python 的元组解包,一行搞定
a, b = input().split()
a, b = b, a   # 右边的 b,a 先打包成元组,再按顺序赋给 a,b
print(a, b)''')

_code(206, '''# 求平均值并保留两位小数
nums = list(map(int, input().split()))
avg = sum(nums) / len(nums)
print(f"{avg:.2f}")''')

# ============ 03_operators ============
_code(301, '''# 两个整数的五种运算
# + - * 直接算,/(浮点除,保留一位),%(求余)
a, b = map(int, input().split())
print(a + b)
print(a - b)
print(a * b)
print(f"{a / b:.1f}")  # 商保留一位小数
print(a % b)''')

_code(302, '''# 五个比较运算,按题目要求顺序输出
# 顺序: >  >=  <  <=  ==
a, b = map(int, input().split())
print(a > b)
print(a >= b)
print(a < b)
print(a <= b)
print(a == b)''')

_code(303, '''# 逻辑运算 and/or/not
a, b = input().split()
a, b = int(a), int(b)
print(a > 0 and b > 0)   # 5>0 且 -1>0 -> False
print(a > 0 or b > 0)    # True
print(not a > 0)         # False
''')

_code(304, '''# 幂运算用 **
a, b = map(int, input().split())
print(a ** b)''')

_code(305, '''# 区分 /(浮点)与 //(整除)
a, b = 7, 2
print(a / b)    # 3.5
print(a // b)   # 3
print(a % b)    # 1
print(a / b)    # 3.5
''')

_code(306, '''# 运算符优先级:** 最高,再 * / 和 %,最后 + -
# 先 4**2=16,再 3*16=48,最后 2+48=50
print(2 + 3 * 4 ** 2)''')

# ============ 04_conditionals ============
_code(401, '''# if/else 判断奇偶
n = int(input())
if n % 2 == 0:
    print("偶数")
else:
    print("奇数")''')

_code(402, '''# 输出两个数中较大的
a, b = map(int, input().split())
if a > b:
    print(a)
else:
    print(b)''')

_code(403, '''# 分数段分级:0-59 为 E,60 起依次 D/C/B/A
score = int(input())
if score >= 90:
    print("A")
elif score >= 80:
    print("B")
elif score >= 70:
    print("C")
elif score >= 60:
    print("D")
else:
    print("E")''')

_code(404, '''# 闰年:能被4整除且(不能被100整除或能被400整除)
year = int(input())
if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0:
    print("yes")
else:
    print("no")''')

_code(405, '''# 判断正数/负数/零
n = int(input())
if n > 0:
    print("正数")
elif n < 0:
    print("负数")
else:
    print("零")''')

_code(406, '''# 三个数取最大:两两比较
a, b, c = map(int, input().split())
if a >= b and a >= c:
    print(a)
elif b >= a and b >= c:
    print(b)
else:
    print(c)''')

# ============ 05_loops ============
_code(501, '''# 用 range(1, n+1) 生成 1 到 n 的序列,for 逐个取出并输出
n = int(input())
# range(1, n+1) 表示从 1 开始,到 n 为止(左闭右开)
for i in range(1, n + 1):
    print(i)''')

_code(502, '''# 累加求和:用一个变量 total 不断累加
n = int(input())
total = 0
for i in range(1, n + 1):
    total += i   # 等价于 total = total + i
print(total)''')

_code(503, '''# 打印 1 到 n 的偶数:数字 % 2 == 0 即为偶数
n = int(input())
for i in range(1, n + 1):
    if i % 2 == 0:
        print(i)''')

_code(504, '''# 嵌套 for 打印乘法表
# 外层 i 表示行(1~9),内层 j 表示每行从 1 到 i
# 每行内多个式子之间用空格分隔
for i in range(1, 10):
    row = []
    for j in range(1, i + 1):
        row.append(f"{j}x{i}={j*i}")
    print(" ".join(row))''')

_code(505, '''# 统计正数个数:遍历每个数,>0 就计数加一
n = int(input())
nums = list(map(int, input().split()))
count = 0
for x in nums:
    if x > 0:
        count += 1
print(count)''')

_code(506, '''# 阶乘:从 1 乘到 n
n = int(input())
result = 1
# 从1乘到n;若 n=0,循环不执行,result 保持 1
for i in range(1, n + 1):
    result *= i
print(result)''')

# ============ 06_strings ============
_code(601, '''# len() 返回字符串长度
s = input()
print(len(s))''')

_code(602, '''# 字符串直接用 + 拼接
# 注意:两行输入要分别 input() 读取
s1 = input()
s2 = input()
print(s1 + s2)''')

_code(603, '''# 切片 [::-1] 表示步长 -1,从后往前取,实现反转
s = input()
print(s[::-1])''')

_code(604, '''# .upper() 全大写,.lower() 全小写
s = input()
print(s.upper())
print(s.lower())''')

_code(605, '''# 统计字母 a 出现的次数,忽略大小写(A 和 a 都算)
# 先统一转小写再 count,这样大写 A 也算
s = input().lower()
print(s.count('a'))''')

_code(606, '''# 字符串切片
# s[0:3] 前3个字符;s[2:6] 下标2~5(共4个,第3到第6个字符)
# s[-3:] 末尾3个
s = input()
print(s[0:3])
print(s[2:6])
print(s[-3:])''')

# ============ 07_lists ============
_code(701, '''# sum() 对列表求和
nums = list(map(int, input().split()))
print(sum(nums))''')

_code(702, '''# 列表:append 加末尾,pop(0) 删第 0 个
lst = [1, 2, 3]
n = int(input())
lst.append(n)   # 加末尾 -> [1,2,3,n]
lst.pop(0)      # 删第一个 -> [2,3,n]
print(lst)''')

_code(703, '''# 反转列表用 [::-1],再按空格拼接输出
nums = list(map(int, input().split()))
rev = nums[::-1]
# 把每个数转回字符串,再用空格连接
print(' '.join(map(str, rev)))''')

_code(704, '''# 统计大于 0 的个数
nums = list(map(int, input().split()))
count = 0
for x in nums:
    if x > 0:
        count += 1
print(count)''')

_code(705, '''# max() 找最大值,index() 找第一次出现的位置
nums = list(map(int, input().split()))
m = max(nums)
print(m, nums.index(m))''')

_code(706, '''# 去重并保持顺序:用一个空列表,没见过的才加入
nums = list(map(int, input().split()))
seen = []
for x in nums:
    if x not in seen:
        seen.append(x)
print(' '.join(map(str, seen)))''')

# ============ 08_tuples_sets ============
_code(801, '''# 元组的 len() 长度与下标取值
# 元组里元素不能改,但能读
print(len((10, 20, 30, 40, 50)))
print((10, 20, 30, 40, 50)[-1])  # 负下标取最后一个''')

_code(802, '''# 元组打包:三个值放进一个元组
a, b, c = map(int, input().split())
t = (a, b, c)
print(t)              # (1, 2, 3)
# 交换前两个的值后输出
print(b, a, c)''')

_code(803, '''# set(集合)自动去重,len() 数不同的单词个数
words = input().split()
print(len(set(words)))''')

_code(804, '''# 集合运算:交集 & 并集 | 差集 -
setA = {1, 2, 3, 4}
setB = {3, 4, 5, 6}
print(setA & setB)   # 交集 {3,4}
print(setA | setB)   # 并集 {1..6}
print(setA - setB)   # 差集 {1,2}''')

_code(805, '''# in 判断元素是否在列表里,结果是 True/False
x = int(input())
print(x in [2, 3, 5, 7])''')

_code(806, '''# 列表转元组:tuple()
nums = list(map(int, input().split()))
print(nums)
print(tuple(nums))''')

# ============ 09_dicts ============
_code(901, '''# 字典按键取值 d[key]
d = {'name': 'Alice', 'age': 20, 'city': 'Beijing'}
key = input()
print(d[key])''')

_code(902, '''# 设置新键和修改已有键的值
# 给 d['c'] 赋值即新增;给已有键赋值即覆盖旧值
d = {'a': 1, 'b': 2}
x, y = map(int, input().split())
d['c'] = x
d['a'] = y
print(d)''')

_code(903, '''# 遍历字典:items() 同时拿到键和值
d = {'apple': 3, 'banana': 5, 'cherry': 2}
for k, v in d.items():
    print(f"{k}:{v}")''')

_code(904, '''# 统计单词出现次数:用字典存 单词->次数
words = input().split()
count = {}
for w in words:
    count[w] = count.get(w, 0) + 1
# 按第一次出现顺序输出
seen = set()
for w in words:
    if w not in seen:
        seen.add(w)
        print(w, count[w])''')

_code(905, '''# 合并字典:update() 会用 d2 覆盖同名键
d1 = {'a': 1, 'b': 2}
d2 = {'b': 3, 'c': 4}
# 把 d2 合并进 d1,重复键 b 以 d2 的 3 为准
res = dict(d1)
res.update(d2)
print(res)''')

_code(906, '''# 读多行 '键 值',找值最大的键(同值取最先出现)
# 用 sys.stdin 逐行读,直到输入结束
import sys
best_key = None
best_val = -1
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    k, v = line.split()
    v = int(v)
    # 严格大于才更新,保住最先出现的最大值
    if v > best_val:
        best_val = v
        best_key = k
print(best_key)''')

# ============ 10_functions ============
_code(1001, '''# 定义函数:def 函数名(参数):
def greet(name):
    print(f"Hello, {name}!")

name = input()
greet(name)''')

_code(1002, '''# 函数用 return 返回结果
def add(a, b):
    return a + b

a, b = map(int, input().split())
print(add(a, b))''')

_code(1003, '''# 偶数判断:n % 2 == 0
def is_even(n):
    return n % 2 == 0

n = int(input())
print(is_even(n))''')

_code(1004, '''# 默认参数:def f(x, times=2)
def repeat(text, times=2):
    return text * times   # 字符串乘整数=重复

s = input()
print(repeat(s))''')

_code(1005, '''# 多返回值:return 多个值
# min() max() 求最值
def min_max(nums):
    return min(nums), max(nums)

nums = list(map(int, input().split()))
a, b = min_max(nums)
print(a, b)''')

_code(1006, '''# 递归:函数调用自己,需有退出条件(基线条件)
def factorial(n):
    if n == 0:      # 基线
        return 1
    return n * factorial(n - 1)  # 递归

n = int(input())
print(factorial(n))''')

# ============ 11_advanced ============
_code(1101, '''# 列表推导式:对每个元素做平方
nums = list(map(int, input().split()))
sq = [x * x for x in nums]
print(sq)''')

_code(1102, '''# 列表推导式 + 条件过滤:只保留偶数
nums = list(map(int, input().split()))
# 若 x 是偶数(x%2==0)才保留
even = [x for x in nums if x % 2 == 0]
print(even)''')

_code(1103, '''# lambda 匿名函数 + 排序
# 分数降序;分数相同按名字(字典序升序)
import sys
pairs = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    name, score = line.split()
    pairs.append((name, int(score)))
# key 返回 (-分数, 名字):-分数使高分在前,名字处理同分先后
pairs.sort(key=lambda p: (-p[1], p[0]))
for name, _ in pairs:
    print(name)''')

_code(1104, '''# 异常处理:try/except
try:
    n = int(input())
    print(f"OK: {n}")
except ValueError:
    print("Error")''')

_code(1105, '''# 二维矩阵转置:行变列
# 读 3 行,每行 3 个数
grid = []
for _ in range(3):
    grid.append(list(map(int, input().split())))
# 转置:zip(*grid) 把每行对应位置组合成新行
for row in zip(*grid):
    print(' '.join(map(str, row)))''')

_code(1106, '''# 读未知行数整数,直到输入结束
import sys
total_count = 0
total_sum = 0
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    nums = list(map(int, line.split()))
    total_count += len(nums)
    total_sum += sum(nums)
print(total_count, total_sum)''')

# ============ 12_challenges ============
_code(1201, '''# 判断质数:只能被 1 和自己整除
n = int(input())
if n < 2:
    print(False)   # 0 和 1 不是质数
else:
    is_prime = True
    import math
    # 从 2 试到 sqrt(n) 即可(正因子成对出现)
    for i in range(2, int(math.isqrt(n)) + 1):
        if n % i == 0:
            is_prime = False
            break
    print(is_prime)''')

_code(1202, '''# 斐波那契:前两项 1,1,之后每项是前两项之和
n = int(input())
fib = []
a, b = 1, 1
for _ in range(n):
    fib.append(a)
    a, b = b, a + b
print(' '.join(map(str, fib)))''')

_code(1203, '''# 判断回文:忽略空格和大小写
# 先去掉所有空格,再统一小写,再对比反转
import re
s = input()
s = re.sub(r'\\s+', '', s).lower()
print(s == s[::-1])''')

_code(1204, '''# 统计元音字母个数,忽略大小写
s = input().lower()
vowels = set('aeiou')
count = 0
for ch in s:
    if ch in vowels:
        count += 1
print(count)''')

_code(1205, '''# 数字位数求和,直到一位数(数学上的数根)
# 若 n%9==0 且 n>0 则数根为 9
n = int(input())
if n == 0:
    print(0)
elif n % 9 == 0:
    print(9)
else:
    print(n % 9)''')

_code(1206, '''# 最大公约数:辗转相除法
# 反复用余数替换,直到余数为 0
def gcd(a, b):
    while b != 0:
        a, b = b, a % b
    return a

a, b = map(int, input().split())
print(gcd(a, b))''')
# ============ 验证逻辑 ============
def run_one(code, inp, timeout=3):
    """在一独立进程里运行代码,喂入 inp,返回 stdout 或抛错。"""
    with tempfile.NamedTemporaryFile('w', suffix='.py', delete=False, encoding='utf-8') as f:
        f.write(code)
        tmp = f.name
    try:
        p = subprocess.run(
            [sys.executable, tmp],
            input=inp.encode('utf-8') if inp else b'',
            capture_output=True, timeout=timeout,
            cwd=os.path.dirname(tmp) or '.',
        )
        out = p.stdout.decode('utf-8')
        # Windows 打包也可用,这里系统 python3
        return out + (p.stderr.decode('utf-8') if p.returncode != 0 else '')
    except subprocess.TimeoutExpired:
        return '__TIMEOUT__'
    finally:
        os.unlink(tmp)

def normalize(s):
    # 行尾去空白,统一换行(与判题引擎 _normalizeLines 一致:保留行内/前导空格)
    lines = [l.rstrip() for l in s.replace('\r\n', '\n').split('\n')]
    # 去掉末尾的纯空行
    while lines and lines[-1] == '':
        lines.pop()
    return lines

def solve_testcases(id_, code, tests):
    ok_all = True
    detail = []
    for i, tc in enumerate(tests):
        out = run_one(code, tc.get('input',''))
        if out == '__TIMEOUT__':
            detail.append(f"[{i+1}] 超时"); ok_all = False; continue
        got = normalize(out)
        want = normalize(tc.get('output',''))
        if got == want:
            detail.append(f"[{i+1}] 通过")
        else:
            detail.append(f"[{i+1}] 失败 got={got} want={want}")
            ok_all = False
    return ok_all, detail

def main():
    files = sorted(glob.glob('assets/problems/python/*.json'))
    all_ok = True
    for f in files:
        with open(f, encoding='utf-8') as fh:
            probs = json.load(fh)
        changed = False
        for p in probs:
            pid = p['id']
            if pid not in ANSWERS:
                continue
            ok, detail = solve_testcases(pid, ANSWERS[pid], p['test_cases'])
            if ok:
                if p.get('solution') != ANSWERS[pid]:
                    p['solution'] = ANSWERS[pid]
                    changed = True
                print(f"  ✓ {pid} {p['title']}")
            else:
                all_ok = False
                print(f"  ✗ {pid} {p['title']}: " + "; ".join(detail))
        if changed:
            with open(f, 'w', encoding='utf-8') as fh:
                json.dump(probs, fh, ensure_ascii=False, indent=2)
                fh.write('\n')
            print(f"  -> 写入 {f.split('/')[-1]}")
    print("\n=== 全部通过" if all_ok else "\n=== 有失败,需修正 ANSWER ===")

if __name__ == '__main__':
    main()
