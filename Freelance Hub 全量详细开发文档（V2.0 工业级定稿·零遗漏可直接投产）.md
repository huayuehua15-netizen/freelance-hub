# Freelance Hub 全量详细开发文档（V2\.0 工业级定稿·零遗漏可直接投产）

# 0\. 项目总览

## 0\.1 项目定位

Freelance Hub：面向欧美按时计费远程自由职业者（设计师/开发/咨询/文案）的**工时计时 \+ 客户项目管理 \+ 可抵扣开支记账 \+ 年度报税汇总**跨端工具。

产品形态：**Android移动端为主（上架Google Play参赛）\+ Web报表后台为辅（演示加分）**。

参赛场景：Ship\-a\-ton 2026 主赛道 \+ Next Gen学生赛道双赛道参赛，深度适配RevenueCat分层订阅体系，主攻HAMM最佳商业化奖、Design设计奖。

## 0\.2 核心差异化

市面产品割裂：计时工具（Toggl/Clockify）无报税归类、财税工具（QuickBooks/Hurdlr）无精细化计费工时、通用表格（Excel/Notion）无移动端便捷录入。本产品独家打通**可计费工时 \+ 客户项目绑定 \+ 税务抵扣类目 \+ 年度自动汇总报表**轻量化移动端一体化，配套Web大屏深度对账，完美适配海外自雇人士报税刚需。

## 0\.3 最终订阅权限体系（固定不变）

|功能项|Free 免费永久版|Monthly Freelancer $4\.79/月（7天试用）|Annual Contractor $37\.99/年|
|---|---|---|---|
|客户项目数量|最多3个|不限|不限|
|工时记录|基础计时|计时\+标签分类|计时\+标签\+批量管理|
|开支记录|基础录入|税务抵扣归类|自定义税务类目模板|
|数据查看范围|仅当月|全部历史\+月度图表|全部历史\+年度看板|
|PDF导出|无|移动端本地导出|后端批量导出\+Web导出|
|云端多设备同步|无|无|增量双向同步|
|Web后台访问|无|无|大屏年报\+批量操作|
|批量项目归档|无|无|支持|

**核心降级规则（Demo核心亮点）：**订阅到期后，云端同步、Web端访问、年度汇总报表、批量导出全部锁定；**所有本地历史工时/开支数据永久保留、不删除、不丢失、可继续本地查看与新增录入**。

## 0\.4 术语表

|术语|定义|
|---|---|
|Entitlement|RevenueCat中的权限令牌，代表用户当前拥有的功能权益集合|
|Billable Hour|可计费工时，即可以向客户收费的工作时长|
|Tax\-Deductible|税务可抵扣支出，自雇人士申报个税时可用于抵扣应纳税收入的业务开支|
|Self\-employment Tax|美国自雇税，自由职业者需自行缴纳的社保\+医保税|
|Incremental Sync|增量同步，仅传输自上次同步以来发生变更的数据，不全量覆盖|
|Sandbox|RevenueCat/Google Play沙盒环境，用于测试订阅购买不产生真实扣费|
|Restore Purchase|订阅恢复，用户换设备后通过Apple/Google账号恢复已有订阅权益|

# 1\. 整体技术架构方案

## 1\.1 技术栈选型

### 移动端（Android主端·Flutter 唯一选型）

**放弃UniApp的原因：**UniApp为国内生态框架，主打小程序与国内App场景，存在三大致命问题：无官方RevenueCat适配，无法稳定实现分层订阅核心逻辑；WebView渲染性能弱，后台计时保活、离线数据库稳定性差；海外Google Play上架生态认可度低，评委易判定为国内套壳玩具。Flutter为Google官方跨端方案，是海外竞赛、海外商业化App标准选型。

|层级|技术选型|版本要求|用途|
|---|---|---|---|
|框架|Flutter|3\.27\+|跨端UI与业务逻辑|
|本地数据库|Hive|2\.2\+|离线优先持久化存储|
|状态管理|Provider|6\.1\+|全局状态与权限管控|
|订阅支付|purchases\_flutter（RevenueCat官方SDK）|最新稳定版|内购订阅与权限生命周期|
|PDF生成|pdf \+ printing|最新稳定版|移动端本地报表导出|
|图表可视化|fl\_chart|0\.68\+|折线/饼图/柱状图|
|后台保活|workmanager|0\.5\+|计时器后台任务保活|
|网络请求|dio|5\.4\+|HTTP客户端\+拦截器|
|本地通知|flutter\_local\_notifications|17\+|计时结束/订阅到期提醒|

### 后端（轻量API服务）

|层级|技术选型|版本要求|用途|
|---|---|---|---|
|运行时|Node\.js|20 LTS|服务端运行环境|
|框架|Express|4\.18\+|RESTful API|
|数据库|MongoDB|6\.0\+|云端同步数据存储|
|ODM|Mongoose|8\.0\+|数据模型与校验|
|鉴权|jsonwebtoken|9\.0\+|JWT无状态令牌|
|PDF服务|pdfkit|0\.13\+|后端批量报表生成|
|日志|winston|3\.11\+|结构化日志|
|限流|express\-rate\-limit|7\.1\+|API防刷限流|

### Web后台（仅报表展示\+批量导出）

|层级|技术选型|版本要求|用途|
|---|---|---|---|
|框架|Vue3|3\.4\+|响应式UI|
|构建工具|Vite|5\.0\+|开发与构建|
|图表|ECharts|5\.4\+|大屏数据可视化|
|UI组件|Element Plus|2\.5\+|表格/表单/弹窗|
|状态管理|Pinia|2\.1\+|全局状态|
|HTTP|axios|1\.6\+|API请求|

## 1\.2 系统架构与数据流

**整体架构：**移动端App为核心数据录入入口，所有读写优先操作本地Hive数据库（离线优先）；年度会员通过后端API进行增量双向同步；Web后台仅通过后端API读取已同步数据，不提供业务录入功能。RevenueCat SDK嵌入移动端，负责订阅状态的获取与变更监听，权限变更通过Provider全局刷新UI。

**数据流方向：**

1. 用户操作 → 本地Hive写入（即时响应，不等待网络）

2. 若为Annual会员且有网络 → 后台队列异步上传变更到后端

3. 后端MongoDB持久化 → 返回serverUpdateTime

4. App拉取远端变更（按lastSyncTime增量拉取）→ 合并到本地

5. Web后台 → 调用后端API → 读取MongoDB数据 → 大屏展示

6. RevenueCat SDK → 监听订阅状态变更 → 更新本地Entitlement缓存 → Provider全局刷新权限

## 1\.3 核心架构原则

1. **离线优先：**所有读写优先本地Hive，无网络完全可用，同步为后台异步行为

2. **增量同步：**仅传输新增/变更数据，基于updateTime时间戳，不全量覆盖

3. **双重权限拦截：**前端UI拦截（体验层）\+ 后端接口强制鉴权拦截（安全层）

4. **数据永不丢失：**会员过期仅锁功能，不删用户任何数据，本地数据永久可读

5. **最终一致性：**多端数据通过增量同步\+冲突解决策略达到最终一致

## 1\.4 工程目录结构

### 移动端 Flutter 工程

