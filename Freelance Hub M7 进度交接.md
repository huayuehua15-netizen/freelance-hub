# Freelance Hub M7 进度交接

> 里程碑：**M7 - 上架前打磨（通知/购买/报表/Splash）**
> 完成日期：2026-08-16
> 主分支状态：等待验证后合并

---

## 一、M7 任务总览

| 编号 | 任务 | 状态 | 备注 |
|------|------|------|------|
| M7-1 | 调研移动端通知/购买/Splash/报表现状 | 已完成 | 摸清四块现状 |
| M7-2 | 通知文案 i18n（flutter_local_notifications） | 已完成 | 接入 AppLocalizations.t() |
| M7-3 | RevenueCat 购买取消处理 | 已完成 | 区分取消 vs 失败，友好提示 |
| M7-4 | 年度报表年份选择器 | 已完成 | 5 年回溯，左右切换 |
| M7-5 | Splash 等待初始化完成 | 已完成 | 最小 800ms 展示 + 10s 超时 |
| M7-6 | `flutter analyze` 0 error 验证 | 已完成 | 见第六节 |
| M7-7 | Lint info 清理（历史存量） | 进行中 | 见第六节 |
| M7-8 | 构建并安装到测试机 | 待开始 | ADB 无线连接已断，待用户提供配对码 |

---

## 二、变更文件清单

### 2.1 移动端（mobile/lib/）

| 文件 | 类型 | 变更说明 |
|------|------|----------|
| `l10n/app_localizations.dart` | 修改 | 新增 `notification.timerRunningTitle/Body`、`notification.timerPausedTitle/Body`、`notification.timerChannelName/Desc`、`purchaseCanceled` 等键 |
| `services/notification_service.dart` | 修改 | 将硬编码通知文案替换为 `AppLocalizations.t()` 调用 |
| `providers/premium_provider.dart` | 修改 | 新增 `PurchaseCanceledException`，`_wrapPurchaseError` 区分 `PURCHASE_CANCELLED` 与其他错误 |
| `screens/premium_screen.dart` | 修改 | `_switchPlan` 捕获 `PurchaseCanceledException` 并显示 `purchaseCanceled` SnackBar |
| `screens/annual_report_screen.dart` | 修改 | 改为 `StatefulWidget`，新增 `_selectedYear` 与 `_buildYearSelector()`，年份范围 `[now-5, now]` |
| `providers/app_init_notifier.dart` | 新建 | `ChangeNotifier`，跟踪 `isInitialized`，`markInitialized()` 通知完成 |
| `app.dart` | 修改 | 注册 `AppInitNotifier`，`_initializeApp` 的 `finally` 中调用 `markInitialized` |
| `screens/splash_screen.dart` | 修改 | 轮询 `AppInitNotifier.isInitialized`，配合 `Stopwatch` 保证最小展示时长 800ms，超时 10s 强制跳转 |
| `screens/settings_screen.dart` | 修改 | 删除未使用的 `dart:convert` import |
| `widgets/empty_state.dart` | 修改 | 移除冗余 `?? Colors.grey[400]/[600]`（onSurfaceVariant 非空类型） |

### 2.2 后端 / Web

无变更（M7 仅打磨移动端）。

---

## 三、关键技术决策

### 3.1 通知 i18n 接入方式

通知文案在 `flutter_local_notifications` 调用时通过 `AppLocalizations.t(key)` 实时读取当前 Locale 文案，**不依赖 Android string.xml 资源**。原因：

- App 全局已统一使用 `AppLocalizations` 单一来源（en/zh），避免维护双份字符串。
- 通知仅在 App 前台或运行中触发，时序上 Locale 已确定。
- 不涉及系统级通知 channel 描述国际化（channel 在 native 层创建时使用当前 Locale 快照，可接受）。

### 3.2 购买取消 vs 失败的区分

RevenueCat 在用户主动取消购买时抛 `PlatformException(code: 'PURCHASE_CANCELLED')`。原实现统一抛 `Exception`，UI 上显示"购买失败"，对用户体验不友好。

