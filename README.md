# 光路工坊 · Lightworks

可离线游玩的 UIKit 光路方块解谜首版，三章共 45 关。**按 2026-10-12 最新要求，不接入内购；所有章节随应用提供，按通关顺序解锁。** `design/` 中早期商业化设想仅作为历史设计资料。

最新功能与内容审查见 [上线前审查报告](verification/Drairtunvur-release-audit.md)：已修复存档兼容与恢复、通关收尾、帮助和问题信息导出；关卡同质化、收藏内容差异及真机验证仍需完成。

## 原型还原更新

城市页改为六个沿栈道排列的关卡节点、底部章节选择卡、双行金色按钮与全宽底部导航（城市／每日／图鉴）；对局采用紧凑灯塔 HUD 和统一玻璃材质；结算使用双灯塔背景和双列统计；图鉴采用港湾主图与双列收藏卡。新背景按原型参考生成，完整提示词见 `design/asset-prompts.txt`。所有控件仍是原生交互，关卡、剩余步数、收藏数量均来自真实状态。

[新版城市截图](verification/previews-v2/iphone-03-city.png) · [新版结算截图](verification/previews-v2/iphone-02-victory.png) · [新版图鉴截图](verification/previews-v2/iphone-04-collection.png)

## 运行

1. 用 Xcode 26.6 打开 `Drairtunvur.xcodeproj`。
2. 选择共享 Scheme **Drairtunvur** 和 iOS 26.5 模拟器，直接 Run。
3. 首次进入教学关；选择横向两格方块，再点第 4 行第 7 列，一步触发传光、消除、通关。支持拖放，也支持先选候选再点棋盘。

也提供 [Release 模拟器构建包](deliverables/Lightworks-simulator-audited.zip)，解压后可将 `Drairtunvur.app` 拖入已启动的 iOS 26.5 Simulator 安装；它不能安装到真实 iPhone。

当前应用最低版本配置为 iOS 15.6；本次仅将纯规则模块的最低声明降为 iOS 15 以兼容现有配置。保留 Swift 5 语言模式、`com.tmuo.Drairtunvur` Bundle ID、签名与设备方向配置。真机运行需要用户自己的有效签名团队与设备；本次没有上传、发布或提交审核。

## 已实现

- 8×8 棋盘，固定朝向，每批三个、全部使用后补牌，固定序列与有限步数。
- 同一纯规则解析器驱动预览和正式落子。上下左右导光；先传光充能，后同时清除满行／满列；一次落子只有一次脉冲；能量保留，方块不下落。
- 完整撤销（含失败后）、最后一步判胜优先、三类失败原因、重开、暂停、继续。
- 后台执行、可取消的提示搜索；仅提供完整通关续局验证后的下一步，明确区分搜索超时与穷尽无解。
- 三章 45 关 JSON 内容，逐关附可重放参考解；前 10 关通过模拟器逐步实际操作验证。
- 城市地图、原生节点、真实章节进度、结算、最好步数、9 个按 5／10／15 关里程碑解锁的场景收藏。
- 独立夜景（含新版港湾和双灯塔结算背景）、原生玻璃方块与金色光路、Core Animation 脉冲、合成音效、触觉、减少动画设置。
- 简体中文／英语与系统语言，String Catalog、动态字体、VoiceOver 棋盘格／候选标签和替代拖动操作。
- 版本化 JSON 存档、actor 串行原子写入、递增版本拒绝旧写入、备份恢复、坏档保留、内容版本变化时保留长期进度。

首版无业务服务器、广告、账号和第三方运行时依赖。图鉴是三幅城市场景的九个进度里程碑，并非九个不同城市。

## 每日挑战

[每日页面截图](verification/previews-daily/iphone-10-daily.png) · [每日完成截图](verification/previews-daily/iphone-11-daily-completed.png)

「每日」按本地日期零点轮换一道已验证的章节题目，无需网络。支持继续挑战、提示、撤销、失败重试、完成后重玩和最佳步数；页面显示累计完成、连续完成及最近七天记录。每日局面独立于主线，跨日完成记在开始当天。保存最近七个每日局面，完成记录长期保留；题目快照随存档保存，应用重启仍可续玩。旧存档不含 daily 字段时自动从空记录开始。

每日题目复用随应用提供的章节关卡，按日期轮换，不宣称每天生成全新关卡。日期依据设备本地时间，无在线校时或排行榜。

## 工程结构

| 路径 | 用途 |
| --- | --- |
| `Packages/LightworksCore` | Foundation 规则、模型、存档、提示；独立于 UI 的本地 Swift Package |
| `Drairtunvur/Features` | 地图、对局、结算、图鉴、设置 |
| `Drairtunvur/Rendering` | 原生棋盘、玻璃方块、场景和通用视觉组件 |
| `Drairtunvur/Services` | AppModel、音效、偏好与语言 |
| `Drairtunvur/Resources/levels.json` | 45 关及其固定序列和参考解 |
| `Drairtunvur/Assets.xcassets` | 章节场景、按原型重建的港湾与双灯塔结算背景，以及应用图标 |
| `design/asset-prompts.txt` | 生成资源的完整提示词与文件映射 |
| `LightworksUITests` | 实际交互、存档恢复、连续通关与适配测试 |
| `verification` | 构建日志、测试日志与实际模拟器截图 |

## 验证命令

```sh
swift test --package-path Packages/LightworksCore --scratch-path /tmp/lightworks-core-build
xcodebuild -project Drairtunvur.xcodeproj -scheme Drairtunvur \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/lightworks-derived CODE_SIGNING_ALLOWED=NO \
  -parallel-testing-enabled NO test
```

构建单独使用 `build`；Release 可加 `-configuration Release`。UI 测试使用独立的 `Lightworks-UITests` 存档目录，不擦除正常游戏进度。仅 Debug 支持 `-ui-testing`、`-reset-test-save`、`-ui-language` 和 `-ui-test-level`，不进入 Release。

关卡生成器 `python3 scripts/generate_levels.py` 采用确定性布局模板；生成后必须运行核心测试重放全部参考解。关卡数量不等同于已经完成玩家难度测试。参考解证明可解，不宣称最短，也不保证任何偏离操作后仍可通关。

语言文本在 `L.text` 中保留双语值，静态键由 `scripts/localize.py` 同步到 String Catalog；包含运行时数字的句子由双语格式直接生成。

## 当前验证范围和后续实测

见 [验证报告](verification/REPORT.md)。核心与模拟器验证不能代替真机帧率、触觉、音频中断和 VoiceOver 手工检查。提示有时间预算，复杂偏离局面可能只能提示撤销或继续探索。建议先进行 8–12 位玩家的节奏和难度测试，再调整关卡。

发布前仍需确认品牌、支持联系方式、隐私政策页面、真实签名与商店资料。**不需要内购商品、售价或支付沙盒配置。**
