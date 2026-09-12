# C 题库编写规格

> 给编写/扩充 `assets/problems/c/*.json` 的人（或 AI）看的。
> **范例：`assets/problems/c/01_basics.json`** —— 结构、文风、注释密度都以它为准。

---

## 一、分类与题目 id 分配

**id 必须严格落在各自区间内。** 进度是按「语言_题号」存的（`c_901`），
跨分类撞号会造成两道题共享同一份进度。

| 文件 | 分类名 | 说明 | id 段 |
|------|--------|------|-------|
| `01_basics.json` | 基础语法 | 程序结构、printf、scanf、变量、注释 | 101–106 |
| `02_datatype.json` | 数据类型与变量 | int/float/double/char、常量、sizeof、类型转换 | 201–206 |
| `03_operators.json` | 运算符 | 算术、关系、逻辑、位运算、优先级 | 301–306 |
| `04_conditionals.json` | 判断与分支 | if / else if / else、switch | 401–406 |
| `05_loops.json` | 循环 | for / while / do-while、break / continue | 501–506 |
| `06_functions.json` | 函数与作用域 | 定义、参数、返回值、递归、作用域 | 601–606 |
| `07_arrays.json` | 数组 | 一维/二维数组、遍历、查找、排序 | 701–706 |
| `08_strings.json` | 字符串 | char 数组、`<string.h>` 常用函数 | 801–806 |
| `09_pointers.json` | 指针 | 指针基础、指针与数组、指针与函数 | 901–906 |
| `10_structs.json` | 结构体与共用体 | struct / union / enum / typedef | 1001–1006 |
| `11_advanced.json` | 进阶 | 预处理器、文件读写、malloc/free | 1101–1106 |
| `12_challenges.json` | 综合挑战 | 跨知识点应用题 | 1201–1206 |

分类顺序对齐 runoob 的 C 教程目录。「指针」是 C 的分水岭，可以多放 medium。

---

## 二、JSON 结构

文件顶层是**数组**，每题一个对象，字段一个都不能少：

```json
{
  "id": 101,
  "title": "Hello, C!",
  "difficulty": "easy",
  "description": "编写一个 C 程序，在屏幕上输出一行文字：Hello, C!",
  "input_format": "无输入",
  "output_format": "输出一行 Hello, C!",
  "sample_input": "",
  "sample_output": "Hello, C!",
  "test_cases": [{ "input": "", "output": "Hello, C!" }],
  "hints": ["提示一", "提示二"],
  "solution": "#include <stdio.h>\n\nint main() {\n    printf(\"Hello, C!\\n\");\n    return 0;\n}\n",
  "tutorial": [
    {
      "title": "小节标题",
      "body": "讲解正文，可含 \\n 换行",
      "code": "示例代码片段",
      "output": "该片段的运行结果"
    }
  ]
}
```

要点：

- `difficulty` 只能是 `easy` / `medium` / `hard`
- `hints` 是**递进**的：第一条只给方向，后面的才给具体函数名/写法
- `solution` 是**完整可编译**的 C 程序，必须含 `#include` 和 `return 0;`
- `tutorial` 至少 1 节；`code` / `output` 可以为空字符串
- 测试用例的 `input` 结尾**要带 `\n`**（跟真实键盘输入一致），
  无输入的题写空字符串

---

## 三、判题比对规则（写用例时必须知道）

判题引擎比对输出时（`judge_engine.dart` 的 `_normalizeLines`）：

1. 统一换行符（`\r\n` / `\r` → `\n`）
2. **去掉每行的尾随空白**
3. **去掉开头和结尾的空行**
4. 全角/半角标点等价（`，`↔`,`、`！`↔`!` 等）

所以「最后一行尾部有没有换行」「行尾多了空格」都不影响判对；
但**行数、每行内容、内部空行**必须一致。

---

## 四、内容与文风要求

面向**零基础**学生，中文。

**description**：说清要做什么，不要泄漏实现方法。
**input_format / output_format**：精确。要写明白「一行两个整数用空格分隔」
「保留 2 位小数」这类细节——这是学生最容易卡住的地方。

**教程要讲「为什么」，不只是「怎么做」。** 优先指出新手易错点，例如：

- 整数除法 `9/5` 得到 1 而不是 1.8
- `scanf` 漏了 `&` 能编译通过但运行崩溃
- 局部变量不初始化是内存里的随机值
- 数组下标从 0 开始，访问 `a[n]` 是越界
- `char s[10]` 存 9 个字符就要留一个给 `'\0'`

**solution 里要有注释**，注释解释易错点而不是复述代码。

---

## 五、必须自检到全绿

```bash
python3 tools/verify_c_bank.py 09_pointers   # 只查某个分类
python3 tools/verify_c_bank.py               # 查全部
```

脚本会真用 clang 编译每道题的 `solution`，真跑它的每个 `test_cases`，
按上面的比对规则核对输出。

**必须全部 ✓ 才算完成。** 不通过就改代码或改用例，反复到全过为止。

另外 Flutter 侧有一条等价的自检测试（用**真判题引擎**跑）：

```bash
flutter test test/c_runtime_test.dart
```

两边都要过。写完一个分类至少跑一次脚本自检。

---

## 六、容易翻车的地方

| 症状 | 原因 |
|------|------|
| 自检报「用例 N 输出不符」 | 大概率是末尾换行或多余空格——先看脚本打出的 `repr` |
| 参考答案编译失败 | 少了 `#include`、漏分号、用了 C99 以上才允许的写法 |
| 多行输出少了/多了空行 | 判题会去掉首尾空行，但**中间**的空行是算数的 |
| 浮点输出对不上 | `%.2f` 的四舍五入 vs 学生用 `%g`；用例里写清保留几位 |
