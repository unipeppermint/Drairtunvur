# 首版验证记录

最新上线前功能与内容审查见 [Drairtunvur-release-audit.md](Drairtunvur-release-audit.md)。本轮核心 21 项、UI 9 项通过，Release 模拟器构建成功；下文保留各历史版本的测试记录，不代表当前仍只有早期数量的测试。

2026-10-12 · Xcode 26.6 (17F113) · iOS Simulator 26.5

## 当前交付范围

三章 45 关的离线游戏，UIKit 与独立本地 Swift Package，无第三方运行时依赖。按用户最新要求，**没有内购、购买页、恢复购买或付费锁**。章节依旧按通关顺序解锁。Bundle ID、签名、最低系统和语言模式沿用原工程。

## 已完成的验证

| 项目 | 结果与范围 |
| --- | --- |
| 核心测试 | 13 项 XCTest 通过，0 失败；见 `core-tests.log` |
| 45 关参考解 | 全部合法且通关，共 255 次落子；逐步验证预览等于正式落子，非成功状态撤销完整恢复 |
| 规则边界 | 非法落子、斜角不连通、源格未覆盖、断路与无消除不充能、多线单脉冲、行列交叉并集、容量封顶、无重力、最后一步判胜、整批补牌后无处可放、序列耗尽 |
| 存档 | Codable 往返、注入写入失败、过期写入拒绝、主档损坏恢复备份、未知 schema 保留坏档、内容版本变化保留历史成绩、奖励幂等 |
| iPhone 实际 UI | 教学通关、重玩计数不重复、失败撤销、提示、拖放、脉冲期间后台中断、冷启动恢复及撤销、中英文、设置、图鉴解锁条件 |
| 前 10 关 | 模拟器连续逐步操作，真实通关后进入已获得图鉴；见 `ten-level-ui.log` |
| 小屏 | iPhone SE (3rd generation) 教学、拖放、中断、重玩、地图及图鉴流程通过；见 `small-screen-tests.log` |
| iPad | iPad mini (A17 Pro) 竖屏教学与导航通过；横屏完整棋盘和候选均可触达；见 `ipad-tests.log`、`ipad-final/` |
| Release | 模拟器 Release 构建通过，已安装启动并导出安装包；见 `release-build.log` |

最终干净构建完整回归 **7 项 UI 测试通过、0 失败**（148.5 秒），见 `ui-tests-final.log` 与 `ui-test-summary.json`。iPhone SE 最终补测 2 项、iPad 最终测试 2 项均通过。

## 性能和提示的实测范围

- 本机 macOS Debug 测试中，1000 次规则预览平均 **0.052 毫秒**；这不是低端 iPhone 的性能结论。
- 45 个初始局面均能返回经过完整回放验证的参考续局。
- 9 个确定性偏离局面、每次 **100 毫秒**的压力预算：1 个找到完整续局，1 个穷尽确认无解，7 个超时。应用实际预算为 **500 毫秒**。超时显示“暂未找到完整解法”，不冒充无解。
- 搜索在后台可取消，返回结果校验局面版本；动画只展示已经提交并请求保存的规则结果，不参与计分或充能。

## 测试中修复的问题

- UIKit `UIControl` 属性命名冲突与显式模块导入。
- 城市节点自绘视图的黑色不透明底色。
- 后台中断落子动画后，回到前台未自动进入结算。
- iPad 浮动导航标题初始化异常；统一采用底部城市／图鉴导航。
- 横屏棋盘过高，改为棋盘与操作区左右排列；小屏竖屏按可用高度缩小棋盘并保留滚动。
- 清理内购实现后的增量构建残留：最终产物从全新目录构建，并检查没有 StoreKit 配置或购买实现。

## 资源、隐私与外部配置

三幅独立场景与应用图标通过内置 imagegen 生成，资源和提示词保存在工程中，未使用整张原型作为应用界面。音效为本地合成的短音色。当前图鉴九个收藏节点复用三幅对应城市场景；精细分建筑亮灯美术可继续打磨。

`PrivacyInfo.xcprivacy` 声明仅在应用内使用偏好存储，以及为提示搜索计时访问系统运行时长；不采集、不跟踪。理由依据 [Apple required reason API 文档](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)。

未进行真机 Instruments 帧率、耗电和内存峰值测量，也未声称达到真机 60 fps。真机声音、触觉、系统音频中断和 VoiceOver 逐项人工巡检仍需实际设备。关卡是有解的首版内容，尚未完成外部玩家难度／节奏验证；不声称参考解最优。

真机安装和上架仍需用户提供有效签名、正式品牌与支持联系方式、隐私页面及商店资料。没有上传、发布或审核提交。无需任何内购配置。

## 最终截图

- [iPhone 城市地图](previews/iphone-03-city.png)
- [iPhone 英语提示](previews/iphone-06-english-hint.png)
- [通关结算](previews/iphone-02-victory.png)
- [获得的收藏](previews/iphone-08-earned-collection.png)
- [iPad 横屏棋盘](previews/ipad-09-landscape.png)
- [iPhone SE 教学](previews/small-01-tutorial.png)