```text
lib/
├── main.dart                    # 应用入口
├── app.dart                     # 根Widget，MultiProvider注册、主题、路由
├── routes.dart                  # 命名路由表
├── config/
│   ├── app_config.dart          # 环境配置（API地址、RevenueCat Key、环境变量）
│   └── app_theme.dart           # 色彩系统、light/dark主题
├── models/                      # Hive数据模型（5个，@HiveType注解）
│   ├── user_info.dart
│   ├── client_project.dart
│   ├── time_log.dart
│   ├── expense_log.dart
│   └── tax_category.dart
├── providers/                   # 状态管理（5个Provider）
│   ├── auth_provider.dart       # 登录态
│   ├── premium_provider.dart    # 订阅权限（核心，含Demo沙盒切换）
│   ├── project_provider.dart    # 项目CRUD + Free版3个限制
│   ├── timelog_provider.dart    # 计时器状态机 + 工时数据
│   └── expense_provider.dart    # 开支CRUD
├── services/
│   ├── hive_service.dart        # Hive初始化、Adapter注册、Box管理
│   ├── api_service.dart         # Dio封装（TODO: token刷新）
│   └── sync_service.dart        # 增量同步（TODO: 同步逻辑）
├── screens/                     # 13个页面
│   ├── splash_screen.dart       # 启动页（2秒后跳Dashboard）
│   ├── login_screen.dart        # 登录页（TODO）
│   ├── main_screen.dart         # 底部4Tab导航容器
│   ├── dashboard_screen.dart    # 首页看板
│   ├── timer_screen.dart        # 计时器（已含每秒刷新）
│   ├── projects_screen.dart     # 项目列表 + 创建底部弹窗
│   ├── project_detail_screen.dart
│   ├── expense_screen.dart      # 开支列表
│   ├── expense_form_screen.dart # 开支表单（已完成表单UI）
│   ├── monthly_report_screen.dart
│   ├── annual_report_screen.dart
│   ├── premium_screen.dart      # 订阅页（含Demo Controls）
│   └── settings_screen.dart
└── widgets/
    ├── premium_guard.dart       # 权限拦截组件
    └── empty_state.dart         # 空状态组件
```

### 后端 Node\.js 工程

```text
backend/
├── .env                         # 环境变量（端口、MongoDB、JWT密钥等）
├── package.json                 # 依赖与启动脚本（npm start）
└── src/
    ├── app.js                   # Express入口（路由挂载、健康检查、错误处理）
    ├── config/
    │   ├── env.js               # 环境变量加载
    │   └── database.js          # MongoDB连接
    ├── models/                  # Mongoose模型（4个，含索引）
    │   ├── User.js
    │   ├── ClientProject.js
    │   ├── TimeLog.js
    │   └── ExpenseLog.js
    ├── controllers/             # 7个控制器（业务逻辑已实现）
    │   ├── authController.js    # 注册/登录/刷新/注销
    │   ├── projectController.js
    │   ├── timelogController.js
    │   ├── expenseController.js
    │   ├── reportController.js  # 含PDF导出
    │   ├── premiumController.js
    │   └── webhookController.js # RevenueCat回调（7种事件）
    ├── middleware/
    │   ├── auth.js              # JWT鉴权
    │   ├── premium.js           # requireMonthly/requireAnnual
    │   ├── rateLimit.js         # 限流
    │   └── errorHandler.js      # 全局异常
    ├── services/
    │   ├── syncService.js       # 批量upsert + LWW冲突处理
    │   └── reportService.js     # 月度/年度报表聚合
    ├── routes/                  # 7个路由文件
    │   ├── auth.js, project.js, timelog.js
    │   ├── expense.js, report.js
    │   ├── premium.js, webhook.js
    └── utils/
        ├── constants.js         # 错误码/会员类型常量
        ├── jwt.js               # Token签发验证
        └── logger.js            # winston日志
```

## 1\.5 环境配置

|环境|后端地址|RevenueCat|Google Play|用途|
|---|---|---|---|---|
|dev|http://localhost:3000（Android模拟器用10\.0\.2\.2:3000）|Sandbox API Key|沙盒测试账号|本地开发调试|
|staging|https://staging\-api\.freelancehub\.app|Sandbox API Key|内部测试轨道|集成测试与Demo录制|
|prod|https://api\.freelancehub\.app|Production API Key|正式发布轨道|上架参赛与真实用户|

# 2\. 数据库完整设计

## 2\.1 移动端 Hive 数据表

### 表1：user\_info 用户信息表

|字段名|类型|必填|说明|
|---|---|---|---|
|userId|String|是|唯一主键，UUID格式|
|userName|String|否|用户显示名|
|userEmail|String|否|登录邮箱|
|currency|String|是|默认货币，默认USD|
|timezone|String|是|时区标识，如America/New\_York|
|isPremium|bool|是|是否拥有付费权益（月/年均为true）|
|premiumType|String|是|free / monthly / annual|
|expireTime|int|否|订阅过期时间戳（毫秒），free为null|
|trialEndTime|int|否|试用期结束时间戳|
|lastSyncTime|int|是|最后一次成功同步时间戳，默认0|
|createdAt|int|是|创建时间戳|
|updatedAt|int|是|更新时间戳|

### 表2：client\_project 客户项目表

|字段名|类型|必填|说明|
|---|---|---|---|
|projectId|String|是|唯一主键，UUID|
|clientName|String|是|客户名称|
|clientEmail|String|否|客户联系邮箱|
|projectName|String|是|项目名称|
|hourlyRate|double|是|时薪（美元）|
|currency|String|是|项目货币，默认继承用户设置|
|status|String|是|active / archived / completed|
|isDeleted|bool|是|软删除标记，默认false|
|syncStatus|int|是|0=待同步 / 1=已同步 / 2=同步冲突|
|serverUpdateTime|int|否|服务端最后更新时间戳|
|createdAt|int|是|创建时间戳|
|updatedAt|int|是|更新时间戳（增量同步依据）|

### 表3：time\_log 工时记录表

|字段名|类型|必填|说明|
|---|---|---|---|
|timeLogId|String|是|唯一主键，UUID|
|projectId|String|是|关联项目ID|
|startTime|int|是|开始时间戳（毫秒，UTC）|
|endTime|int|否|结束时间戳，进行中为null|
|duration|double|是|时长（小时），保留2位小数，进行中为0|
|isBillable|bool|是|是否可计费，默认true|
|billableAmount|double|是|可计费金额 = duration × 项目时薪|
|tag|String|否|工时标签（design/dev/meeting等）|
|note|String|否|工作内容备注|
|isDeleted|bool|是|软删除标记|
|syncStatus|int|是|0=待同步 / 1=已同步 / 2=冲突|
|serverUpdateTime|int|否|服务端更新时间戳|
|createdAt|int|是|创建时间戳|
|updatedAt|int|是|更新时间戳|

### 表4：expense\_log 开支记录表

|字段名|类型|必填|说明|
|---|---|---|---|
|expenseId|String|是|唯一主键，UUID|
|projectId|String|否|关联项目ID，可为空（通用业务开支）|
|amount|double|是|开支金额|
|currency|String|是|货币代码|
|expenseDate|int|是|开支发生日期（时间戳，区别于创建时间）|
|category|String|是|开支分类，关联tax\_category字典|
|isTaxDeductible|bool|是|是否税务可抵扣|
|merchant|String|否|商家/收款方名称|
|note|String|否|备注说明|
|receiptUrl|String|否|票据图片URL（云端存储，Annual功能）|
|isDeleted|bool|是|软删除标记|
|syncStatus|int|是|0=待同步 / 1=已同步 / 2=冲突|
|serverUpdateTime|int|否|服务端更新时间戳|
|createdAt|int|是|创建时间戳|
|updatedAt|int|是|更新时间戳|