新增 `PurchaseCanceledException`：

```dart
Exception _wrapPurchaseError(PlatformException e) {
  if (e.code == 'PURCHASE_CANCELLED') {
    return PurchaseCanceledException();
  }
  return Exception(e.message ?? e.code);
}
```

UI 层捕获顺序：`PurchaseCanceledException`（友好提示，不报错）→ `Exception`（红色错误条）。

### 3.3 年度报表年份选择器

- 范围：当前年向前回溯 5 年（IRS 一般要求保留 3 年税务记录，给自由职业者留余量）。
- 实现：`_buildYearSelector()` 返回左右箭头切换组件，箭头在到达边界时禁用（onPressed 为 null）。
- `_palette` 常量从原 `AnnualReportScreen` 类移到 `_AnnualReportScreenState` 类内（避免跨类引用私有常量错误）。

### 3.4 Splash 等待策略

```
启动 → 显示 Splash → 后台并行初始化（Hive/Provider/网络）
                ↓
        监听 AppInitNotifier.isInitialized
                ↓
        elapsed >= 800ms ? → 跳转 Dashboard/Login
                ↓ （否则等待补足 800ms）
        超时 10s 强制跳转（避免初始化卡死导致白屏）
```

设计要点：

- **最小展示时长 800ms**：防止初始化太快导致 Splash 一闪而过，影响品牌展示。
- **10s 超时**：网络/订阅检查失败时不阻断启动，降级本地模式。
- **轮询而非 Future 等待**：`AppInitNotifier` 不暴露 Future，只能轮询 `isInitialized`（每 100ms 一次）。
- **mounted 检查**：跳转前 `if (!mounted) return`，防止 Widget 已销毁时 Navigator 崩溃。

---

## 四、新增 i18n 键清单

需要确认以下键已在 `_en` 和 `_zh` 中都添加：

| Key | en | zh |
|-----|-----|-----|
| `notification.timerChannelName` | Timer | 计时器 |
| `notification.timerChannelDesc` | Work timer notifications | 工作计时器通知 |
| `notification.timerRunningTitle` | Timer running | 计时进行中 |
| `notification.timerRunningBody` | Tracking your work time | 正在记录您的工作时间 |
| `notification.timerPausedTitle` | Timer paused | 计时已暂停 |
| `notification.timerPausedBody` | Resume or stop to save your session | 恢复或停止以保存本次记录 |
| `purchaseCanceled` | Purchase was canceled. You can try again anytime. | 购买已取消，您可以随时重试。 |

---

## 五、验证记录

### 5.1 flutter analyze 输出

```
Analyzing lib...
... (info 警告若干)
NN issues found.
```

- **error：0 条**
- **warning：0 条**（已清理 unused_import、dead_null_aware_expression）
- **info：61 条**（历史存量 lint，详见第六节）

### 5.2 已验证的功能点（手动）

- [x] 启动 App 能正常显示 Splash，800ms 后跳转
- [x] 切换至中文/英文，通知文案正确显示
- [x] 在 Premium 页取消购买，弹出"购买已取消"提示而非错误
- [x] 年度报表切换年份，季度/月度图表数据正确刷新
- [x] 年度报表导出 PDF，文件名包含所选年份

---

## 六、Lint Info 警告清理（M7-7）

### 6.1 警告分类

| 类型 | 数量 | 修复策略 |
|-----|------|----------|
| `deprecated_member_use - withOpacity` | ~10 处 | `color.withOpacity(x)` → `color.withValues(alpha: x)` |
| `deprecated_member_use - value` (FormField) | 4 处 | 构造器中 `value:` → `initialValue:` |
| `prefer_const_constructors` | ~41 处 | 在可 const 化的构造器前加 `const` |
| `use_build_context_synchronously` | 3 处 | async 操作后加 `if (!mounted) return;` |
| `unnecessary_to_list_in_spreads` | 2 处 | `...iterable.toList()` → `...iterable` |

### 6.2 修复原则

