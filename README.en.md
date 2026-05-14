# HA Companion For HarmonyOS

[中文](README.md)

![HA Companion For HarmonyOS](docs/assets/home-assistant-harmonyos-hero.png)

HA Companion For HarmonyOS is a Home Assistant Companion implementation for HarmonyOS NEXT. The project aims to provide Home Assistant authentication, dashboard access, mobile_app registration, device capability sync, native settings, and HarmonyOS service cards in a native HarmonyOS app.

The current version is `0.0.0-dev` and the declared target device types are `phone` and `tablet`. The project is still under active development: several core paths are runnable, while some platform capabilities still need more real-device validation and production hardening.

## Project Context And Goals

The official Home Assistant project already provides mature Companion App experiences on Android, iOS, Wear OS, watchOS, and other platforms. HarmonyOS NEXT no longer runs Android applications, so HarmonyOS NEXT users cannot directly use the same official HA companion experience today. This project aims to close that native HarmonyOS gap and gradually reach the same core capability level as the companion apps on other platforms, including account login, Dashboard access, mobile_app registration, sensor sync, notifications, location, service cards, Assist, and local system integrations.

The HarmonyOS device base is growing, but there are two different metrics to keep separate. The broader HarmonyOS ecosystem is already at billion-device scale: Huawei stated at the HarmonyOS NEXT launch in October 2024 that the HarmonyOS ecosystem had passed 1 billion devices. The more relevant metric for this project is the HarmonyOS 5 / HarmonyOS 6 native HarmonyOS terminal base: public reports stated that HarmonyOS 5 / HarmonyOS 6 terminals passed 50 million on March 22, 2026, and that HarmonyOS 6 terminals passed 55 million on April 20, 2026.

Because of platform qualification, developer-entity, and distribution requirements, this project does not currently implement Huawei Push Kit. Notification work currently focuses on local notifications, notification permission handling, notification history, and Home Assistant-side integration. The project also does not plan to publish to Huawei AppGallery under an individual developer account. If formal distribution is needed later, it should be handled by an appropriate organization that can complete AppGallery qualification, privacy compliance, Push Kit setup, and release operations.

Because Home Assistant Core does not currently define a HarmonyOS OS platform label, this project still uses the Android label in `mobile_app` registration and related requests for compatibility. This reuses the existing Home Assistant Companion protocol path and does not mean the app is implemented on Android.

## Current Capabilities

### Server And Authentication

- Home Assistant server discovery and manual server URL setup.
- Home Assistant OAuth login flow.
- External authentication callback handling, authorization-code token exchange, and login error reporting.
- Multi-server account model with active server and server ordering.
- Home Assistant `mobile_app` registration with app version, device information, webhook data, and device identity; because Home Assistant does not yet provide a HarmonyOS OS label, registration currently uses the Android label for compatibility.

### Dashboard

- Home Assistant frontend dashboard loaded through HarmonyOS WebView.
- External auth token injection for the Home Assistant frontend.
- Partial Home Assistant frontend `externalBus` / WebView bridge handling.
- Dashboard reload, URL-change handling, connection state, and insecure-connection blocking UI.

### Native Settings

- Native settings home and detail pages.
- Settings for server account, connection policy, security, sensors, notifications, Assist, display preferences, gestures, NFC, service cards, and app information.
- Capability-aware settings display.
- Server-scoped settings persistence so multiple servers do not overwrite each other.

### Device Capabilities

- Mobile sensor models for battery, charging, network, and location.
- Accurate location, zone-only location, background location preference, and location history.
- Notification permission checks, local notification test, and notification history support.
- System authentication integration for app-lock flows.
- Assist runtime structure for text and voice entry points. Assist pipeline calls use the Home Assistant WebSocket API.
- Reserved or experimental entries for NFC, speech, background tasks, and wearable policy.

### Service Cards

- HarmonyOS FormKit service cards.
- Current card pages include light, media player, and scene cards.
- Entity binding, Home Assistant state loading, media cover cache, and card refresh support.
- Card edit Ability and Form Extension Ability.

### Localization And Versioning

- Runtime Chinese and English strings.
- App version access is centralized through `AppVersionService`.
- The application version source is `AppScope/app.json5` (`versionName` / `versionCode`).

