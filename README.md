

> **本项目由AI生成**

# 倒计时App

一个纯本地运行的个人倒计时 App：**无登录、无网络、无广告、数据全部保存在本机**。  
基于 Flutter 实现，支持直接打包 Android APK。

完整变更历史见 [CHANGELOG.md](CHANGELOG.md)。

## 功能总览

### Tab1 · 倒计时任务

- 输入目标时长（时 / 分 / 秒），点击【开始】启动倒计时。
- **任务标签**：可选一级标签（学习 / 工作 / 健身 / 休息 / 其他），选中后可填二级自定义标签（如「数学」），统计面板会按「学习·数学」聚合。
- 大号数字实时显示剩余时间。
- 暂停 / 继续：**每个任务周期最多暂停 3 次**，用完后「暂停」按钮置灰不可点；界面显示「剩余暂停次数」。
- 提供【开始】【暂停】【停止】按钮，以及【重置】按钮（清空当前任务）。
- 点击【停止】弹出三选项弹窗：
  - **放弃当前任务**：丢弃本次计时，不保存，回到初始状态。
  - **提前完成任务**：将实际有效时长保存到本地数据库，结束任务。
  - **取消**：关闭弹窗，继续计时。
- 倒计时跑完：触发**震动提醒**，自动保存有效时长。
- **有效时长规则**：扣除暂停时间；开始后 30 秒以内终止不计入统计。
- **进行中任务持久化**：计时状态（时长、标签、截止时刻、暂停次数）实时落库，App 被系统杀掉或重启后自动恢复未完成任务，已过期的自动补记完成。

### Tab2 · 数据统计

- 展示全部历史倒计时记录列表（每条：任务时间 + 标签 + 实际有效计时时长）。
- 四种时间筛选：**今日 / 本周 / 本月 / 自定义时间范围**。
- 顶部卡片展示筛选后的**总有效时长**与记录数。
- **分类统计**：按「一级标签·二级标签」聚合各标签的有效时长（如「学习·数学 5 小时」）。
- 每条记录提供**再来一次**按钮：一键用相同时长与标签回倒计时页重新开始。
- 数据用 SQLite 持久化，**App 关闭重启后不丢失**。

## 技术说明

- **计时精度**：基于系统时间戳差值（记录「截止时间点」，剩余时长实时用 `截止时间 - 当前时间` 计算），  
  不通过变量累加，避免卡顿 / 切后台造成的漂移。
- **依赖极简**（尽量内置组件）：
  - `sqflite` —— 本地 SQLite 数据库（本地持久化的标准做法，无内置替代）。
  - `vibration` —— 倒计时结束震动提醒（对应 `VIBRATE` 权限）。
  - `flutter_localizations` —— SDK 内置，仅用于日期选择器等系统组件显示中文。
  - 其余（日期选择、深浅色主题、导航、按钮等）全部使用 Flutter 内置组件。
- **权限**：仅声明 `android.permission.VIBRATE`，无网络、无存储、无定位等权限。
- **进行中任务持久化**：把「进行中」任务（时长、标签、截止时刻、暂停次数）实时写入数据库，启动时读回恢复，避免进程被杀导致任务丢失。
- **深色模式**：自动跟随系统（`ThemeMode.system`）。
- 注：**安卓切后台后计时可能被系统暂停**，建议保持前台运行。

## 目录结构

```
countdown_timer_app/
├── lib/
│   ├── main.dart                     # 入口 + 主题/本地化
│   ├── models/timer_record.dart      # 记录模型
│   ├── services/
│   │   ├── database_service.dart     # SQLite 持久化
│   │   └── timer_controller.dart     # 倒计时状态机（时间戳计时）
│   ├── screens/
│   │   ├── home_screen.dart          # 双 Tab 容器
│   │   ├── timer_tab.dart            # 倒计时任务页
│   │   └── stats_tab.dart            # 数据统计面板
│   └── utils/formatters.dart         # 时间格式化
├── android/                          # Android 平台配置（已含 VIBRATE 权限 + 图标 + Gradle Wrapper）
├── .github/workflows/build-apk.yml   # 云端打包 APK
└── pubspec.yaml
```

## 本地运行

前置：安装 [Flutter SDK](https://flutter.dev/docs/get-started/install)（建议 3.19+，本项目按 3.22 配置）。

```bash
cd countdown_timer_app
flutter pub get
flutter run          # 连接真机或模拟器运行
```

## 打包 APK

```bash
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

> 个人自用已默认使用 debug 签名，可直接安装。如需正式签名，请参考  
> <https://docs.flutter.dev/deployment/android#signing-the-app> 配置密钥库后重打包。

## 云端打包 APK

项目已内置 GitHub Actions 工作流（`.github/workflows/build-apk.yml`）：

1. 把本目录推送到 GitHub 仓库；
2. 打开仓库 **Actions** 页，手动触发 `Build Android APK`；
3. 构建完成后在产物（Artifacts）中下载 `countdown-timer-apk`（即 `app-release.apk`）。

## 版本兼容说明

- Android 平台文件按 **Flutter 3.22 / AGP 8.1 / Kotlin 1.8.22 / Gradle 8.3** 配置。
- 若你本机 Flutter 版本差异较大（如 3.24+ 或更旧的 3.13 以下），建议在项目根目录执行  
  `flutter create --platforms=android .` 重新生成平台脚手架，再按需把 `android/app/src/main/AndroidManifest.xml`  
  中的 `VIBRATE` 权限补上即可，`lib/` 业务代码无需改动。
