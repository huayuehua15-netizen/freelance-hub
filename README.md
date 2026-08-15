# Freelance Hub 项目框架说明

## 项目结构
```
freelance_hub/
├── mobile/          # Flutter 移动端（Android）
├── backend/         # Node.js + Express + MongoDB 后端
└── web/             # Vue3 + Vite Web 后台
```

## 快速开始

### 1. 移动端 (Flutter)
```bash
cd mobile
flutter pub get
# 生成 Hive Adapter（必须执行，否则编译报错）
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

**环境变量注入（可选）：**
```bash
flutter run --dart-define=ENV=dev \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1 \
  --dart-define=REVENUECAT_API_KEY=your_key
```

### 2. 后端 (Node.js)
```bash
cd backend
npm install
# 确保 MongoDB 已启动，然后
npm start
```
默认端口 3000，健康检查：`GET http://localhost:3000/api/v1/health`

### 3. Web 后台 (Vue3)
```bash
cd web
npm install
npm run dev
```
默认端口 5173，需要 Annual 订阅才能登录。

## 已修复的问题（2026-08-13）
1. routes.dart 补全了 monthlyReport 路由（之前点击月度报表会白屏）
2. timer_screen.dart 添加了每秒刷新（之前计时器数字不会跳动）
3. premium_screen.dart Demo Controls 改用 kDebugMode 判断（之前初始化后按钮消失）
4. timelog_provider.dart 修复了工时计算精度问题
5. 后端 package.json 添加了 start 脚本，依赖版本改为稳定版
6. Web 端 package.json 补全了缺失的依赖（pinia/element-plus/vue-router/axios/echarts）

## 你需要在 Trae/Cursor 中完成的核心业务代码

### 移动端 TODO 标记位置
- `lib/providers/` 下所有 `// TODO:` 标记处（Hive 读写逻辑）
- `lib/services/sync_service.dart` 同步逻辑
- `lib/services/api_service.dart` token刷新逻辑
- 各页面的数据加载和交互
- `lib/screens/premium_screen.dart` RevenueCat真实购买逻辑
- PDF导出实现（pdf + printing包）
- fl_chart 图表数据绑定
- 后台保活和通知（workmanager + flutter_local_notifications）

### 建议开发顺序
1. project_provider.dart 的 loadProjects / createProject（Hive 读写）
2. timelog_provider.dart 的 loadTimeLogs / stopAndSave（Hive 读写）
3. expense_provider.dart 的 loadExpenses / createExpense（Hive 读写）
4. projects_screen.dart 创建项目表单接入 Provider
5. expense_form_screen.dart 已基本完成，确认能保存
6. dashboard_screen.dart 绑定真实数据
7. premium_screen.dart 先用 Demo Controls 测试权限
8. 月度/年度报表页面
9. PDF 导出

### 后端
- 后端代码已较完整，可直接运行，按需修改
- RevenueCat Webhook 签名校验（生产环境需配置真实secret）
- PDF导出内容丰富化

### Web端
- 各页面的 `// TODO:` 标记处，替换mock数据为真实API调用
- 导出功能对接后端

## 重要提醒
1. **Hive Adapter 必须生成**：模型用了 `@HiveType` 注解，首次运行前必须执行 `build_runner`
2. **RevenueCat**：需要在 RevenueCat 后台创建项目，配置 Product ID 和 Entitlement，然后填入 API Key
3. **MongoDB**：后端需要本地或 Atlas MongoDB 连接
4. **Demo数据**：开发文档第13章有完整的模拟数据，可在Hive初始化时导入用于录视频
5. **沙盒测试**：PremiumScreen 底部有 DEMO CONTROLS 按钮（debug模式自动显示），可在无RevenueCat配置时切换权限等级演示
6. **模拟器访问后端**：Android 模拟器访问宿主机后端用 `10.0.2.2`，不是 `localhost`