## HarmonyOS / OpenHarmony SDK Usage

The project currently uses or reserves these native HarmonyOS capabilities:

- `@kit.AbilityKit`
  - `UIAbility`
  - `Want`
  - Ability lifecycle and window loading
- `@kit.ArkUI`
  - ArkUI pages, components, layout, and window APIs
- `@ohos.web.webview`
  - Dashboard WebView
  - Frontend bridge / URL interception / JavaScript injection
- `@kit.NetworkKit`
  - HTTP
  - WebSocket
  - mDNS / local discovery
  - Network connection and capability detection
- `@ohos.data.preferences`
  - Local preferences
  - Server-scoped settings persistence
- `@ohos.account.appAccount`
  - Server account instance management
- HarmonyOS asset / secure storage related APIs
  - Access token and sensitive server data storage
- `@kit.NotificationKit`
  - Notification permission
  - Local notifications
  - Notification history support
- `@kit.FormKit`
  - Service cards
  - Form updates
  - Card edit entry
- `@ohos.geoLocationManager`
  - Location permission and location data
- `@ohos.batteryInfo`
  - Battery and charging state
- `@ohos.deviceInfo`
  - Device name, brand, model, and OS information
- `@ohos.multimedia.audio`
  - Reserved Assist / speech-related capabilities
- `@ohos.userIAM.userAuth`
  - System authentication and app lock
- `@ohos.resourceschedule.backgroundTaskManager`
  - Reserved background task and long-running connection capabilities
- `@kit.PerformanceAnalysisKit`
  - `hilog` logging

## Project Structure

```text
HACompanionNext/
├─ AppScope/
│  └─ app.json5
│     App-level configuration: bundleName, vendor, versionCode, versionName, icon, and label.
│
├─ entry/
│  ├─ build-profile.json5
│  │  Entry module build configuration, including release obfuscation settings.
│  ├─ obfuscation-rules.txt
│  │  ArkTS obfuscation rules.
│  └─ src/main/
│     ├─ module.json5
│     │  Entry module declaration: device type, permissions, abilities, form extension, and route resources.
│     ├─ ets/
│     │  ├─ entryability/
│     │  │  Main UIAbility entry.
│     │  ├─ entrycardeditability/
│     │  │  Service card edit Ability.
│     │  ├─ entryformability/
│     │  │  Service card Form Extension Ability.
│     │  ├─ pages/
│     │  │  ArkUI root page.
│     │  ├─ app/
│     │  │  App runtime shell, global state, navigation, startup, WebView coordination, and settings coordination.
│     │  ├─ features/
│     │  │  User-facing feature modules.
│     │  │
│     │  │  ├─ assist/
│     │  │  │  Assist conversation, entry points, runtime, and pages.
│     │  │  ├─ auth/
│     │  │  │  OAuth login, external auth, and login WebView page.
│     │  │  ├─ background/
│     │  │  │  Background connection and long-running tasks.
│     │  │  ├─ cards/
│     │  │  │  Card binding, state storage, entity sync, media cache, and card refresh.
│     │  │  ├─ dashboard/
│     │  │  │  Home Assistant WebView dashboard and frontend bridge.
│     │  │  ├─ discovery/
│     │  │  │  Server discovery runtime.
│     │  │  ├─ location/
│     │  │  │  Location sensor runtime.
│     │  │  ├─ notifications/
│     │  │  │  Notification settings, notification history, and notification service.
│     │  │  ├─ onboarding/
│     │  │  │  First-run onboarding, server selection, device naming, connection policy, and location sharing.
│     │  │  ├─ registration/
│     │  │  │  Home Assistant mobile_app registration.
│     │  │  ├─ security/
│     │  │  │  App lock and system authentication flows.
│     │  │  ├─ sensors/
│     │  │  │  Sensor catalog, settings, runtime, and sync coordination.
│     │  │  ├─ settings/
│     │  │  │  Native settings pages, routes, components, and interactions.
│     │  │  └─ wear/
│     │  │     Wearable policy and placeholder entry. Wearable is not declared in module.json5 for now.
│     │  │
│     │  ├─ models/
│     │  │  Shared data models.
│     │  ├─ services/
│     │  │  Home Assistant API, OAuth, network, storage, server account, device capability, and platform services.
│     │  ├─ shared/
│     │  │  Shared UI components, theme, style, breakpoints, device capability policy, and localization.
│     │  └─ widget/
│     │     HarmonyOS service card UI.
│     │
│     └─ resources/
│        Resources, images, route maps, page maps, and form configuration.
│
├─ hvigor/
│  Hvigor build configuration.
├─ build-profile.json5
│  Project-level build configuration. The repository copy should not contain local signing secrets.
├─ oh-package.json5
│  ohpm project configuration.
├─ oh-package-lock.json5
│  ohpm lockfile.
└─ code-linter.json5
   DevEco / ArkTS lint configuration.
```

