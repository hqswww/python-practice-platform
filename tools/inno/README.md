# Inno Setup 简体中文语言包（随仓库分发）

这里的 `ChineseSimplified.isl` 不是 Inno Setup 官方自带的，而是第三方翻译，
为了**不依赖用户装的 Inno Setup 版本**才随仓库带上：

- 来源：<https://github.com/kira-96/Inno-Setup-Chinese-Simplified-Translation>
- 许可证：MIT（见同目录 `LICENSE`，版权归 kirakira）
- 适用版本：Inno Setup **6.5.0+**（文件头第一行就写着）

## 为什么要带进仓库，而不是让用户自己下

Inno Setup 的官方翻译虽然「通常随安装包一起提供」，但**不同版本带的不一样**，
而且中文翻译更新得比官方版本快。把语言包钉在仓库里：

- 构建结果可复现（不受用户装的是哪个 Inno 版本影响）
- 不用在构建时联网下载
- 翻译文本的改动可以在 git 里看到

## 升级语言包

从上游仓库取新的 `ChineseSimplified.isl` 覆盖本文件即可。
⚠️ 上游是按 Inno Setup 版本写的，若把文件换成要求更高版本的，
`installer.iss` 里的 `MinVersion` 之类声明也要跟着确认。