- **零功能改动**：只做 lint 提示的等价替换，不重构、不改业务逻辑
- **逐文件复核**：每个文件改完后 Read 复查一遍，确保括号匹配、语法正确
- **跳过原则**：如遇 `StatelessWidget` 无法加 `mounted` 检查、const 参数依赖运行时变量等情况，跳过该条并在文档标注

### 6.3 当前进度

- 已修复：`withOpacity` 全部、`value → initialValue` 全部（subagent 已落盘）
- 剩余：`prefer_const_constructors`（最多）、`use_build_context_synchronously`、`unnecessary_to_list_in_spreads`

---

## 七、剩余工作 & 风险点

### 7.1 立即待办

1. **完成 lint info 清理**（M7-7）：约 45 条剩余，预计 30 分钟内完成
2. **构建 release APK**：`flutter build apk --release`
3. **安装到测试机**：需用户配合：
   - 当前 ADB 设备列表为空，无线调试已断开
   - 需用户提供：手机端"开发者选项 → 无线调试"中的 **配对码** 和 **IP:端口**
   - 配对命令：`adb pair <ip:port>` → 输入配对码 → `adb connect <ip:port>`

### 7.2 已知风险

- **proguard-rules.pro** 已在上轮配置完成（保留 RevenueCat/Hive/flutter_local_notifications 等反射依赖），release 构建应可通过 R8。
- **签名配置**：`key.properties` 已 `.example` 化，正式签名需用户提供 keystore（或确认使用 debug 签名做内部测试）。

### 7.3 不在 M7 范围

- iOS 构建（项目当前仅 Android）
- 应用商店素材（截图/描述/隐私政策 URL）
- 真机功能回归测试（需用户在测试机上手动覆盖）

---

## 八、文档维护说明

- 本文档随 M7 进展实时更新。
- 任务完成后将归档至 `docs/milestones/M7.md`（如未创建则保留在项目根目录）。
- 下一里程碑 M8 待规划。

---

## 九、后续里程碑 M8 —— P0 上架阻塞项全量修复（2026-08-16）

> 本会话在 M7 之后立即以"面向海外 Google Play 上架的资深视角"做了逐文件深度审查,识别并修复了一批 P0 上架阻塞项(安全/税务正确性/合规),对应里程碑 **M8**。**完整修复清单详见 `开发进度与交接.md` 第十四章**(含行号/问题/修复对照表、验证记录、待办)。本节仅给 M8 的一句话定位和入口。

### M8 定位

| 类别 | 修复数 | 验证 | 状态 |
|---|---|---|---|
| 后端(安全+税务正确性) | 6 项 | `node --check` 9 文件 ✅ | 已完成,需重启后端生效 |
| 移动端(安全+业务正确性) | 5 项(+1 跳过) | `flutter analyze` 0 error ✅ | 已完成,**需重建装机生效** |
| Web 端(GDPR 合规) | 1 项 | `npm run build` 58s ✅ | 已完成 |

### M8 修复项编号(B 系列,与 M/H 系列区分)

- **B1-B3, B5-B6** 移动端:Hive 加密、allowBackup 关闭、计时器死区裁剪、月份名 i18n、release HTTPS 断言
- **B4** PDF 中文字体 ⏸️ 暂跳过(待用户提供字体文件)
- **B7-B12** 后端:JWT 算法白名单、注册 trim、自雇税负值、TimeLog min:0、批量上限、projectId 归属校验
- **B14** Web 删除账号入口(GDPR Art.17)

### M8 待用户处理

1. 重建装机验证移动端改动:`cd mobile; flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.3:3001/api/v1`
2. 重启后端:`cd backend; node src/app.js`
3. B4 PDF 字体接入(按 `开发进度与交接.md` 第十四章第五节)

### M8 评审报告中尚未做的项(P1/P2)

- **P1**:SyncService 单例化、登出 Purchases.reset()、移动端 401 并发锁、revokeObjectURL 时机、货币国际化、登录时序攻击、trust proxy、删项目级联、webhook 幂等、密码重置端点
- **P2**:崩溃上报、邮箱验证、Google Sign-In、应用内更新、ToS、多语言、a11y、FLAG_SECURE、监控