### 表5：tax\_category 税务类目字典表

|字段名|类型|必填|说明|
|---|---|---|---|
|categoryId|String|是|唯一主键|
|name|String|是|类目名称（英文）|
|isDefault|bool|是|是否系统内置默认类目|
|isTaxDeductibleDefault|bool|是|该类目默认是否可抵扣|
|sortOrder|int|是|显示排序|
|createdAt|int|是|创建时间戳|

**内置默认类目：**Software \& Subscriptions / Office Supplies / Internet \& Phone / Hardware \& Equipment / Travel / Education \& Training / Marketing \& Advertising / Legal \& Professional / Insurance / Other Business Expense

### 表6：app\_config 本地配置表

|字段名|类型|说明|
|---|---|---|
|key|String|配置键，主键|
|value|dynamic|配置值（任意类型）|

## 2\.2 后端 MongoDB 数据表

所有集合字段与移动端完全对齐，额外增加以下同步管控字段：

|字段名|类型|说明|
|---|---|---|
|userId|String|数据归属用户（所有业务表必带，用于数据隔离）|
|serverCreateTime|Date|服务端创建时间|
|serverUpdateTime|Date|服务端更新时间（增量拉取依据）|

### MongoDB 索引设计

|集合|索引字段|类型|用途|
|---|---|---|---|
|users|userId|唯一|用户主键查询|
|users|userEmail|唯一稀疏|邮箱登录|
|client\_projects|userId \+ projectId|唯一复合|用户内项目唯一|
|client\_projects|userId \+ updatedAt|普通复合|增量同步查询|
|time\_logs|userId \+ timeLogId|唯一复合|工时唯一|
|time\_logs|userId \+ updatedAt|普通复合|增量同步|
|time\_logs|userId \+ startTime|普通复合|报表时间范围查询|
|expense\_logs|userId \+ expenseId|唯一复合|开支唯一|
|expense\_logs|userId \+ updatedAt|普通复合|增量同步|
|expense\_logs|userId \+ expenseDate|普通复合|报表时间范围查询|

## 2\.3 数据库版本迁移策略

1. Hive使用TypeAdapter注册，每个数据模型标注固定typeId（0\-5），新增字段通过默认值兼容旧版本

2. App启动时检测本地数据库版本号（存于app\_config），若低于当前版本，执行对应迁移脚本

3. 迁移脚本按版本号顺序执行，每个迁移包含upgrade和rollback方法

4. MongoDB通过Mongoose Schema的default值和setDefaultsOnInsert选项保证字段兼容

5. 破坏性字段变更（删除/重命名）必须经过至少一个版本的过渡期，同时保留新旧字段

# 3\. 完整前后端接口文档

## 3\.1 通用规范

**基础前缀：**`/api/v1`

**统一请求头：**

|Header|必填|说明|
|---|---|---|
|Authorization|是（除登录/注册）|Bearer \{JWT access token\}|
|Content\-Type|是|application/json|
|X\-Device\-Id|否|设备唯一标识，用于多端识别|
|X\-App\-Version|否|App版本号，用于兼容性判断|

**统一返回格式：**

```json
{
  "code": 200,
  "msg": "success",
  "data": {},
  "timestamp": 1718236800000
}
```

**统一错误码：**

|code|HTTP状态|说明|
|---|---|---|
|200|200|成功|
|400|400|请求参数错误|
|401|401|未登录或Token过期|
|403|403|权限不足（会员等级不够）|
|404|404|资源不存在|
|409|409|数据冲突（同步冲突）|
|429|429|请求过于频繁（限流）|
|500|500|服务端内部错误|
|1001|401|Refresh Token过期，需重新登录|
|2001|403|免费版项目数已达上限（3个）|
|2002|403|该功能需要Monthly及以上会员|
|2003|403|该功能需要Annual会员（云端同步/Web访问）|
|3001|409|同步冲突，需客户端处理|

**分页规范：**列表接口统一使用游标分页，参数为`limit`（每页条数，默认20，最大100）和`cursor`（上一页最后一条的updatedAt时间戳，首页不传）。返回包含`hasMore`和`nextCursor`。

## 3\.2 用户鉴权接口

### POST /auth/register — 用户注册

**权限：**公开

**请求参数：**

|字段|类型|必填|说明|
|---|---|---|---|
|email|String|是|邮箱地址|
|password|String|是|密码（最少8位，前端加密传输）|
|userName|String|否|显示名称|
|currency|String|否|默认货币，默认USD|
|timezone|String|否|时区，默认America/New\_York|

**返回数据：**

```json
{
  "userId": "uuid-string",
  "email": "user@example.com",
  "userName": "John Doe",
  "premiumType": "free",
  "accessToken": "jwt-access-token",
  "refreshToken": "jwt-refresh-token",
  "expiresIn": 3600
}
```

### POST /auth/login — 用户登录

**权限：**公开

**请求参数：**email, password

**返回数据：**同注册接口

### POST /auth/refresh — 刷新Token

**权限：**需有效refreshToken（放在请求体）

**请求参数：**refreshToken

**返回数据：**新的accessToken \+ refreshToken \+ expiresIn

**说明：**accessToken有效期1小时，refreshToken有效期30天；refreshToken单次使用，刷新后旧token立即失效。

### GET /auth/me — 获取当前用户信息

**权限：**已登录

**返回数据：**用户完整信息 \+ premiumType \+ expireTime \+ 可用权限集合

### POST /auth/logout — 退出登录

**权限：**已登录

**说明：**服务端将当前refreshToken加入黑名单，客户端清除本地token。

### DELETE /auth/account — 注销账户（GDPR要求）

**权限：**已登录

**说明：**软删除用户账户，30天宽限期内可恢复；30天后永久删除所有关联数据。需用户二次确认。

## 3\.3 项目同步接口

### POST /project/batch\-upsert — 批量上传项目（增量同步）

**权限：**Annual会员

**请求参数：**

```json
{
  "projects": [
    {
      "projectId": "uuid",
      "clientName": "Acme Corp",
      "projectName": "Website Redesign",
      "hourlyRate": 45.0,
      "currency": "USD",
      "status": "active",
      "isDeleted": false,
      "clientUpdatedAt": 1718236800000
    }
  ],
  "deviceId": "device-uuid"
}
```

**返回数据：**

```json
{
  "results": [
    {
      "projectId": "uuid",
      "status": "updated",
      "serverUpdateTime": 1718237000000,
      "conflict": false
    }
  ],
  "conflicts": []
}
```

### GET /project/pull — 增量拉取项目

**权限：**Annual会员

**请求参数：**since（时间戳，拉取该时间之后变更的数据）、limit、cursor

**返回数据：**变更项目列表 \+ hasMore \+ nextCursor

### GET /project/list — 获取全部项目列表

**权限：**已登录（Free返回最多3个，Monthly/Annual返回全部）

**请求参数：**status（可选筛选：active/archived）、limit、cursor

### DELETE /project/\{projectId\} — 删除项目

**权限：**已登录

**说明：**软删除，设置isDeleted=true；同步到云端后其他设备也会标记删除。