## 2026-10-12 原型还原修订

按 `design/lightworks-prototype.png` 重新组织四个页面，并增加 `harbor-v2` 与 `harbor-victory` 两个独立场景资源。城市改为六节点栈道、底部章节选择卡、双行金色按钮与全宽双项导航；对局改为紧凑灯塔 HUD、共享玻璃绘制材质，玩法说明移入暂停菜单；结算使用双灯塔背景和双列统计；图鉴改为主场景与双列卡片。图鉴裁切按建筑位置调整，卡片触摸不被装饰视图拦截。小屏按可用高度收缩棋盘和托盘。

保留真实进度、45 关规则、九个收藏条件及无内购设定。重建背景接近原型的构图与氛围，并非逐像素复制；教学局面及数字由真实状态决定。当前工程应用目标已为 iOS 15.6，本次没有修改项目发布配置，只把 Foundation 规则包的最低系统声明从 iOS 16 降为 iOS 15，以解决模块与应用目标不一致的编译错误。仍仅在 iOS 26.5 模拟器验证运行，未将其描述为 iOS 15 真机实测。

验证记录：

- 核心 13 项测试通过，包含全部 45 关参考解；`visual-core.log`。
- iPhone 完整七场景回归中，存档恢复、拖放与中断、英语提示设置、失败撤销、横屏五项通过；新图鉴裁切视图拦截触摸导致两项失败。修复后重跑教学／地图／锁定图鉴，以及连续十关／已解锁收藏，两项均通过，见 `visual-verified.log`。
- 最后的小屏尺寸与节点绘制调整后，iPhone 教学／地图／结算／图鉴再次通过，见 `visual-finalscreens.log`。
- iPhone SE 教学／地图／结算／图鉴与横屏两项通过，见 `visual-small2.log`；人工检查截图确认撤销、提示和三个托盘同时可见。
- iPad 横屏检查通过；触摸修复后教学／地图／结算／图鉴重跑通过，见 `visual-ipad2.log`。
- 最终 Release 模拟器构建通过，见 `visual-release.log`。安装包为 `deliverables/Lightworks-simulator-v2.zip`。

最终实际运行截图位于 `verification/previews-v2/`；先前 `previews/` 保留为旧版对照。资源完整提示词与文件来源保存在 `design/asset-prompts.txt`。Bundle ID、签名团队及发布配置没有更改。

最后按安全区域高度调整城市留白，修复 iPad 兼容窗口下按钮与导航重叠，并调整主图灯塔裁切。iPhone 与 iPad 教学／地图／结算／图鉴重跑通过（`visual-delivery.log`、`visual-ipad-delivery.log`）；最终 Release 和交付 ZIP 已同步，ZIP 完整性检查通过。

## 2026-10-12 每日挑战

新增可玩的「每日」入口，底部导航顺序为城市／每日／图鉴。每日按照设备本地日期从已验证的章节题目轮换，保留题目快照、局面及撤销历史，使用独立 DailyProgress；不覆盖主线、不推进章节或图鉴。支持重玩、最佳步数、累计和连续完成、近七天记录。日期变化或重新进入前台会刷新首页；跨日游戏仍归属开始日期。完成记录保留，局面保留最近七个。可选 daily 存档字段兼容之前版本。

- 核心 17 项通过（`daily-core.log`），新增测试覆盖 60 天选题可解与确定性、日期／时区边界、闰日、旧存档、续玩、连续记录、中途重玩、跨日隔离和存储往返。
- iPhone 每日挑战完整流程及原有教学／地图／图鉴回归通过（`daily-ui.log`）。实际操作验证主线第二关放置后进入每日、每日中途冷启动续玩、完成五步解、回到每日查看已完成状态，以及返回主线仍保留原来剩余步数。
- iPhone SE 同样每日全流程通过（`daily-small.log`），截图检查每日开始按钮在首屏可操作，更多记录可滚动浏览。
- Release 模拟器构建通过（`daily-release.log`），交付包 `deliverables/Lightworks-simulator-daily.zip` 的 ZIP 完整性检查通过。
- 实际截图保存于 `verification/previews-daily/`。测试使用独立存档与仅 Debug 可用的固定日期参数，正常应用按真实设备本地日期运行。

每日题目是已有章节关卡的按日轮换，没有在线校时、排行榜或无限新关卡生成。无内购，也没有增加第三方依赖；未改 Bundle ID、签名团队及发布配置。

## 首页关卡与翻页栏间距修复

关卡节点区域改为独立的 94 点高区域，底部通过约束与翻页栏保持 18 点间距；不再将节点和翻页栏同时贴到场景底部。翻页栏宽 248 点，两侧按钮固定为 46 点，中间范围文本保持单行，并增加深色圆角背景提升可读性。

iPhone SE 现有教学／地图／图鉴交互回归通过，实际截图确认关卡序号与左右按钮不重合（`previews-daily/small-city-spacing.png`、`city-spacing-small.log`）。Release 构建通过，`Lightworks-simulator-daily.zip` 已更新。
