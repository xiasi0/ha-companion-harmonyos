# HA Companion For HarmonyOS

[English](README.en.md)

![HA Companion For HarmonyOS](docs/assets/home-assistant-harmonyos-hero.png)

HA Companion For HarmonyOS 是面向 HarmonyOS NEXT 的 Home Assistant Companion 应用实现。项目目标是在鸿蒙原生应用中提供 Home Assistant 登录、仪表盘访问、移动端注册、设备能力同步、原生设置和服务卡片能力。

当前版本为 `0.0.0-dev`，声明支持的设备类型为 `phone` 和 `tablet`。项目仍处于开发阶段，部分能力已经形成可运行主路径，部分平台能力仍需要更多真机验证和产品化打磨。

## 背景与目标

Home Assistant 官方已经在 Android、iOS、Wear OS、watchOS 等平台提供成熟的 Companion App 体验，但 HarmonyOS NEXT 不再兼容 Android 应用，当前鸿蒙 NEXT 用户无法直接获得同等的官方 HA 伴侣能力。这个项目的目标是补齐鸿蒙原生端的体验缺口，逐步达到其它平台 Companion App 的核心能力水平，包括账号登录、Dashboard、移动端注册、传感器同步、通知、定位、服务卡片、Assist 和本地系统能力集成。

鸿蒙生态的设备规模正在扩大。需要区分两个口径：广义 HarmonyOS 生态设备已经是亿级规模，华为在 2024 年 10 月发布 HarmonyOS NEXT 时披露鸿蒙生态设备超过 10 亿；对本项目更直接相关的是 HarmonyOS 5 / HarmonyOS 6 原生鸿蒙终端口径，公开报道显示截至 2026 年 3 月 22 日已突破 5000 万，2026 年 4 月 20 日 HarmonyOS 6 终端设备数突破 5500 万。

受平台资质、开发者主体和分发条件限制，本项目暂不实现 Huawei Push Kit 能力。当前通知相关工作以本地通知、通知权限、通知历史和 Home Assistant 侧能力适配为主。项目也不计划以个人身份上架华为应用市场；后续如需正式分发，应由合适的组织主体完成应用市场资质、隐私合规、Push Kit 和发布流程。

由于 Home Assistant 核心当前没有面向 HarmonyOS 的 OS 平台标签，本项目在 `mobile_app` 注册和相关请求中仍使用 Android 标签作为兼容标识。这是为了复用现有 Home Assistant Companion 协议路径，并不代表应用基于 Android 实现。

## 当前能力

### 服务器与登录

- 支持 Home Assistant 服务器发现和手动输入服务器地址。
- 支持 Home Assistant OAuth 登录流程。
- 支持外部认证回调、授权码换取访问令牌和基础登录错误提示。
- 支持多服务器账号模型，服务器实例、活动服务器和服务器顺序由独立服务管理。
- 支持 Home Assistant `mobile_app` 注册，注册 payload 包含应用版本、设备信息、webhook 信息和设备标识；由于 Home Assistant 暂无 HarmonyOS OS 标签，当前仍使用 Android 标签进行兼容请求。

### Dashboard

- 使用 HarmonyOS WebView 加载 Home Assistant 前端仪表盘。
- 支持向 Home Assistant 前端提供外部认证令牌。
- 支持处理部分 Home Assistant frontend `externalBus` / WebView bridge 消息。
- 支持仪表盘重载、URL 变化、连接状态和不安全连接提示。

### 原生设置

- 提供原生设置页面和设置详情页面。
- 当前设置范围包括服务器、连接策略、安全、传感器、通知、Assist、显示偏好、手势、NFC、服务卡片和应用信息。
- 设置项支持按设备能力进行展示和禁用。
- 支持服务器维度的设置持久化，避免多服务器配置互相覆盖。

### 设备能力

- 支持电池、充电、网络、定位等移动端传感器模型和同步流程。
- 支持准确定位、区域定位、后台定位偏好和位置历史。
- 支持 HarmonyOS 通知权限检查、本地通知测试和通知历史记录。
- 支持系统认证能力接入，用于应用锁相关流程。
- 支持 Assist 文本/语音入口的运行时结构，Assist pipeline 通过 Home Assistant WebSocket 调用。
- 保留 NFC、语音、后台长任务、手表端策略等扩展能力入口，其中部分仍处于占位或实验阶段。

### 服务卡片

- 支持 HarmonyOS FormKit 服务卡片。
- 当前包含灯光、媒体播放器和场景卡片页面。
- 支持卡片绑定 Home Assistant 实体、读取实体状态、缓存媒体封面和刷新卡片数据。
- 支持卡片编辑 Ability 和 Form Extension Ability。

### 国际化和版本