## 3\.4 工时同步接口

### POST /timelog/batch\-upsert — 批量上传工时

**权限：**Annual会员

**请求体结构：**同项目批量上传，包含timeLogId、projectId、startTime、endTime、duration、isBillable、tag、note、isDeleted、clientUpdatedAt

### GET /timelog/pull — 增量拉取工时

**权限：**Annual会员

**请求参数：**since、limit、cursor

### GET /timelog/list — 工时列表查询

**权限：**已登录（Free仅当月数据）

**请求参数：**projectId（可选）、startDate、endDate、limit、cursor

### DELETE /timelog/\{timeLogId\} — 删除工时

**权限：**已登录

## 3\.5 开支同步接口

### POST /expense/batch\-upsert — 批量上传开支

**权限：**Annual会员

**请求体结构：**包含expenseId、projectId、amount、currency、expenseDate、category、isTaxDeductible、merchant、note、isDeleted、clientUpdatedAt

### GET /expense/pull — 增量拉取开支

**权限：**Annual会员

### GET /expense/list — 开支列表查询

**权限：**已登录（Free仅当月数据）

**请求参数：**projectId、category、isTaxDeductible、startDate、endDate、limit、cursor

### DELETE /expense/\{expenseId\} — 删除开支

**权限：**已登录

## 3\.6 报表接口（HAMM核心演示）

### GET /report/monthly — 月度报表数据

**权限：**Monthly/Annual会员

**请求参数：**year、month、projectId（可选）

**返回数据：**

```json
{
  "period": "2026-05",
  "totalBillableHours": 84.5,
  "totalBillableAmount": 3780.00,
  "totalExpenses": 324.98,
  "taxDeductibleExpenses": 289.98,
  "nonDeductibleExpenses": 35.00,
  "netIncome": 3455.02,
  "hoursByProject": [
    {"projectId": "uuid", "projectName": "Website Redesign", "hours": 40.0, "amount": 1800.00}
  ],
  "expensesByCategory": [
    {"category": "Software", "amount": 54.99, "isTaxDeductible": true}
  ],
  "dailyHoursTrend": [
    {"date": "2026-05-01", "hours": 6.5}
  ]
}
```

### GET /report/annual — 年度报税汇总（Annual专属）

**权限：**Annual会员

**请求参数：**year

**返回数据：**年度总收入、总可计费工时、总开支、可抵扣开支汇总、按季度拆分、按项目汇总、按类目汇总、预估自雇税（仅参考，不构成税务建议）

### GET /report/export — 导出PDF报表

**权限：**Monthly（本地生成）/ Annual（云端生成）

**请求参数：**type（monthly/annual）、year、month（月报必填）

**返回数据：**PDF文件下载URL（有效期24小时）

**说明：**Monthly会员在移动端本地生成PDF，不调用此接口；Annual会员调用后端生成高质量PDF，支持批量导出。

## 3\.7 权限校验接口

### GET /premium/entitlement — 获取当前用户权限集合

**权限：**已登录

**返回数据：**

```json
{
  "premiumType": "annual",
  "expireTime": 1748236800000,
  "isTrial": false,
  "trialEndTime": null,
  "entitlements": {
    "unlimitedProjects": true,
    "monthlyReport": true,
    "annualReport": true,
    "pdfExport": true,
    "cloudSync": true,
    "webAccess": true,
    "batchArchive": true,
    "customTaxCategory": true
  }
}
```

**说明：**后端通过RevenueCat API实时校验用户订阅状态，返回最新权限。客户端以此为准，不依赖本地缓存。

## 3\.8 RevenueCat Webhook 回调接口

### POST /webhook/revenuecat — 订阅事件回调

**权限：**RevenueCat签名校验

**说明：**RevenueCat在订阅状态变更时（购买、续费、过期、取消、退款、恢复）调用此接口。后端校验签名后更新用户premiumType和expireTime，并触发多端权限刷新。

**处理事件类型：**

|事件|处理逻辑|
|---|---|
|INITIAL\_PURCHASE|首次购买，设置会员等级和过期时间|
|RENEWAL|续费，更新过期时间|
|EXPIRATION|订阅过期，降级为free，保留数据|
|CANCELLATION|用户取消订阅（仍有效至到期日）|
|REFUND|退款，立即降级|
|PRODUCT\_CHANGE|切换套餐（月→年等）|
|SUBSCRIPTION\_PAUSED|订阅暂停（Google Play）|

# 4\. 权限控制体系

## 4\.1 前端拦截规则

|功能|Free|Monthly|Annual|拦截方式|
|---|---|---|---|---|
|新建项目（第4个起）|禁用|允许|允许|按钮置灰\+点击弹窗引导升级|
|月度报表|隐藏入口|允许|允许|PremiumGuard包裹组件|
|年度报税报表|隐藏|隐藏|允许|PremiumGuard包裹|
|PDF导出|隐藏按钮|本地导出|云端导出|按钮级权限控制|
|云端同步|隐藏设置项|隐藏|自动同步|SyncService判断等级|
|Web后台登录|拒绝|拒绝|允许|后端鉴权拒绝|
|批量归档|无|无|允许|按钮级控制|
|自定义税务类目|仅默认|仅默认|允许新增|表单级控制|

**过期用户处理：**订阅到期后自动降级为Free权限规则，但所有本地数据完整保留，已录入的超过3个的项目仍可查看和编辑（不强制删除），仅禁止新建第4个项目。

## 4\.2 后端强制拦截

所有需要付费权限的接口，在Controller层通过`premium.middleware`二次校验会员等级。校验逻辑：

1. 从JWT解析userId

2. 查询用户数据库中的premiumType和expireTime

3. 调用RevenueCat API获取最新订阅状态（防止本地缓存不一致）

4. 对比接口所需最低等级，不足则返回403 \+ 对应错误码（2001/2002/2003）

**安全红线：**前端拦截仅为体验优化，后端强制拦截为安全底线。绝不能仅依赖前端控制权限，否则可被抓包绕过。

## 4\.3 RevenueCat 详细配置

### Product ID 命名规范

|套餐|Google Play Product ID|类型|价格|试用期|
|---|---|---|---|---|
|Monthly Freelancer|`freelance_hub_monthly_479`|月度订阅|$4\.79/月|7天免费|
|Annual Contractor|`freelance_hub_annual_3799`|年度订阅|$37\.99/年|7天免费|

### Entitlement 配置

|Entitlement ID|关联Product|包含权限|
|---|---|---|
|`free`|默认（无购买）|基础功能|
|`monthly_premium`|freelance\_hub\_monthly\_479|不限项目\+月度报表\+本地PDF|
|`annual_pro`|freelance\_hub\_annual\_3799|全部功能\+云端同步\+Web\+批量导出|

### Sandbox 测试流程

1. Google Play Console创建内部测试轨道，添加测试账号

2. RevenueCat Dashboard配置Sandbox API Key

3. App使用Sandbox Key初始化，测试账号可模拟购买不扣费

4. 测试场景：首次购买（含试用）、续费、手动过期、取消、退款、恢复购买、切换套餐

5. 验证每种场景下App权限正确变更、UI正确刷新、数据不丢失

### 订阅恢复（Restore Purchase）流程

1. 用户在新设备登录后，进入订阅页点击"Restore Purchases"

2. 调用RevenueCat SDK的restorePurchases方法

