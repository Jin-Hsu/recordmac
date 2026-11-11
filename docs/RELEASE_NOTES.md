# 轻录 1.2.1 · 首次公开测试版

面向 macOS 教学演示的本地录屏工具。源码仓库名为 recordmac，应用名为轻录（QingLu）。

## 下载

- `QingLu-1.2.1-arm64.dmg`：Apple Silicon / macOS 15+ 安装包。
- `SHA256SUMS.txt`：安装包校验值。
- GitHub 自动生成的 Source code：源码，不是安装包。

## 已包含

全屏/区域录制、系统声、麦克风、摄像头画中画、录制前布局与大小设置、区域边框、计时提示、倒计时与保存位置。

## 使用前须知

当前为未公证、临时签名的测试版。首次运行可能需要在系统设置允许打开和录屏/麦克风/摄像头权限。摄像头合成输出固定 30 fps；布局缩略图比例与长时间音画同步仍需改进。正式长录前请先做短录测试。

本次已从公开版源码构建并验证 DMG 完整性；尚未完成多机型、长时录制的端到端验收。

## 许可

CC BY-NC 4.0：署名、非商业用途。商业用途需另行授权。详情见仓库 LICENSE。

---

First public beta of QingLu, a local macOS screen recorder with system audio, microphone and camera picture-in-picture. Apple Silicon / macOS 15+ only. Ad-hoc signed and not notarized. Camera composition exports at 30 fps; layout and long-session synchronization still need validation. Test a short recording first. Licensed under CC BY-NC 4.0 (noncommercial).