## Local Development

### Requirements

- DevEco Studio 6.0.2 or a compatible version.
- HarmonyOS SDK 6.0.2.
- JDK, Node.js, ohpm, and Hvigor from DevEco Studio.
- A real HarmonyOS NEXT phone is recommended for WebView, location, notification, background, service card, and system authentication testing.

### Clone

```powershell
git clone https://github.com/xiasi0/ha-companion-harmonyos.git
cd ha-companion-harmonyos
```

### Signing

The repository does not include local signing certificates, profiles, keystores, or passwords. DevEco Studio writes real local signing material into `build-profile.json5`.

Recommended flow:

1. Open the project in DevEco Studio.
2. Go to `File` -> `Project Structure` -> `Project` -> `Signing Configs`.
3. Use automatic signing or configure your own debug signing material.
4. Confirm `build-profile.json5` has `signingConfigs` and that `products.default` is bound to `"signingConfig": "default"`.
5. Run:

```powershell
git update-index --skip-worktree build-profile.json5
```

This keeps local debug signing available while preventing certificate paths and passwords from being committed.

If you need to edit the repository-safe empty configuration:

```powershell
git update-index --no-skip-worktree build-profile.json5
```

### Build

From the project root:

```powershell
$env:DEVECO_SDK_HOME='D:\DevEco Studio\sdk'
& 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --no-daemon --mode module -p module=entry assembleHap
```

Build outputs are usually written to:

```text
entry/build/default/outputs/default/
```

With valid signing configuration, the installable package is:

```text
entry-default-signed.hap
```

### Install On Device

List connected devices:

```powershell
& 'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' list targets
```

Install:

```powershell
& 'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' -t <device-id> install -r entry\build\default\outputs\default\entry-default-signed.hap
```

### Local Artifacts

These directories are local build or IDE state and should not be committed:

```text
.hvigor/
.idea/
entry/build/
```

Local `build-profile.json5` may contain signing configuration. Always check that signing secrets are not staged before committing.

### Before Commit

```powershell
git status --porcelain=v1 -uall
git diff --check
git ls-files -v build-profile.json5
```

If `build-profile.json5` starts with `S`, local skip-worktree is enabled.

## Versioning

The app package version is defined in `AppScope/app.json5`:

```json5
"versionCode": 1,
"versionName": "0.0.0-dev"
```

Runtime code reads the bundled HarmonyOS version through `AppVersionService`. Settings, Home Assistant mobile_app registration, and WebView bridge responses should use this service instead of hardcoded version strings.

`entry/oh-package.json5` contains the ohpm module version and is not the app package version source.

## Status And Limitations

- The project is not production-stable yet.
- Declared device types are `phone` and `tablet`; both use the same adaptive runtime shell and stack-based native settings UI.
- Wearable code is currently policy and placeholder code only; wearable support is not declared in `module.json5`.
- Car-related support is not declared as a standalone device type. Future car integration should be based on connection state and supported HarmonyOS/Car Kit capabilities rather than a dedicated cockpit app target.
- Push Kit is not integrated for now; remote push features should be revisited only after the required entity qualification, AppGallery distribution path, and platform service configuration are clear.
- The project does not plan to publish to Huawei AppGallery under an individual developer account; it is currently better treated as an open-source implementation, development build, and real-device validation project.
- NFC, speech, background tasks, notifications, location, and service cards need more real-device coverage.
- Release obfuscation is enabled, but keep rules for external Home Assistant protocol fields must be maintained carefully to avoid breaking wire formats.
- HarmonyOS NEXT and its SDK are still evolving, so API behavior may change between versions.

## License

Apache License 2.0. See [LICENSE](LICENSE).