3. SDK通过Google Play账号查询历史订阅

4. 若存在有效订阅，更新本地Entitlement和用户premiumType

5. 同步到后端，更新用户会员状态

# 5\. UI/UX 全局设计规范

## 5\.1 设计风格

极简商务轻量化、海外SaaS标准风格、低饱和高质感、无冗余动画，适配Design奖项评审。信息层级清晰，操作路径短，核心功能（计时/录入）一屏可达。

## 5\.2 全局色彩系统

|角色|色值|用途|
|---|---|---|
|Primary 主色|\#2563EB|主按钮、选中态、导航高亮|
|Primary Light|\#DBEAFE|主色浅背景|
|Success 成功|\#10B981|同步成功、正向数据|
|Warning 警告|\#F59E0B|试用即将到期、提醒|
|Danger 危险|\#EF4444|删除、过期、错误|
|Background 背景|\#F8FAFC|页面底色|
|Surface 卡片|\#FFFFFF|卡片、弹窗背景|
|Text Primary|\#1E293B|标题、正文|
|Text Secondary|\#64748B|辅助文字、说明|
|Text Disabled|\#94A3B8|禁用文字|
|Border 边框|\#E2E8F0|分割线、输入框边框|

## 5\.3 全局尺寸与字体规范

|元素|规范|
|---|---|
|卡片圆角|12px|
|按钮圆角|8px|
|输入框圆角|8px|
|卡片阴影|0 2px 8px rgba\(0,0,0,0\.06\)|
|页面水平边距|16px|
|卡片内边距|16px|
|字体|Roboto（Android系统无衬线，海外原生适配）|
|标题字号|20sp / 24sp（页面大标题）|
|正文字号|14sp / 16sp|
|辅助文字|12sp|

## 5\.4 移动端导航结构

**底部Tab导航（4个）：**

1. **Dashboard 看板**：首页数据概览

2. **Timer 计时**：工时计时器（核心功能，中间突出按钮）

3. **Projects 项目**：客户项目列表

4. **Reports 报表**：月度/年度报表入口（权限卡点）

**侧边抽屉：**开支记录、设置、订阅会员、帮助反馈

## 5\.5 各页面详细布局

### Splash 启动初始化页

全屏Logo \+ 加载指示器。后台执行：Hive初始化 → RevenueCat SDK初始化 → 检查登录态 → 获取最新订阅权限 → 跳转到对应页面（未登录→登录页，已登录→看板）。超时3秒强制进入。

### Dashboard 数据看板首页

**顶部区域：**用户头像\+名称 \+ 当月净收入大字展示 \+ 会员状态标签（Free/Monthly/Annual，试用中显示剩余天数）

**核心卡片（横向滚动或纵向排列）：**

- 本月可计费工时 \+ 环比变化

- 本月总收入 \+ 环比变化

- 本月可抵扣开支 \+ 环比变化

- 进行中项目数量

**快捷操作区：**开始计时按钮（大按钮，主色）、快速录开支按钮

**最近活动列表：**最近5条工时/开支记录，点击可跳转详情

**空状态：**无数据时显示插画 \+ "Start tracking your first work session"引导文案 \+ 开始计时按钮

### Timer 工时计时器页

**顶部：**当前选中项目名称（可点击切换）\+ 时薪显示

**中部：**大字号计时器（HH:MM:SS），运行中数字动态刷新

**标签选择：**横向滚动标签（Design/Dev/Meeting/Other），可多选

**备注输入：**单行文本框，记录工作内容

**底部操作：**开始/暂停按钮（主色大按钮）\+ 结束并保存按钮 \+ 取消按钮

**状态说明：**

|状态|UI表现|可操作|
|---|---|---|
|idle 空闲|计时器显示00:00:00，开始按钮可用|选择项目、开始计时|
|running 运行中|数字跳动，暂停按钮显示，通知栏显示计时中|暂停、添加备注、切换标签|
|paused 已暂停|数字静止，继续按钮显示|继续、结束保存、取消|

### Projects 项目管理页

**顶部：**搜索框 \+ 筛选（全部/进行中/已归档）\+ 新建项目按钮

**Free版提示：**当项目数=3时，新建按钮旁显示"Free plan limit: 3 projects"小标签，点击新建弹出升级引导

**项目卡片列表：**每张卡片显示客户名\+项目名、时薪、本月累计工时、本月累计收入、状态标签

**项目详情页：**项目基本信息 \+ 该项目工时列表 \+ 该项目开支列表 \+ 项目收支汇总 \+ 编辑/归档/删除操作

### Expense 开支记录页

**顶部：**本月开支总额 \+ 可抵扣/不可抵扣占比小饼图

**筛选栏：**时间范围 \+ 分类 \+ 是否可抵扣

**开支列表：**按日期分组，每条显示商家名、金额、分类标签、可抵扣标记（绿色对勾）

**新增/编辑开支表单：**金额（必填）、开支日期（默认今天）、分类（下拉选择，关联tax\_category）、关联项目（可选）、商家名称、是否可抵扣（开关，默认根据分类自动设置）、备注、票据照片（Annual功能，Free/Monthly隐藏）

### Monthly Report 月度报表演示页

**权限：**Monthly/Annual可见，Free点击入口弹出升级引导

**顶部：**月份选择器（左右切换）\+ 导出PDF按钮

**数据卡片：**总收入、总工时、总开支、可抵扣开支、净收入

**图表区：**每日工时趋势折线图、开支分类饼图、项目收入柱状图

**明细列表：**按项目汇总的工时和收入

### Annual Report 年度报税报表页

**权限：**Annual专属，Monthly/Free均显示升级引导

**顶部：**年份选择 \+ 导出完整报税PDF按钮

**核心数据：**年度总收入、年度总工时、年度总开支、年度可抵扣开支、预估净收入、预估自雇税（标注"Estimate only, not tax advice"）

**季度拆分：**四个季度的收入/开支/工时对比柱状图

**分类汇总：**按税务类目汇总的可抵扣开支明细表

**免责声明：**页面底部固定显示"This report is for record\-keeping purposes only and does not constitute tax advice\. Please consult a certified tax professional\."

### Premium 订阅会员页

**顶部：**产品价值主张文案 \+ 当前会员状态

**三档套餐卡片：**Free（当前标记）、Monthly（显示7天免费试用标签）、Annual（显示"Best Value"推荐标签，计算月均$3\.17）

**功能对比表：**精简版对比，突出各档差异

**购买按钮：**Monthly/Annual卡片底部各有购买按钮，调用RevenueCat SDK发起购买

**底部链接：**Restore Purchases（恢复购买）、Privacy Policy、Terms of Service

**试用期用户：**顶部显示黄色警告条"Trial ends in X days\. You won't be charged if you cancel before then\."

### Settings 设置页

账户信息（名称/邮箱/货币/时区）、数据管理（导出本地数据/清除缓存）、同步状态（Annual显示，Free/Monthly隐藏并提示升级）、通知设置、关于（版本号/隐私政策/用户协议）、登出按钮、注销账户入口（GDPR）

## 5\.6 Web后台页面

### Web登录页

邮箱\+密码登录，底部提示"Web dashboard is available for Annual Contractor plan only"。非Annual用户登录后提示升级。

### Web年度大屏报表页

**顶部导航：**Logo \+ 年份选择 \+ 导出PDF \+ 用户菜单

