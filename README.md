# 🐍 Python 练习平台

一个面向 Python 初学者的**本地自习 + 刷题** Flutter 桌面应用（Linux / Windows）。

> 现状：**v1.0-final** — P1/P2/P3 全部完成，Windows 绿色版 .exe（免装 Python）已可分发。

---

## ✨ 功能

- **72 道题**，12 个分类（基础语法 → 数据类型 → 运算符 → 条件 → 循环 → 字符串 → 列表 → 元组集合 → 字典 → 函数 → 进阶 → 综合挑战），难度 easy/medium/hard 三级
- **判题引擎**：内置 Python 实时运行，比对输出；支持交互终端（A主B辅）
- **判题输入自适应**：`input()` 单行/多行写法自适应，答案对上就算对
- **学习页详细教程**：72 题全覆盖，runoob 风格分区卡片讲解
- **成就与称号系统**：13 个成就 + 6 级称号，判题通过解锁弹窗
- **自定义主题强调色**：6 套色板，即时换肤，保留明暗模式
- **错题本 + 收藏 + 测试模式 + 进度统计 + 导出**

## 🚀 运行 / 构建

```bash
# Linux 开发
flutter run -d linux

# Windows 发布（需 Windows 机器 + Flutter + VS2022 C++ 工作负载）
powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1
```

## 📂 项目结构

- `lib/` — Flutter 源码（models / services / pages / widgets）
- `assets/problems/` — 72 道题题库 JSON
- `tools/` — 教程批量脚本、Windows 打包脚本
- `docs/WINDOWS_MIGRATION.md` — Windows 迁移手册
- `PROJECT_BACKLOG.md` — 待办 / 想法池

## 🔖 版本

- v1.0-final — 正式版（P1-P3 全 + Windows 迁移）
- v0.6-tutorials-all — 72 题教程铺完

详细设计见 [DESIGN.md](DESIGN.md)、待办见 [PROJECT_BACKLOG.md](PROJECT_BACKLOG.md)。
