# 液态底栏 LiquidTabBar（微信）

## 编译
1. 新建 GitHub 仓库，把本目录全部文件（含 .github）上传。
2. Actions → build → 下载 artifact `LiquidTabBar-deb`，里面就是 .deb。
3. 本机有 Theos 也可：`make package`。
4. 用 lcsign 把 deb 里的 dylib 注入微信即可。

## 功能
- iOS 26 使用系统 UIGlassEffect（Liquid Glass），低版本自动降级为毛玻璃。
- 中间条左右滑动：迷你播放器 / 搜索页。
- 点底栏中间圆盘或迷你播放器封面：门轴式弹开音乐面板；长按圆盘播放/暂停。
- 音乐：网易云直连；QQ音乐走 Meting 接口。支持搜索、歌单（ID）、歌词、锁屏控制、后台播放。
- 左/右按钮：可在 设置 中显示/隐藏、改功能。右侧默认快捷面板（门轴反向弹开）。
- 入口：微信 我 → 设置 → 液态底栏（也可点底栏左侧按钮）。

## 与 JS 版 TM API 的对应
TM.loadPlaylist / loadSong / getSongUrl / getLyric → 见 LTBCore.m 里的 `TM` 类。
