# Freelance Hub · 上架操作手册（Play Console + RevenueCat 配置指南）

> 用途：Google Play 开发者账号就绪后，按本手册逐项操作即可上架。
> 前置产物均已就绪：release AAB（69.6MB）、隐私政策（已公网部署）、商店文案/图标/Feature Graphic、签名密钥（见 SECRETS.md）。
> 最后更新：2026-08-21

---

## 一、全局速览（先读）

| 环节 | 依赖 | 状态 |
|---|---|---|
| ① Play 开发者账号注册 | 国际信用卡 $25 + 身份验证 | ⏸️ 用户暂缓 |
| ② 创建应用 + 上传 AAB | ① | 待做 |
| ③ 创建订阅产品 | ② | 待做 |
| ④ RevenueCat 连接 Google Play | ③（需 Play 服务账号 JSON） | 待做 |
| ⑤ Entitlement/Offering 映射 | ④ | 待做 |
| ⑥ Render 后端密钥回填 + webhook | ④ | 待做 |
| ⑦ 数据安全表单 / 内容分级 | ① | 模板已备（见下） |
| ⑧ 商店截图 3+ | 真机 | 可随时做 |

---

## 二、应用基础信息（②创建应用时填写）

### 0. 账号注册要点（①，重要）

**付款（$25 一次性）**：
- 支持 Mastercard / Visa / Amex，**不接受银联、预付卡、支付宝/微信**
- **不需要海外卡**：国内银行 Visa/Mastercard 双币/全币种信用卡即可（招行 Visa 全币种成功率最高，电话客服可办）
- 关键：卡支持境外美元交易 + 持卡人姓名与注册一致 + 预留手机能收境外验证码；支付失败勿连续重试（触发风控）

**⚠️ 新账号硬门槛（2023-11-13 后注册的个人账号）**：
- **12 人 / 14 天封闭测试**才能获得正式版发布权限——是目前新账号最大难关，建议注册后立即开始攒测试者（IP 分散，朋友/社区），与后续步骤并行

**地址验证**（注册时填中国大陆真实地址，精确到门牌号）：
- 最佳凭证：**银行对账单 PDF（近 60 天内，含地址）**——招行掌上生活 App 可在线补寄带地址的电子账单；3 次机会，失败不退 $25

**收款**（上线后有收入时）：
- 中国大陆账号绑定中国大陆储蓄卡（招行对美元汇入友好，默认支持外币入账+App 结汇）；年 5 万美元外汇额度
- 不建议用第三方结汇/虚拟卡做收款（Google 只认中国大陆银行卡）

| 项 | 值 |
|---|---|
| 应用名 | Freelance Hub |
| 包名 | `com.freelancehub.freelance_hub`（必须与 AAB 一致） |
| 语言 | English (United States) |
| 应用类型 | App / 应用 |
| 定价 | Free（应用免费下载，订阅内购） |
| 短描述（≤80字符） | Track billable hours, expenses & tax deductions for freelancers. |
| 完整描述 | 见 `deploy/store-listing.md`（≤4000 字符，含 CORE FEATURES / WHO IT'S FOR / PRICING / DISCLAIMER） |
| 类别 | Business → Productivity（参考，可微调） |
| 关键词 | time tracker, freelancer, billable hours, expense tracker, tax deduction, contractor, timesheet |

**上传 AAB**：`mobile\build\app\outputs\bundle\release\app-release.aab`（69.6MB）
- ⚠️ 上传后核对"App signing"页显示的 SHA-256 指纹与 `deploy/SECRETS.md` 记录一致（`81:2E:3F:F9:...`）
- ⚠️ 构建脚本 `build_release_aab.ps1` 中的 `SENTRY_DSN` 留空时崩溃上报禁用；上线前建议在 sentry.io 建项目并注入 DSN

**商店素材**（deploy/ 目录）：
| 素材 | 文件 | 规格 |
|---|---|---|
| 应用图标 | `play-store-icon-512.png` | 512×512 |
| Feature Graphic | `play-store-feature-graphic-1024x500.png` | 1024×500 |
| 手机截图 3+ | 待真机截取 | 1080×1920 竖屏 |

---

## 三、订阅产品（③创建）

Play Console → 应用 → **Monetize（变现）→ Products（产品）→ Create subscription**

| 产品 | 产品 ID（写进 Play） | 建议定价 | 免费试用 |
|---|---|---|---|
| 月度订阅 | `freelance_monthly` | $4.99 / 月 | 7 天 |
| 年度订阅 | `freelance_annual` | $39.99 / 年 | 7 天 |

> 产品 ID 可在 RevenueCat 里另起映射，但建议与 App 代码判定逻辑一致（后端 `tierFromProductId` 靠 productId 含 `annual`/`monthly` 判断档位——**ID 必须包含 annual 或 monthly 字样**）。

---

## 四、RevenueCat 配置（④⑤）

### 4.1 注册并创建项目
1. 注册 `https://app.revenuecat.com`（免费起步）
2. **Create App**：名称 `Freelance Hub`，平台 Android + 原生

### 4.2 连接 Google Play（④）
1. Play Console → 应用 → **Setup（设置）→ API access（API 访问权限）→ Create service account**
2. 按引导创建服务账号 → 下载 **JSON 密钥文件**（Google Cloud 控制台导出）
3. RevenueCat → **App Settings → Google Play** → 上传该 JSON
4. RevenueCat 自动拉取 Play 的订阅产品列表

