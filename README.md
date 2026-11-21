# UfiPeek 桌面小组件（iOS + Android 原生版）

参考 UfiPeek v3.0 脚本，做成独立 App：装好后直接把小组件放到手机桌面，不需要再装脚本类 App。

取数流程和原脚本完全一样：

1. `GET /api/baseDeviceInfo` → 型号、版本、温度、CPU、电量、今日/本月流量
2. `POST /api/user_shell` 调设备本机 `zreq` 自动登录 ZTE 后台，读 goform（运营商、网络、信号、SSID、短信、连接数、频段…）
3. zreq 失败时回退：直接 `GET goform`，`loginfo=no` 时再 POST 登录
4. `POST /api/root_shell` 读 WiFi 频率（5G/2.4G）和内存占用
5. 所有请求带 UFI-TOOLS 的 `Authorization / kano-t / kano-sign` 签名（已和原脚本逐字节对过结果）

设置项也一样三个：**后台地址**、**UFI 密码**、**ZTE 密码（可空）**。

后台地址默认填入 `http://192.168.88.1:2333`，已保存的自定义地址优先。若能显示流量和电量，但蜂窝信号或 Wi-Fi 信息显示为 `--`，可在设置页点「测试连接」查看未读到的项目。Wi-Fi 的「5 GHz」表示无线频率。

## 小组件

| 平台 | 尺寸 | 内容 |
|---|---|---|
| iOS | 中号 | 完整复刻原版：顶栏（型号/版本/信号/电量）、今日/本月流量、两行状态胶囊、RSRP/RSRQ/SNR + 刷新时间 |
| iOS | 小号 | 型号、电量、今日流量大数字、本月流量、网络 |
| iOS | 锁屏矩形 | 今日 / 本月流量 + 电量 |
| Android | 中号 4×2 | 同 iOS 中号；Android 12+ 压扁时自动隐藏 WiFi 那一行 |
| Android | 小号 2×2 | 同 iOS 小号 |

- **点一下小组件 = 立即刷新**（iOS 17 交互小组件 / Android 广播）
- 自动刷新约 15 分钟一次（iOS 由系统调度，Android 用 JobScheduler）
- 刷新失败时保留上次数据，底栏显示红色错误提示
- 跟随系统深色模式

## 怎么得到 IPA 和 APK

本机没有 Mac 也可以，全部在 GitHub Actions 上打包：

1. 在 GitHub 新建一个仓库（私有也行），把本文件夹里的所有内容推上去（包括 `.github` 文件夹）。
2. 推送到 `main` 分支后自动开始构建；也可以在仓库的 **Actions → Build IPA & APK → Run workflow** 手动触发。
3. 大约 5–10 分钟后，在仓库的 **Releases → latest** 里下载：
   - `UfiPeek.apk`：Android 直接安装
   - `UfiPeek-unsigned.ipa`：iOS 未签名包

## iOS 安装注意

- 需要 **iOS 17 及以上**。
- IPA 未签名，用你平时的证书 / 签名工具签名后安装（小组件扩展在 `PlugIns/UfiPeekWidget.appex`，签名工具一般会一起重签）。
- 打开 App → 填地址密码 → 点「测试连接」。第一次会弹「允许查找本地网络设备」，请点允许，否则局域网地址连不上。
- 然后点「保存并刷新小组件」，回桌面长按 → 左上角 `+` → 搜 UfiPeek 添加。
- **如果小组件提示「长按 → 编辑小组件，填写后台地址」**：说明重签后 App Group 失效了，App 和小组件不能共享设置。直接长按小组件 →「编辑小组件」，在里面填地址和密码即可，效果一样。

## Android 安装注意

- 需要 Android 8.0 及以上。APK 用仓库里固定的 `android/app/ufipeek.jks` 签名，以后更新可以直接覆盖安装。
- 打开 UfiPeek → 填设置 → 测试连接（下方会直接显示小组件预览）→ 保存并刷新。
- 桌面长按空白处 → 小组件 → UfiPeek。
- 点小组件顶部型号那一行可以回到设置页。
- 小米 / 华为 / OPPO / vivo 等系统请把 UfiPeek 的电池策略改成「无限制」，否则后台自动刷新可能被拦。

## 目录

```
ios/            XcodeGen 工程（project.yml），App + WidgetKit 扩展
  Shared/       取数逻辑 UfiClient.swift、小组件视图 WidgetViews.swift（App 预览和小组件共用）
  Widget/       小组件入口、配置 Intent、刷新 Intent
  App/          设置页 + 测试连接 + 预览
android/        Gradle 工程，纯 Kotlin，无第三方依赖
tools/          图标与小组件布局生成脚本（改了图标/布局后运行 python3 tools/gen_android.py）
.github/        自动打包 IPA / APK 并发布到 Release
```

## 与原版的差异

- 原版用的阿里健康体 / 玄冬楷书字体没有打包进来，改用系统圆体（iOS）/ 系统字体（Android）。
- Android 端图标是重新绘制的矢量图标，iOS 端用 SF Symbols（和原版同名或相近）。
- 刷新时间显示为 `月-日 时:分`，省一点宽度。