- 支持中文和英文运行时文案。
- 运行时应用版本统一通过 `AppVersionService` 从 HarmonyOS bundle 信息读取。
- 当前应用版本来源为 `AppScope/app.json5` 中的 `versionName` / `versionCode`。

## 使用的 HarmonyOS / OpenHarmony SDK 能力

项目当前使用或预留了以下鸿蒙原生能力：

- `@kit.AbilityKit`
  - `UIAbility`
  - `Want`
  - Ability 生命周期和窗口加载
- `@kit.ArkUI`
  - ArkUI 页面、组件、窗口和布局能力
- `@ohos.web.webview`
  - Home Assistant Dashboard WebView
  - 前端 bridge / URL 拦截 / JavaScript 注入
- `@kit.NetworkKit`
  - HTTP 请求
  - WebSocket
  - mDNS / 本地发现
  - 网络连接和网络能力判断
- `@ohos.data.preferences`
  - 本地偏好设置
  - 多服务器设置持久化
- `@ohos.account.appAccount`
  - 服务器账号实例管理
- HarmonyOS asset / 安全存储相关能力
  - 访问令牌和服务器敏感信息存储
- `@kit.NotificationKit`
  - 通知权限
  - 本地通知
  - 通知历史辅助流程
- `@kit.FormKit`
  - HarmonyOS 服务卡片
  - 卡片数据更新
  - 卡片编辑入口
- `@ohos.geoLocationManager`
  - 定位权限和定位数据
- `@ohos.batteryInfo`
  - 电池和充电状态
- `@ohos.deviceInfo`
  - 设备名称、品牌、型号和系统信息
- `@ohos.multimedia.audio`
  - Assist / 语音相关能力预留
- `@ohos.userIAM.userAuth`
  - 系统认证和应用锁
- `@ohos.resourceschedule.backgroundTaskManager`
  - 后台任务和长连接能力预留
- `@kit.PerformanceAnalysisKit`
  - `hilog` 日志

## 项目结构

```text
HACompanionNext/
├─ AppScope/
│  └─ app.json5
│     应用级配置。bundleName、vendor、versionCode、versionName、图标和名称在这里声明。
│
├─ entry/
│  ├─ build-profile.json5
│  │  entry 模块构建配置。当前包含 release obfuscation 配置。
│  ├─ obfuscation-rules.txt
│  │  ArkTS 混淆规则。
│  └─ src/main/
│     ├─ module.json5
│     │  entry 模块声明。包含设备类型、权限、Ability、Form Extension 和路由资源。
│     ├─ ets/
│     │  ├─ entryability/
│     │  │  主 UIAbility 入口。
│     │  ├─ entrycardeditability/
│     │  │  服务卡片编辑 Ability。
│     │  ├─ entryformability/
│     │  │  服务卡片 Form Extension Ability。
│     │  ├─ pages/
│     │  │  ArkUI 根页面。
│     │  ├─ app/
│     │  │  应用运行时外壳、全局状态、导航、启动协调、WebView 协调和设置协调。
│     │  ├─ features/
│     │  │  面向用户的业务功能模块。
│     │  │
│     │  │  ├─ assist/
│     │  │  │  Assist 会话、入口、运行时和页面。
│     │  │  ├─ auth/
│     │  │  │  登录授权、外部认证和登录 Web 页面。
│     │  │  ├─ background/
│     │  │  │  后台连接和长任务。
│     │  │  ├─ cards/
│     │  │  │  服务卡片绑定、状态存储、实体同步、媒体缓存和卡片刷新。
│     │  │  ├─ dashboard/
│     │  │  │  Home Assistant WebView 仪表盘和前端 bridge。
│     │  │  ├─ discovery/
│     │  │  │  服务器发现运行时。
│     │  │  ├─ location/
│     │  │  │  定位传感器运行时。
│     │  │  ├─ notifications/
│     │  │  │  通知设置、通知历史和通知服务。
│     │  │  ├─ onboarding/
│     │  │  │  首次启动引导、服务器选择、设备命名、连接策略和定位分享页面。
│     │  │  ├─ registration/
│     │  │  │  Home Assistant mobile_app 注册。
│     │  │  ├─ security/
│     │  │  │  应用锁和系统认证流程。
│     │  │  ├─ sensors/
│     │  │  │  传感器目录、设置、运行时和同步协调。
│     │  │  ├─ settings/
│     │  │  │  原生设置页面、设置详情、设置路由、设置组件和设置交互。
│     │  │  └─ wear/
│     │  │     手表端策略和占位入口。当前未在 module.json5 声明 wearable 支持。
│     │  │
│     │  ├─ models/
│     │  │  跨模块共享的数据模型。
│     │  ├─ services/
│     │  │  Home Assistant API、OAuth、网络、存储、服务器账号、设备能力和平台能力封装。
│     │  ├─ shared/
│     │  │  共享 UI 组件、主题、样式、断点、设备能力策略和国际化。
│     │  └─ widget/
│     │     HarmonyOS 服务卡片 UI。
│     │
│     └─ resources/
│        资源文件、图片、路由表、页面表和服务卡片配置。
│
├─ hvigor/
│  Hvigor 构建配置。
├─ build-profile.json5
│  项目级构建配置。仓库版本不应包含本机签名密钥和密码。
├─ oh-package.json5
│  ohpm 工程配置。
├─ oh-package-lock.json5
│  ohpm 锁文件。
└─ code-linter.json5
   DevEco / ArkTS 代码检查配置。
```

