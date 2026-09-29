# Freelance Hub · 比赛演示清单（学生赛道）

> 适用：比赛期间不正式上架 Google Play，以 **debug 构建 + 离线演示** 为主。
> 上架相关事项（Play 账号 / 订阅产品 / RC 配置）见 `LAUNCH_CHECKLIST.md`，比赛后执行。
> 最后更新：2026-09-20

---

## 一、必须用 debug 构建（不是 release，也不是 profile）

| 构建类型 | Demo 预置数据 | 付费墙演示开关 | 结论 |
|---|---|---|---|
| **debug** | ✅ 有 | ✅ 有 | **✅ 演示用这个** |
| profile | ✅ 有 | ❌ 无（`kDebugMode=false`） | ✗ 付费功能演示不了 |
| release | ❌ 无（`ENV=prod` 禁播） | ❌ 无 | ✗ 界面全空 |

原因（代码事实）：
- `mobile/lib/app.dart:77` — `if (AppConfig.isDev)` 才播种 demo 数据；release 构建 `ENV=prod`，新用户打开是空界面
- `mobile/lib/screens/premium_screen.dart:131` — `if (kDebugMode)` 才显示 DEMO CONTROLS（Free/Monthly/Annual 切换）

> 好消息：上架要求的"生产禁播 demo 数据"与比赛要求的"有 demo 数据"已通过 `ENV` 隔离，两者不冲突，**不需要改代码**。

---

## 二、构建与安装

### 方式 A：直接用现成脚本
```
mobile\update_phone.bat
```
（= `flutter build apk --debug` + adb install 到 `192.168.1.101:5555`，改 IP 即可）

### 方式 B：手动
```bash
cd mobile
flutter build apk --debug
```
产物：`mobile\build\app\outputs\flutter-apk\app-debug.apk`

> ⚠️ 不要加 `--dart-define=ENV=prod`，否则 demo 数据消失。
> ✅ 可以加 `--dart-define=API_BASE_URL=<地址>`（不影响 demo 数据，见第三节）。

### 界面干净度
`debugShowCheckedModeBanner: false` 已在 `app.dart` 设置 —— **右上角无 DEBUG 水印**，可直接录屏/截图。

---

## 三、真机演示登录：必须先确认 API 地址

> **登录 / 注册 / 云同步功能已完整实现**（后端 `authController` 全套 + 移动端 `ApiService`/`AuthProvider`），并非不能用。
> 需要处理的只是**默认地址指向模拟器**这一点。

debug 构建不传 `--dart-define` 时，API 地址是默认值：

```
AppConfig.apiBaseUrl = http://10.0.2.2:3001/api/v1
```

`10.0.2.2` 是 **Android 模拟器访问宿主机的专用回环地址**。真机上这个 IP 并不是你的电脑，请求发到不存在的地址 → 登录失败。**只要把地址指对，登录注册同步全部正常。**

### 已验证可用的做法（真机联调实际使用）

```bash
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.3:3001/api/v1
```

笔记本跑后端（`cd backend && npm start`，端口 3001）+ 真机连同一局域网 —— **登录/注册/云同步均已真机实测通过**。

| 场景 | 做法 |
|---|---|
| **真机 + 本地后端**（比赛现场推荐） | 注入宿主机**局域网 IP**（如 `http://192.168.1.3:3001/api/v1`）；后端连的是 MongoDB Atlas，笔记本能上网即可 |
| **真机 + 公网后端** | 注入 `https://<后端域名>/api/v1`，最接近上线形态 |
| **模拟器** | 不传参数，默认 `10.0.2.2` 即正确 |

### 关于 HTTP 明文（以实测为准）

项目未配置 `usesCleartextTraffic`，按 Android 规范 targetSdk ≥ 28 默认禁明文，**但真机实测局域网 HTTP 可正常通信**（项目全程真机测试通过）。规范推断让位于实测结论。

若**换设备**后出现 `Cleartext traffic not permitted`，在 `android/app/src/debug/AndroidManifest.xml` 的 `<application>` 上加一行即可（只影响 debug，不影响 release）：

```xml
<application android:usesCleartextTraffic="true" ... />
```

### 现场兜底：游客模式

若现场无网、后端没起来或局域网 IP 变了，启动后点 **「Continue without account」** 进入游客模式，全程离线可用（Hive 本地库），核心功能照常演示。

> ⚠️ 现场注意：局域网 IP 可能因 DHCP 变化，演示前先 `ipconfig` 确认，并确保后端已启动。