**核心指标卡片行：**年度总收入、总工时、总开支、可抵扣开支、净收入（5个卡片并排）

**图表区（2列布局）：**月度收入趋势折线图、月度开支柱状图、开支分类饼图、项目收入排行柱状图

**底部明细：**可切换Tab查看工时明细/开支明细，支持筛选、排序、分页

### Web批量导出页

选择时间范围 \+ 选择导出内容（工时/开支/全部）\+ 选择格式（PDF/CSV）\+ 生成导出按钮。导出任务异步处理，完成后提供下载链接。

## 5\.7 通用状态设计

|状态|表现|
|---|---|
|加载中|骨架屏（数据列表）/ 居中Loading指示器（页面切换）|
|空状态|插画 \+ 说明文案 \+ 引导操作按钮|
|错误状态|错误图标 \+ 错误信息 \+ 重试按钮|
|无网络|顶部黄色提示条"No internet connection\. Data will sync when online\."（Annual用户）|
|同步中|设置页同步状态显示"Syncing\.\.\."旋转图标|
|同步失败|红色提示"Sync failed\. Will retry automatically\."|

## 5\.8 表单校验规则

|字段|规则|
|---|---|
|邮箱|必填，符合email格式|
|密码|必填，最少8位，至少包含字母和数字|
|客户名称|必填，最多100字符|
|项目名称|必填，最多100字符|
|时薪|必填，大于0，最多2位小数|
|开支金额|必填，大于0，最多2位小数|
|工时备注|可选，最多500字符|

## 5\.9 深色模式与多语言

**深色模式：**MVP阶段跟随系统，提供完整深色配色方案（背景\#0F172A、卡片\#1E293B、文字\#F1F5F9）。P1优先级。

**多语言：**MVP仅英文（en），架构预留i18n接口，所有文案通过arb文件管理，便于后续扩展。

# 6\. 核心业务详细规则

## 6\.1 工时计时器状态机

计时器存在4种状态，状态转换规则如下：

|当前状态|事件|目标状态|副作用|
|---|---|---|---|
|idle|start\(\)|running|记录startTime=now，启动后台保活任务，显示通知|
|running|pause\(\)|paused|记录已运行时长，暂停保活任务，更新通知|
|paused|resume\(\)|running|恢复计时，重启保活任务|
|running|stopAndSave\(\)|idle|计算总duration，生成timeLog记录写入Hive，标记syncStatus=0，取消保活和通知|
|paused|stopAndSave\(\)|idle|同上|
|running/paused|cancel\(\)|idle|丢弃当前计时，不保存，取消保活和通知|

**异常恢复：**App启动时检查是否存在未结束的计时任务（startTime存在但endTime为null），若有则根据当前时间计算已运行时长，自动恢复为running状态，确保杀进程后计时不丢失。

**后台保活：**使用workmanager注册周期性任务（每15分钟），确保计时状态在后台不被系统清除；同时通过前台服务（Foreground Service）显示持续通知，提升进程优先级。

## 6\.2 税务抵扣规则

1. 每笔开支独立勾选Tax\-Deductible开关，默认值根据所选分类的isTaxDeductibleDefault自动设置，用户可手动覆盖

2. 年度报表自动统计：总收入（可计费工时金额总和）、非抵扣开支、可抵扣开支、净营收（总收入 \- 总开支）

3. 预估自雇税 = 净营收 × 15\.3%（美国2024年自雇税率，标注为参考值）

4. 所有税务相关文案包含免责声明："For reference only\. Consult a tax professional for filing advice\."

5. Annual用户可自定义税务类目，Free/Monthly仅使用系统内置10个默认类目

## 6\.3 数据同步与冲突处理

### 增量同步协议

1. 客户端维护lastSyncTime（用户级），每次成功同步后更新为服务端返回的最新serverUpdateTime

2. 上传：收集本地所有syncStatus≠1（待同步/冲突）的记录，批量调用batch\-upsert接口，携带clientUpdatedAt

3. 拉取：调用pull接口，参数since=lastSyncTime，获取服务端所有更新时间大于该值的记录

4. 合并：拉取到的远端记录与本地对比，按冲突解决策略处理

5. 同步触发时机：Annual用户登录后、数据变更后延迟5秒防抖、App回到前台、手动点击同步

### 冲突解决策略

采用**Last\-Write\-Wins（最后写入优先）**策略，基于updatedAt时间戳：

- 远端记录的serverUpdateTime \> 本地updatedAt → 远端覆盖本地

- 远端记录的serverUpdateTime \< 本地updatedAt → 本地保留，重新上传本地版本

- 时间戳相等 → 视为一致，不做处理

**特殊场景：**同一记录在两端都被删除，以删除为准；一端删除一端修改，以删除为准（软删除），避免幽灵数据。

**冲突标记：**无法自动解决的极端冲突标记syncStatus=2，在设置页显示冲突列表供用户手动选择保留版本。MVP阶段LWW策略可覆盖99%场景。

## 6\.4 时区与货币处理

**时区：**所有时间戳以UTC毫秒存储，展示时根据用户timezone字段转换为本地时间。报表的"当月/当年"边界按用户本地时区计算。跨时区用户修改时区后，历史数据展示自动适配，不改变存储值。

**货币：**用户设置默认货币，项目可单独设置货币。MVP阶段不做汇率转换，多货币项目在报表中分别展示，不强行汇总。所有金额存储为原始数值\+货币代码，展示时按货币格式化（如USD显示$1,234\.56，EUR显示€1\.234,56）。

## 6\.5 PDF报表内容规范

### 月度报表PDF包含

1. 报表标题：Freelance Hub Monthly Report — \{Month Year\}

2. 用户信息：名称、邮箱、报表生成时间

3. 核心指标汇总：总工时、总收入、总开支、可抵扣开支、净收入

4. 按项目汇总表：项目名、客户、工时、收入

5. 按分类开支表：分类、金额、是否可抵扣

6. 每日工时明细表

7. 页脚：免责声明 \+ 页码

### 年度报税报表PDF包含

1. 报表标题：Freelance Hub Annual Tax Summary — \{Year\}

2. 用户信息

3. 年度核心指标：总收入、总工时、总开支、可抵扣开支、净收入、预估自雇税

4. 季度对比表：Q1\-Q4的收入/开支/工时

5. 按项目年度汇总表

6. 按税务类目汇总表（可抵扣/不可抵扣分开）

7. 月度趋势数据表

8. 完整免责声明（大字号，独立页面）

9. 页脚：页码 \+ 生成时间

## 6\.6 试用期与订阅到期处理

1. 首次购买Monthly/Annual自动开启7天免费试用，试用期间享受完整对应等级功能

2. 试用结束前3天，App启动时弹出温和提醒（不强制），订阅页显示倒计时

3. 试用结束未取消 → 自动转为正式付费订阅，开始扣费

4. 订阅到期（含试用结束未付费）→ RevenueCat触发EXPIRATION事件 → 后端更新premiumType=free → 客户端SDK监听到变更 → Provider刷新权限 → UI降级

5. 降级后：超过3个的项目仍可查看和编辑（不删除数据），但新建第4个项目被拦截；报表/同步/Web功能锁定

6. 降级后本地通知："Your subscription has ended\. Your data is safe and still accessible\. Upgrade anytime to restore premium features\."

# 7\. 安全与合规