## 本地开发指南

### 环境要求

- DevEco Studio 6.0.2 或兼容版本。
- HarmonyOS SDK 6.0.2。
- JDK、Node.js、ohpm、Hvigor 使用 DevEco Studio 自带版本即可。
- 推荐使用真实 HarmonyOS NEXT 手机测试 WebView、定位、通知、后台、服务卡片和系统认证能力。

### 克隆项目

```powershell
git clone https://github.com/xiasi0/ha-companion-harmonyos.git
cd ha-companion-harmonyos
```

### 签名配置

仓库不会提交本机签名证书、profile、keystore 或密码。DevEco Studio 生成的真实签名配置会写入本地 `build-profile.json5`。

推荐流程：

1. 使用 DevEco Studio 打开项目。
2. 进入 `File` -> `Project Structure` -> `Project` -> `Signing Configs`。
3. 使用自动签名或配置自己的调试签名。
4. 确认 `build-profile.json5` 中存在 `signingConfigs`，并且 `products.default` 绑定了 `"signingConfig": "default"`。
5. 本地执行：

```powershell
git update-index --skip-worktree build-profile.json5
```

这样可以保留本机调试签名，同时避免把证书路径和密码提交到仓库。

如果需要修改仓库中的安全空配置，先取消：

```powershell
git update-index --no-skip-worktree build-profile.json5
```

### 构建 HAP

在项目根目录执行：

```powershell
$env:DEVECO_SDK_HOME='D:\DevEco Studio\sdk'
& 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --no-daemon --mode module -p module=entry assembleHap
```

构建输出通常位于：

```text
entry/build/default/outputs/default/
```

如果签名配置正确，会生成：

```text
entry-default-signed.hap
```

### 安装到真机

连接设备后查看设备 ID：

```powershell
& 'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' list targets
```

安装：

```powershell
& 'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' -t <device-id> install -r entry\build\default\outputs\default\entry-default-signed.hap
```

### 常见本地产物

以下目录是本地产物或 IDE 状态，不需要提交：

```text
.hvigor/
.idea/
entry/build/
```

`build-profile.json5` 本地可能包含签名配置。提交前必须确认没有把本机签名路径和密码加入暂存区。

### 提交前检查

```powershell
git status --porcelain=v1 -uall
git diff --check
git ls-files -v build-profile.json5
```

如果 `build-profile.json5` 前缀是 `S`，说明本地 skip-worktree 生效。

## 版本管理

应用安装包版本以 `AppScope/app.json5` 为准：

```json5
"versionCode": 1,
"versionName": "0.0.0-dev"
```

运行时通过 `AppVersionService` 读取 HarmonyOS bundle 信息。设置页、Home Assistant mobile_app 注册和 WebView bridge 都应使用该服务，不应在业务代码中硬编码版本号。

`entry/oh-package.json5` 中的 `version` 是 ohpm 模块版本，不作为应用安装包版本来源。

## 当前状态和限制

- 当前项目尚未声明生产稳定。
- 当前声明支持的设备类型为 `phone` 和 `tablet`，两者共用同一套自适应运行时外壳和栈式原生设置 UI。
- Wearable 相关代码仅保留策略和占位入口，当前不接入发布目标。
- 车机场景当前不作为独立设备类型声明；后续如接入，应基于连接状态和 HarmonyOS / Car Kit 支持能力扩展，而不是声明独立座舱应用目标。
- Push Kit 暂不接入；涉及远程推送的能力需要等合适的主体资质、应用市场分发条件和平台服务配置明确后再评估。
- 项目不计划以个人身份上架华为应用市场，当前更适合作为开源实现、开发构建和真机验证项目。
- NFC、语音、后台任务、通知、定位、服务卡片等平台能力需要更多真机覆盖。
- release 混淆已开启，但涉及 Home Assistant 外部协议字段时需要持续维护 keep 规则，避免破坏 wire format。
- HarmonyOS NEXT 平台和 SDK 仍在演进，部分 API 行为可能随版本变化。

## 许可证

Apache License 2.0，详见 [LICENSE](LICENSE)。
