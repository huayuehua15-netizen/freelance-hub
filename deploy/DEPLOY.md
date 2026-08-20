# Freelance Hub 生产后端部署指南（Render 免费托管）

面向 Google Play 正式上架。约 10 分钟完成，无需备案、自带 HTTPS 域名。

---

## 一、为什么不用大陆阿里云

- 阿里云大陆节点绑定域名必须 ICP 备案（个人约 1–3 周），`.app` 域名大陆基本不受理。
- 目标用户是欧美，访问大陆服务器延迟高，上架即差评。
- Render 免费层自带 HTTPS 域名（`xxx.onrender.com`），海外访问快，参赛/上架完全够用。

> 大陆阿里云服务器可留作他用，或暂不使用。

---

## 二、部署步骤

### 第 1 步：把代码推到 GitHub（Render 从仓库拉取）

```bash
cd C:\dev\freelance_hub
git init   # 若尚未初始化
git add backend deploy
git commit -m "chore: backend + render blueprint"
git remote add origin https://github.com/<你的账号>/freelance-hub.git
git push -u origin main
```

> 注意：`.env`、`key.properties`、`*.jks` 已在 .gitignore 中，不会上传（安全）。

### 第 2 步：Render 后台部署

1. 注册 [render.com](https://render.com)（可用 GitHub 账号登录）
2. 顶部 **New → Blueprint**
3. 连接你的 GitHub 仓库，选择 `deploy/render.yaml`
4. 按提示填写下面的**环境变量**（secrets）
5. 点 **Apply**，等 2–3 分钟构建完成

### 第 3 步：验证

浏览器访问 Render 给你的域名（形如 `https://freelance-hub-api.onrender.com/api/v1/health`），返回 `{"status":"ok","db":"connected",...}` 即成功。

---

## 三、环境变量清单（在 Render 后台填）

先生成 3 个生产密钥（Windows PowerShell 或 Git Bash 执行）：

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

执行 3 次，得到 3 个随机串，分别填入：

| 变量名 | 填什么 |
|---|---|
| `NODE_ENV` | `production` |
| `MONGODB_URI` | 你现有的 MongoDB Atlas 连接串（`backend/.env` 里那份） |
| `JWT_ACCESS_SECRET` | 随机串 ① |
| `JWT_REFRESH_SECRET` | 随机串 ② |
| `REVENUECAT_WEBHOOK_SECRET` | 随机串 ③（需与 RevenueCat 后台 webhook 一致） |
| `REVENUECAT_API_KEY` | RevenueCat 后台的 Secret API key（`sk_` 开头，配好 RC 后填） |
| `CLIENT_URL` | Web 后台地址（暂可填 `https://freelance-hub-api.onrender.com`） |
| `SMTP_HOST` | 你现有的 SMTP 主机（`backend/.env` 里那份） |
| `SMTP_PORT` | `587` |
| `SMTP_USER` | SMTP 用户名 |
| `SMTP_PASS` | SMTP 密码 |
| `SMTP_FROM` | 发件人（如 `Freelance Hub <no-reply@xxx.com>`） |

> `MONGODB_URI` 和 `SMTP_*` 直接从你本地 `backend/.env` 复制即可（值不变）。

---

## 四、拿到域名后回填

部署成功后你会得到一个形如 `https://freelance-hub-api.onrender.com` 的地址。

### 1. 构建正式 AAB（移动端）

```bash
cd C:\dev\freelance_hub\mobile
flutter build appbundle --release \
  --dart-define=ENV=prod \
  --dart-define=API_BASE_URL=https://freelance-hub-api.onrender.com/api/v1 \
  --dart-define=REVENUECAT_API_KEY=<RevenueCat 公开 SDK key>
```

### 2. 后端 webhook 地址

RevenueCat 后台 → Webhooks → 填 `https://freelance-hub-api.onrender.com/api/v1/webhook/revenuecat`

---

## 五、注意事项

- **Render 免费层会休眠**：15 分钟无请求会休眠，首次请求需 30–60 秒唤醒。可接受（参赛演示时提前访问一次即可）；如需常驻可升级 $7/月，或后续换 Railway。
- **数据库用 MongoDB Atlas**：已免费，与 Render 后端跨云互通，无需自建。
- **Web 后台**：Vue 构建产物可部署到 CloudStudio 或 Render Static Site，上架非必需（仅 Annual 用户增值），可后置。

---

## 六、上架冲刺倒排（目标 9 月中旬提交审核）

| 顺序 | 事项 | 状态 |
|---|---|---|
| 1 | 后端 Render 部署（本文档） | ⬜ 待做 |
| 2 | RevenueCat 生产配置（Play Console + RC 后台） | ⬜ 待做 |
| 3 | release AAB 构建 + 签名 | 🟡 签名已就绪，构建进行中 |
| 4 | 隐私政策 URL | ✅ 已部署 |
| 5 | 商店素材（图标/截图/描述）+ 数据安全表单 | ⬜ 待做 |
| 6 | Google Play Console 提交审核 | ⬜ 待做 |