## 7\.1 数据安全

|层面|措施|
|---|---|
|传输加密|所有API通信强制HTTPS（TLS 1\.2\+），禁止明文HTTP|
|密码存储|bcrypt哈希（cost factor=12），不存储明文密码|
|JWT安全|accessToken有效期1小时，refreshToken 30天且单次使用；Token存储在HttpOnly Cookie（Web）/安全存储（移动端Keystore/Keychain）|
|本地数据库|Hive支持加密，生产环境使用加密密钥（通过flutter\_secure\_storage存储），防止root设备直接读取|
|API限流|登录接口10次/分钟/IP，普通接口100次/分钟/用户，防止暴力破解和滥用|
|输入校验|后端所有接口参数校验（类型、长度、格式），防止注入和异常数据|
|SQL/NoSQL注入|Mongoose参数化查询，禁止拼接查询字符串|

## 7\.2 GDPR 合规要求

1. **知情权：**注册时明确告知收集哪些数据、用途、存储期限，隐私政策可随时查看

2. **访问权：**用户可在设置页导出自己的全部数据（JSON格式）

3. **删除权：**用户可注销账户，30天宽限期后永久删除所有数据（含备份中的数据）

4. **数据可携带权：**导出数据为通用格式（JSON/CSV），可迁移到其他服务

5. **同意撤回：**用户可随时撤回非必要数据收集同意（如崩溃分析、推送通知）

6. **数据处理协议：**若使用第三方服务（RevenueCat、MongoDB Atlas、云存储），需签署DPA

## 7\.3 隐私政策内容框架

隐私政策页面必须包含以下章节（Google Play上架强制要求）：

1. 收集的信息类型（账户信息、使用数据、设备信息）

2. 信息收集方式与目的

3. 信息共享与披露（是否共享给第三方，如RevenueCat）

4. 数据存储与安全措施

5. 数据保留期限

6. 用户权利（访问、更正、删除、导出）

7. Cookie与类似技术说明（Web端）

8. 儿童隐私（不面向13岁以下儿童）

9. 政策变更通知方式

10. 联系方式（邮箱）

## 7\.4 Google Play 数据安全表单

上架时需在Google Play Console填写数据安全声明，对应本App：

|数据类型|是否收集|是否加密|是否可删除|说明|
|---|---|---|---|---|
|邮箱地址|是|是（传输\+存储）|是|用于登录和账户识别|
|姓名|是|是|是|用户可选填写|
|财务信息|否（不经手）|—|—|支付由Google Play和RevenueCat处理，App不存储信用卡|
|位置信息|否|—|—|不收集GPS位置|
|应用使用数据|是（匿名）|是|是|崩溃日志和性能分析|
|设备ID|是|是|是|用于多端同步识别|

# 8\. 测试与验收

## 8\.1 单元测试策略

|模块|测试重点|工具|
|---|---|---|
|数据模型|Hive序列化/反序列化、字段默认值、类型转换|flutter\_test|
|计时器逻辑|状态转换、时长计算、异常恢复、暂停/继续|flutter\_test \+ fake\_async|
|权限逻辑|各等级功能开关、过期降级、试用期判断|flutter\_test|
|同步逻辑|增量上传/拉取、冲突解决（LWW）、离线队列|flutter\_test \+ mockito|
|报表计算|月度/年度数据聚合、可抵扣统计、金额计算精度|flutter\_test|
|后端接口|参数校验、权限拦截、错误码、同步逻辑|jest \+ supertest|

## 8\.2 Demo验收标准（参赛视频必须通过）

**以下检查项全部通过，方可录制参赛Demo视频：**

|\#|验收项|通过标准|
|---|---|---|
|1|预置数据完整|3个项目、12条工时、4笔开支全部正确显示，图表有数据|
|2|计时器可用|开始→暂停→继续→结束保存全流程正常，时长计算正确|
|3|开支录入|新增开支，选择分类，isTaxDeductible开关正常|
|4|Free版权限拦截|点击年度报表弹出升级引导，新建第4个项目被拦截|
|5|订阅购买（沙盒）|点击购买→RevenueCat沙盒支付→权限实时生效→报表可访问|
|6|PDF导出|Monthly本地生成PDF可预览，Annual云端生成可下载|
|7|订阅到期降级|沙盒模拟过期→高级功能锁定→本地数据完整保留|
|8|云端同步（Annual）|手机录入→Web后台可看到同步数据，双向增量同步|
|9|Web后台|Annual登录→大屏报表正常显示→批量导出可用|
|10|离线可用|断网状态下计时、录入、查看全部正常，恢复网络后自动同步|
|11|无崩溃|连续操作15分钟无闪退、无ANR|
|12|UI一致性|所有页面符合设计规范，无错位、无溢出、无默认Flutter样式残留|

## 8\.3 真机测试清单

|测试项|验证内容|
|---|---|
|多机型适配|至少测试小屏（5\.5寸）、大屏（6\.7寸）、平板各一台|
|Android版本|Android 10 / 12 / 14 各一台|
|后台计时|锁屏5分钟、切后台10分钟、杀进程后重启，计时不丢失|
|权限弹窗|通知权限、存储权限（PDF导出）正常引导|
|网络切换|WiFi→移动数据→断网→恢复，同步行为正确|
|深色模式|系统切换深色模式，所有页面适配无问题|
|字体缩放|系统字体放大到最大，无布局溢出|

# 9\. 打包、上架、参赛规范

## 9\.1 Android Release 打包规范

|项|规范|
|---|---|
|minSdkVersion|21（Android 5\.0，覆盖99%设备）|
|targetSdkVersion|34（Android 14，Google Play要求）|
|compileSdkVersion|34|
|应用包名|com\.freelancehub\.app|
|版本名|1\.0\.0|
|版本号|1|
|ProGuard|开启混淆，配置RevenueCat/Hive/dio等第三方库keep规则|
|签名|使用上传密钥签名（Google Play App Signing）|
|ABI|arm64\-v8a \+ armeabi\-v7a（覆盖主流设备）|
|权限|INTERNET、ACCESS\_NETWORK\_STATE、POST\_NOTIFICATIONS、FOREGROUND\_SERVICE、WAKE\_LOCK、RECEIVE\_BOOT\_COMPLETED|
|密钥配置|RevenueCat Production API Key、后端prod地址，不硬编码在代码中，通过\-\-dart\-define注入|

## 9\.2 Google Play 上架材料清单

1. App Bundle（\.aab）Release包2应用标题：Freelance Hub: Time \& Expense Tracker（最多30字符）3简短说明（最多80字符）：Track billable hours, expenses \& tax deductions for freelancers\.4完整说明（最多4000字符）：功能介绍、目标用户、订阅说明、免责声明5图标：512x512 PNG，圆角由Google Play处理6功能图：1024x500 PNG7手机截图：至少3张，1080x1920或类似比例87寸平板截图（可选，加分）9隐私政策URL（公开可访问网页）10数据安全表单填写（见7\.4）11内容分级问卷12目标受众（18\+，面向专业人士）

## 9\.3 参赛合规优势

- 无医疗、金融诊疗、版权等高风险敏感内容，审核风险极低

- 赛道全新无撞题，与往届获奖项目（户外识别、法律索赔、AI笔记）完全错开

- 完整商业化分层、7天试用、订阅到期优雅降级，完美契合HAMM评审