### 演示脚本（约 60 秒走查）

| 步骤 | 操作 | 展示卖点 |
|---|---|---|
| 1 | 登录页 → Continue without account | 无需注册即可用，隐私友好 |
| 2 | 仪表盘 | 本月工时 / 收入 / 开支三卡 + 最近记录（预置数据） |
| 3 | 计时 Tab → 选项目 → Start | 实时计时 + 常驻通知；暂停/继续/停止保存 |
| 4 | 开支 Tab → 新增一笔 → 选类目 → 打收据照片 | 可抵扣税标记、自定义类目 |
| 5 | 报表 Tab → 月报 | 收入趋势折线、类目饼图、项目工时柱状图；导出 PDF |
| 6 | 设置 → Premium → 年付 → 用底部 **DEMO CONTROLS** 切 Annual | 解锁年报 + 云同步 + Web 看板 |
| 7 | 报表 → 年报 | 自雇税估算（Schedule SE）+ 季度预缴税（1040-ES） |

### 加分项：完整账号链路（现场有网时演示）

在局域网后端可用的前提下，可完整演示（dev 后端 `DEMO_ANNUAL_BY_DEFAULT=true`，注册即 Annual，云同步免配置）：

1. 注册新账号 → 收到验证邮件（SMTP2GO 已配，发件 `no-reply@ddntqts.cn`）
2. 登录 → 设置 → Cloud Sync → 手动同步
3. 打开 Web 看板（另一台设备/电脑浏览器）查看同步过来的项目与工时
4. 设置 → 删除账号（输入 DELETE + 密码）→ 演示 GDPR 30 天宽限期机制

> 无法演示的仅 **Google Play 真实支付**（需上架后才能测），付费权益用 DEMO CONTROLS 演示。

### 预置数据（debug 首次启动自动播种）
3 个项目（Acme / StartupXYZ / Digital Agency）+ 12 条工时 + 4 笔可抵扣开支
→ 总工时 **41.5h**、总收入 **$2110.00**、总开支 **$219.97**

> 重装或清除应用数据后才会重新播种（`demo_seeded` 标记）。演示前若发现无数据：**卸载重装**即可。

---

## 四、如果评审一定要看"多端同步"

需要先让后端在线，再注入 HTTPS 地址构建：

```bash
# 1. 先确认后端可达（海外网络实测，国内直连 onrender.com 常被干扰）
curl https://freelance-hub-api-f2gn.onrender.com/api/v1/health

# 2. 注入真实地址构建 debug（保留 demo 数据与付费墙开关）
cd mobile
flutter build apk --debug ^
  --dart-define=ENV=dev ^
  --dart-define=API_BASE_URL=https://freelance-hub-api-f2gn.onrender.com/api/v1
```

演示链路：注册账号 → 仪表盘 → 设置 → Cloud Sync → Web 看板（Annual 才解锁）
> dev 后端 `.env` 的 `DEMO_ANNUAL_BY_DEFAULT=true`，注册即 Annual，同步演示免配置。

**建议**：把离线演示作为主方案，同步作为加分项备用 —— 现场网络不可控，别把核心演示押在后端上。

---

## 五、已知限制（被问到时如实说明）

| 限制 | 说明 |
|---|---|
| 真机默认地址连不上后端 | debug 默认指向模拟器回环 `10.0.2.2`；**注入真实地址即可正常登录**（见第三节）。生产强制 HTTPS 是刻意设计，见 `main.dart` 的 `_MisconfiguredApp` 兜底 |
| 购买流程无法真实走通 | RevenueCat SDK key 未注入（`build_release_aab.ps1` 已 fail-fast 防误出包）；付费功能用 DEMO CONTROLS 演示 |
| 云同步需 Annual | 产品权益设计，demo 环境下可用 DEMO CONTROLS 解锁 |
| 自雇税为估算值 | 页面已带免责声明，遵循 IRS Schedule SE / 1040-ES 简化算法 |

---

## 六、录屏 / 截图建议

1. 卸载重装 App → 得到完整预置数据
2. 关闭手机「省电模式」，避免后台计时被冻结影响演示
3. 通知权限在首次启动时已自动申请（Android 13+），**允许** 以展示常驻计时通知
4. 竖屏 1080×1920 录屏；截图可直接复用为后续上架素材（Play 要求 3 张+）

---

## 七、比赛后恢复上架时

按 `LAUNCH_CHECKLIST.md` 执行；本轮代码审查的修复（`Google_Play_上架代码审查报告.md`）全部保留有效，无需返工。