### 4.3 Entitlements / Products / Offerings（⑤）
| 对象 | ID（必须与代码一致） | 说明 |
|---|---|---|
| Entitlement | `monthly_premium` | 月度权益（代码 `premium_provider.dart` 常量） |
| Entitlement | `annual_pro` | 年度权益 |
| Product 关联 | `freelance_monthly` → `monthly_premium` | 在 Products 页绑定 |
| Product 关联 | `freelance_annual` → `annual_pro` | 同上 |
| Offering | 默认 Offering | 月付/年付包放入（代码 `offering.monthly / offering.annual`） |

> 核对要点：Entitlement ID 必须与 `mobile/lib/providers/premium_provider.dart` 中 `_monthlyEntitlement = 'monthly_premium'`、`_annualEntitlement = 'annual_pro'` **逐字一致**。

### 4.4 密钥（⑥，均在 `backend/.env` 已有值）
| 变量 | 值来源 | 用途 |
|---|---|---|
| `REVENUECAT_API_KEY` | `.env` 中 `sk_` 开头 | 后端 REST（回填 Render） |
| `REVENUECAT_WEBHOOK_SECRET` | `.env` | webhook HMAC 校验 |
| 移动端 SDK key | `goog_` 开头 | 已写入 AAB 构建，无需再动 |

**Render 回填**：Render 后台 → 服务 → Environment → 添加 `REVENUECAT_API_KEY` 与 `REVENUECAT_WEBHOOK_SECRET` → 部署。

### 4.5 Webhook（⑥）
RevenueCat → **Webhooks** 页面：
- URL：`https://freelance-hub-api-f2gn.onrender.com/api/v1/webhook/revenuecat`
- Authorization：填 `REVENUECAT_WEBHOOK_SECRET` 对应值（Bearer 形式按 RC 页面提示）
- 事件：全选（INITIAL_PURCHASE / RENEWAL / EXPIRATION / CANCELLATION / PRODUCT_CHANGE 等）
- 后端已实现：HMAC 签名校验（任何环境）+ 幂等去重（WebhookEvent 唯一索引）+ 档位单调性守卫

**验证**：RevenueCat 后台可发送 Test event → 后端日志应出现 `Duplicate webhook event`（重复投递）或 `premium updated`。

---

## 五、数据安全表单（⑦，Play 审核必填）

> Play Console → App content（应用内容）→ Data safety（数据安全）

| 问题 | 回答模板 |
|---|---|
| 是否收集数据？ | 是 |
| 数据类型 | **个人数据**：邮箱、用户名（账号体系必需）；购买记录（订阅状态，由 Google 结算承载）；用户生成内容（工时/开支/项目记录，核心功能） |
| 数据是否加密传输 | 是（HTTPS） |
| 数据是否可以删除 | 是（App 内"删除账号"入口 + 30 天宽限期后物理删除，GDPR 合规） |
| 是否与第三方共享 | 否（除结算必需：RevenueCat/Google Play） |
| 数据用途 | 账号与身份、应用功能、个性化（货币/时区偏好） |

## 六、内容分级问卷（⑦）

> Play Console → App content → Content ratings

| 问题 | 答案 |
|---|---|
| 是否包含成人/性内容 | 否 |
| 是否包含暴力 | 否 |
| 是否包含赌博 | 否 |
| 是否收集个人数据 | 是（账号/开支记录，不影响分级） |
| 是否允许用户生成内容分享 | 否（数据仅本人可见） |
| 预期评级 | 适合所有人（Everyone） |

**目标受众声明**：非儿童应用（非 child-directed），不面向 13 岁以下。

---

## 七、真机购买测试清单（AAB 上线后内部测试）

1. Play Console 发布到**内部测试通道**（Internal testing），添加测试邮箱
2. 测试机加入测试组 → 安装 AAB
3. 购买月度：Google 弹窗 → 沙盒付款 → 立即变 monthly
4. 购买年度：立即变 annual → Cloud Sync / Web 看板解锁
5. 取消订阅：CANCELLATION 事件 → 权益保留至到期
6. 退款（沙盒）：CANCELLATION + CUSTOMER_SUPPORT → 立即降级
7. 过期：EXPIRATION 事件 → premiumType 变 free
8. 后端日志核对：`premium updated` / `expired` / `Duplicate webhook event`

---

## 八、状态追踪（填进度用）

- [ ] ① Play 账号注册（暂缓）
- [ ] ② 创建应用 + 上传 AAB + 核对签名指纹
- [ ] ③ 创建订阅产品（freelance_monthly / freelance_annual）
- [ ] ④ RevenueCat 连接 Play（服务账号 JSON）
- [ ] ⑤ Entitlement/Product/Offering 映射
- [ ] ⑥ Render 环境变量回填 + webhook 配置
- [ ] ⑦ 数据安全表单 + 内容分级 + 目标受众
- [ ] ⑧ 商店截图 3+ 张
- [ ] 提交审核 → 上架

---

> 本手册为机密内部文档（含操作细节），与 `SECRETS.md` 同目录；如需入库需确认无敏感信息。