- 双端（Mobile\+Web）演示素材充足，产品成熟度远超普通单机Demo

- 离线优先架构，无网络也可完整演示核心功能，避免现场网络翻车

# 10\. 标准Demo模拟数据

## 10\.1 模拟用户

**Alex Morgan**｜US Freelance UI/Frontend Designer｜货币USD｜时区America/New\_York｜premiumType在Demo中切换演示

## 10\.2 预置项目（3个，Free版上限临界）

|\#|客户|项目|时薪|状态|
|---|---|---|---|---|
|1|Acme Corp|Website Redesign|$45/hr|active|
|2|StartupXYZ|Mobile UI Kit Design|$50/hr|active|
|3|Digital Agency Co\.|Design Consulting|$60/hr|active|

## 10\.3 预置工时数据（每项目4条，共12条，覆盖近30天）

|项目|日期|时长|标签|备注|金额|
|---|---|---|---|---|---|
|Website Redesign|近30天内|3\.5h|design|Homepage mockup iteration|$157\.50|
|Website Redesign|近30天内|4\.0h|dev|React component implementation|$180\.00|
|Website Redesign|近30天内|2\.5h|meeting|Client review call|$112\.50|
|Website Redesign|近30天内|5\.0h|design|Mobile responsive layouts|$225\.00|
|Mobile UI Kit|近30天内|6\.0h|design|Component library setup|$300\.00|
|Mobile UI Kit|近30天内|3\.0h|design|Icon set creation|$150\.00|
|Mobile UI Kit|近30天内|4\.5h|dev|Figma to Flutter export|$225\.00|
|Mobile UI Kit|近30天内|2\.0h|meeting|Stakeholder presentation|$100\.00|
|Design Consulting|近30天内|2\.0h|meeting|Brand strategy session|$120\.00|
|Design Consulting|近30天内|3\.5h|design|Design system audit|$210\.00|
|Design Consulting|近30天内|1\.5h|other|Email correspondence|$90\.00|
|Design Consulting|近30天内|4\.0h|design|Design guideline document|$240\.00|

**月度汇总：**总工时41\.5h｜总收入$2,110\.00

## 10\.4 预置可抵扣开支（全部标记Tax\-Deductible）

|商家|金额|分类|日期|
|---|---|---|---|
|Adobe Inc\.|$54\.99|Software \& Subscriptions|本月1日|
|Vercel Inc\.|$29\.99|Software \& Subscriptions|本月5日|
|Amazon Business|$89\.99|Hardware \& Equipment|本月10日|
|Comcast|$45\.00|Internet \& Phone|本月15日|

**月度开支汇总：**总开支$219\.97｜全部可抵扣｜净收入$1,890\.03

# 11\. 开发排期优先级

## P0 必做（Demo视频核心链路，优先开发）

|\#|任务|预估工时|依赖|
|---|---|---|---|
|1|Flutter工程初始化、Hive配置、模型定义|4h|—|
|2|Provider状态管理框架、路由配置|3h|1|
|3|RevenueCat SDK接入、权限Provider、PremiumGuard组件|6h|2|
|4|计时器核心（状态机\+后台保活\+通知）|8h|1,2|
|5|项目管理（增删改查\+Free版3个限制）|6h|1,2|
|6|开支记录（增删改查\+税务类目\+可抵扣标记）|6h|1,2|
|7|数据看板首页（预置数据展示）|5h|4,5,6|
|8|订阅会员页（三档展示\+沙盒购买\+恢复购买）|5h|3|
|9|月度报表页\+fl\_chart图表|6h|4,5,6|
|10|年度报表页（权限卡点\+免责声明）|4h|9|
|11|移动端本地PDF导出|5h|9,10|
|12|订阅到期降级逻辑\+UI刷新|4h|3|
|13|预置Demo数据导入脚本|2h|1|
|14|设置页、登录注册页|5h|2|

**P0合计：约74小时**

## P1 加分（视频观感提升，P0完成后开发）

|\#|任务|预估工时|
|---|---|---|
|1|图表美化与交互动画|4h|
|2|深色模式适配|6h|
|3|空状态/加载状态/错误状态完善|3h|
|4|表单校验与错误提示|3h|
|5|搜索与筛选功能|4h|

**P1合计：约20小时**

## P2 演示收尾（仅视频加分，无需精细打磨）

|\#|任务|预估工时|
|---|---|---|
|1|后端Express\+MongoDB搭建、JWT鉴权|8h|
|2|增量同步接口（项目/工时/开支）|8h|
|3|移动端SyncService（增量上传/拉取/冲突处理）|8h|
|4|RevenueCat Webhook回调接口|4h|
|5|后端报表聚合接口\+PDF批量生成|6h|
|6|Web后台Vue3工程\+登录页|4h|
|7|Web大屏报表页\+ECharts|8h|
|8|Web批量导出页|4h|

**P2合计：约50小时**

## 总工时估算

P0（74h）\+ P1（20h）\+ P2（50h）= **约144小时**。单人全职开发约3\-4周，建议P0必须全部完成，P1选择性做，P2至少完成同步\+Web大屏用于视频演示。

# 12\. 常见故障排查

|问题|可能原因|解决方案|
|---|---|---|
|RevenueCat购买无响应|沙盒账号未配置/未添加测试轨道/网络问题|确认Google Play内部测试轨道已添加测试账号，设备登录该Google账号，检查网络|
|订阅购买后权限未更新|SDK监听未生效/Provider未刷新/后端Webhook未收到|检查Purchases\.addCustomerInfoUpdateListener注册，手动调用getCustomerInfo刷新，检查RevenueCat Dashboard Webhook配置|
|计时器后台被杀死|国产ROM电池优化/未开启前台服务|启用Foreground Service显示持续通知，引导用户关闭电池优化，workmanager保活|
|同步数据冲突|多端同时编辑同一记录|LWW策略自动解决，极端冲突在设置页手动处理|
|PDF导出空白|中文/特殊字体缺失/数据为空|使用pdf包内置字体，确保有数据再导出，测试多内容场景|
|Hive数据库升级崩溃|模型字段变更未写迁移脚本/typeId冲突|新增字段给默认值，不要修改已有字段类型，typeId固定不重复|
|Google Play上架被拒|隐私政策URL不可访问/数据安全表单不一致/目标受众问题|确保隐私政策公网可访问，数据安全声明与实际收集一致，选择正确目标年龄段|
|Web后台非Annual也能访问|后端premium中间件未生效/前端未校验|检查接口是否经过premium中间件，Annual专属接口返回403，前端登录后校验entitlement|

### 新手开发常见问题

|问题|可能原因|解决方案|
|---|---|---|
|编译报错：\*\.g\.dart not found|未执行build\_runner生成Hive Adapter|在mobile目录执行 flutter pub run build\_runner build \-\-delete\-conflicting\-outputs|
|模拟器访问后端Connection refused|Android模拟器中localhost指向模拟器自身|API地址用10\.0\.2\.2:3000代替localhost:3000（框架已默认配置）|
|flutter run找不到设备|模拟器未启动/未开启USB调试|Android Studio → Device Manager → 启动模拟器，或连接真机开启USB调试|

---

Freelance Hub 开发文档 V2\.1 \| 最后更新：2026\-08\-13 \| 框架已搭建并修复6个问题，可直接开发

> （注：部分内容可能由 AI 生成）
