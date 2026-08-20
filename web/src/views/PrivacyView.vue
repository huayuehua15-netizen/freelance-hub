<template>
  <div class="privacy-page">
    <header class="privacy-header">
      <div class="header-inner">
        <router-link to="/login" class="back-link">
          <el-icon><svg viewBox="0 0 24 24" width="16" height="16"><path fill="currentColor" d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"/></svg></el-icon>
          {{ t('privacy.backToLogin') }}
        </router-link>
        <el-dropdown @command="handleLocaleCommand" trigger="click">
          <span class="locale-trigger">
            {{ localeLabel }}
            <el-icon><svg viewBox="0 0 24 24" width="14" height="14"><path fill="currentColor" d="m7 10 5 5 5-5z"/></svg></el-icon>
          </span>
          <template #dropdown>
            <el-dropdown-menu>
              <el-dropdown-item command="en" :disabled="locale === 'en'">English</el-dropdown-item>
              <el-dropdown-item command="zh" :disabled="locale === 'zh'">中文</el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
      </div>
    </header>

    <main class="privacy-content">
      <div class="doc-container">
        <h1>{{ t('privacy.title') }}</h1>
        <p class="last-updated">{{ t('privacy.lastUpdated') }}: 2026-08-16</p>

        <!-- English version -->
        <div v-if="locale === 'en'">
          <section>
            <h2>1. Introduction</h2>
            <p>Freelance Hub ("we," "us," or "our") operates a mobile application and web dashboard (the "Service") that helps freelancers and independent contractors track work hours, manage projects, record expenses, and generate tax reports. This Privacy Policy explains what data we collect, how we use it, and the rights you have over your data.</p>
            <p>By using the Service, you agree to the collection and use of information in accordance with this policy. This Service is provided to users located in the United States, the European Economic Area (EEA), the United Kingdom, and other regions where it is legally available.</p>
          </section>

          <section>
            <h2>2. Information We Collect</h2>
            <h3>2.1 Information You Provide</h3>
            <ul>
              <li><strong>Account information:</strong> Email address (used as your login identifier), an optional display name, and a password. Passwords are never stored in plain text — they are securely hashed using bcrypt before being saved to our database.</li>
              <li><strong>Business data:</strong> Projects you create (names, hourly rates, statuses), time logs (start/end times, durations, billable flags, tags, notes), expense records (amounts, categories, merchants, tax-deductible status, notes), and tax category preferences.</li>
              <li><strong>Preferences:</strong> Your selected currency (e.g., USD, EUR), timezone (e.g., America/New_York), and display language.</li>
            </ul>
            <h3>2.2 Information Collected Automatically</h3>
            <ul>
              <li><strong>Device identifier:</strong> A randomly generated device ID is used solely to deduplicate data when syncing across multiple devices. It is not linked to your personal identity.</li>
              <li><strong>Usage data:</strong> We may collect aggregated, anonymized analytics about app performance and feature usage to improve the Service. This data cannot be used to identify you personally.</li>
              <li><strong>Subscription status:</strong> Your subscription plan (Free, Monthly, or Annual) and expiration time, managed through Google Play Billing and RevenueCat.</li>
            </ul>
            <h3>2.3 Information We Do NOT Collect</h3>
            <ul>
              <li>We do <strong>not</strong> collect your precise GPS location.</li>
              <li>We do <strong>not</strong> access your contacts, photos, or camera unless you explicitly use a feature that requires it (and you will be asked for permission at that time).</li>
              <li>We do <strong>not</strong> sell your personal data to third parties under any circumstances.</li>
            </ul>
          </section>

          <section>
            <h2>3. How We Use Your Information</h2>
            <ul>
              <li>To provide the Service: authenticate your account, store and sync your projects, time logs, and expenses across devices.</li>
              <li>To generate tax reports: calculate billable income, deductible expenses, estimated self-employment tax, and quarterly summaries based on your timezone.</li>
              <li>To manage your subscription: verify entitlements, process billing through Google Play, and grant or restrict premium features accordingly.</li>
              <li>To communicate with you: send service notifications (e.g., timer reminders, sync status), respond to support requests, and notify you of important policy changes.</li>
              <li>To improve the Service: analyze aggregated usage patterns to identify bugs and prioritize new features.</li>
            </ul>
          </section>

          <section>
            <h2>4. Legal Basis for Processing (GDPR)</h2>
            <p>If you are located in the EEA or UK, we process your personal data under the following legal bases:</p>
            <ul>
              <li><strong>Performance of a contract (Art. 6(1)(b)):</strong> Processing your account and business data is necessary to deliver the Service you requested.</li>
              <li><strong>Legal obligation (Art. 6(1)(c)):</strong> We may retain certain records to comply with tax or accounting regulations.</li>
              <li><strong>Legitimate interests (Art. 6(1)(f)):</strong> We use aggregated analytics to improve security and service quality.</li>
              <li><strong>Consent (Art. 6(1)(a)):</strong> For any optional data collection (e.g., push notifications), we seek your explicit consent, which you may withdraw at any time.</li>
            </ul>
          </section>

          <section>
            <h2>5. Data Storage and Security</h2>
            <p>Your data is stored in encrypted MongoDB Atlas database clusters hosted on cloud infrastructure. All data in transit is protected using TLS/HTTPS encryption. Passwords are hashed using bcrypt with a work factor of 12. Authentication tokens (JWT) are signed with secrets stored only in server-side environment variables and have limited lifetimes (access tokens expire in 1 hour).</p>
            <p>We implement reasonable technical and organizational measures to protect your data, including: role-based access controls, security headers (CSP, HSTS), rate limiting, and regular security reviews. However, no method of transmission or storage is 100% secure, and we cannot guarantee absolute security.</p>
          </section>

          <section>
            <h2>6. Third-Party Services</h2>
            <p>We use the following third-party services that may have access to limited personal data:</p>
            <ul>
              <li><strong>MongoDB Atlas:</strong> Cloud database hosting. Processes your business data on our behalf as a data processor. <a href="https://www.mongodb.com/legal/privacy-policy" target="_blank" rel="noopener">Privacy Policy</a>.</li>
              <li><strong>RevenueCat:</strong> Subscription management and entitlement verification. Receives anonymous app user IDs and purchase receipts. <a href="https://www.revenuecat.com/privacy" target="_blank" rel="noopener">Privacy Policy</a>.</li>
              <li><strong>Google Play Billing:</strong> Processes in-app purchases. Google handles all payment information; we never see your credit card or payment details. <a href="https://policies.google.com/privacy" target="_blank" rel="noopener">Privacy Policy</a>.</li>
            </ul>
            <p>These third parties are bound by their own privacy policies and are prohibited from using your data for unrelated purposes.</p>
          </section>

          <section>
            <h2>7. Data Retention</h2>
            <p>We retain your data for as long as your account is active. When you request account deletion:</p>
            <ul>
              <li>Your account is immediately deactivated and you can no longer log in.</li>
              <li>A 30-day grace period begins, during which you can contact us to restore your account and recover all data.</li>
              <li>After 30 days, your account and all associated data (projects, time logs, expenses, preferences) are <strong>permanently and irreversibly deleted</strong> from our database via a cascading deletion process.</li>
            </ul>
            <p>If your subscription expires but your account remains active, we retain your data so you can resubscribe and continue where you left off. Free-tier users retain access to all historical data, with only the current month's detailed views available in the mobile app.</p>
          </section>

          <section>
            <h2>8. Your Rights</h2>
            <h3>8.1 GDPR Rights (EEA & UK Users)</h3>
            <ul>
              <li><strong>Right of access:</strong> Request a copy of your personal data via the in-app CSV export feature.</li>
              <li><strong>Right to rectification:</strong> Edit your profile, projects, time logs, and expenses at any time within the app.</li>
              <li><strong>Right to erasure:</strong> Delete your account from Settings. Data is permanently removed after the 30-day grace period.</li>
              <li><strong>Right to data portability:</strong> Export all your data in CSV format (time logs and expenses for any selected year).</li>
              <li><strong>Right to object:</strong> Disable push notifications or specific data processing at any time.</li>
              <li><strong>Right to withdraw consent:</strong> Revoke any consent-based processing (e.g., notifications) without affecting the core Service.</li>
            </ul>
            <h3>8.2 CCPA Rights (California Users)</h3>
            <ul>
              <li><strong>Right to know:</strong> What personal information we collect and how it is used (detailed in Sections 2 and 3).</li>
              <li><strong>Right to delete:</strong> Request deletion of your personal information via account deletion.</li>
              <li><strong>Right to opt-out of sale:</strong> We do not sell your personal information, so no opt-out is necessary. This statement serves as our "Do Not Sell My Personal Information" declaration.</li>
              <li><strong>Right to non-discrimination:</strong> We will not discriminate against you for exercising any of these rights.</li>
            </ul>
            <p>To exercise any of these rights, contact us at <a href="mailto:privacy@freelancehub.app">privacy@freelancehub.app</a>. We will respond within 30 days (GDPR) or 45 days (CCPA).</p>
          </section>

          <section>
            <h2>9. Cookies and Local Storage</h2>
            <p>The mobile app does not use cookies. The web dashboard uses browser <strong>localStorage</strong> to store your authentication token and language preference so you remain logged in across page reloads. This data never leaves your browser except to authenticate API requests. We do not use tracking cookies, advertising cookies, or third-party analytics cookies.</p>
          </section>

          <section>
            <h2>10. Children's Privacy</h2>
            <p>The Service is not directed to children under the age of 13 (COPPA) or 16 (GDPR). We do not knowingly collect personal information from children. If you believe a child has provided us with personal data, please contact us and we will promptly delete it.</p>
          </section>

          <section>
            <h2>11. International Data Transfers</h2>
            <p>Your data may be processed in countries other than your own, including the United States. When transferring data from the EEA or UK, we rely on appropriate safeguards such as Standard Contractual Clauses (SCCs) to ensure a level of data protection equivalent to that in your home region.</p>
          </section>

          <section>
            <h2>12. Changes to This Policy</h2>
            <p>We may update this Privacy Policy from time to time. We will notify you of material changes by displaying a notice in the app or by sending an email to your registered address. The "Last Updated" date at the top of this page indicates when the policy was last revised. Continued use of the Service after changes take effect constitutes acceptance of the updated policy.</p>
          </section>

          <section>
            <h2>13. Contact Us</h2>
            <p>If you have questions, concerns, or requests regarding this Privacy Policy or your personal data, please contact us:</p>
            <ul>
              <li>Email: <a href="mailto:privacy@freelancehub.app">privacy@freelancehub.app</a></li>
              <li>Subject line: "Privacy Policy Inquiry"</li>
            </ul>
            <p>We are committed to resolving your privacy concerns promptly and transparently.</p>
          </section>
        </div>

        <!-- 中文版本 -->
        <div v-else>
          <section>
            <h2>1. 引言</h2>
            <p>Freelance Hub（以下简称"我们"）运营一款移动应用和 Web 仪表板（以下简称"服务"），帮助自由职业者和独立承包商记录工时、管理项目、记录开支并生成税务报表。本隐私政策说明了我们收集哪些数据、如何使用这些数据，以及您对自身数据拥有的权利。</p>
            <p>使用本服务即表示您同意按照本政策收集和使用信息。本服务面向美国、欧洲经济区（EEA）、英国及其他合法可用地区的用户。</p>
          </section>

          <section>
            <h2>2. 我们收集的信息</h2>
            <h3>2.1 您主动提供的信息</h3>
            <ul>
              <li><strong>账户信息：</strong>邮箱地址（用作登录标识）、可选的显示名称和密码。密码绝不以明文存储——在保存到数据库前使用 bcrypt 进行安全哈希处理。</li>
              <li><strong>业务数据：</strong>您创建的项目（名称、时薪、状态）、工时记录（开始/结束时间、时长、计费标记、标签、备注）、开支记录（金额、类目、商家、可抵扣状态、备注）和税务类目偏好。</li>
              <li><strong>偏好设置：</strong>您选择的货币（如 USD、EUR）、时区（如 America/New_York）和显示语言。</li>
            </ul>
            <h3>2.2 自动收集的信息</h3>
            <ul>
              <li><strong>设备标识符：</strong>随机生成的设备 ID，仅用于跨设备同步时去重，不与您的个人身份关联。</li>
              <li><strong>使用数据：</strong>我们可能收集聚合的、匿名的应用性能和功能使用分析数据，以改进服务。该数据无法用于识别您的个人身份。</li>
              <li><strong>订阅状态：</strong>您的订阅计划（免费、月度或年度）和到期时间，通过 Google Play Billing 和 RevenueCat 管理。</li>
            </ul>
            <h3>2.3 我们不收集的信息</h3>
            <ul>
              <li>我们<strong>不</strong>收集您的精确 GPS 位置。</li>
              <li>除非您明确使用需要该权限的功能（届时会向您请求权限），否则我们<strong>不</strong>访问您的通讯录、照片或相机。</li>
              <li>我们在任何情况下都<strong>不</strong>向第三方出售您的个人数据。</li>
            </ul>
          </section>

          <section>
            <h2>3. 我们如何使用您的信息</h2>
            <ul>
              <li>提供服务：验证您的账户，跨设备存储和同步您的项目、工时记录和开支。</li>
              <li>生成税务报表：根据您的时区计算计费收入、可抵扣开支、预估自雇税和季度汇总。</li>
              <li>管理订阅：验证权益，通过 Google Play 处理计费，并据此授予或限制高级功能。</li>
              <li>与您沟通：发送服务通知（如计时器提醒、同步状态），回复支持请求，通知您重要的政策变更。</li>
              <li>改进服务：分析聚合的使用模式以识别 bug 并优先开发新功能。</li>
            </ul>
          </section>

          <section>
            <h2>4. 处理的法律依据（GDPR）</h2>
            <p>如果您位于 EEA 或英国，我们在以下法律依据下处理您的个人数据：</p>
            <ul>
              <li><strong>履行合同（第6(1)(b)条）：</strong>处理您的账户和业务数据是提供您所请求的服务所必需的。</li>
              <li><strong>法律义务（第6(1)(c)条）：</strong>我们可能保留某些记录以遵守税务或会计法规。</li>
              <li><strong>合法利益（第6(1)(f)条）：</strong>我们使用聚合分析来改善安全性和服务质量。</li>
              <li><strong>同意（第6(1)(a)条）：</strong>对于任何可选的数据收集（如推送通知），我们寻求您的明确同意，您可随时撤回。</li>
            </ul>
          </section>

          <section>
            <h2>5. 数据存储与安全</h2>
            <p>您的数据存储在托管于云基础设施的加密 MongoDB Atlas 数据库集群中。传输中的所有数据均使用 TLS/HTTPS 加密保护。密码使用工作因子为 12 的 bcrypt 进行哈希处理。身份验证令牌（JWT）使用仅存储在服务器端环境变量中的密钥签名，且具有有限的生命周期（访问令牌 1 小时后过期）。</p>
            <p>我们采取合理的技术和组织措施来保护您的数据，包括：基于角色的访问控制、安全头（CSP、HSTS）、速率限制和定期安全审查。然而，没有任何传输或存储方法是 100% 安全的，我们无法保证绝对安全。</p>
          </section>

          <section>
            <h2>6. 第三方服务</h2>
            <p>我们使用以下可能访问有限个人数据的第三方服务：</p>
            <ul>
              <li><strong>MongoDB Atlas：</strong>云数据库托管。作为数据处理者代表我们处理您的业务数据。<a href="https://www.mongodb.com/legal/privacy-policy" target="_blank" rel="noopener">隐私政策</a>。</li>
              <li><strong>RevenueCat：</strong>订阅管理和权益验证。接收匿名应用用户 ID 和购买凭证。<a href="https://www.revenuecat.com/privacy" target="_blank" rel="noopener">隐私政策</a>。</li>
              <li><strong>Google Play Billing：</strong>处理应用内购买。Google 处理所有支付信息；我们绝不会看到您的信用卡或支付详情。<a href="https://policies.google.com/privacy" target="_blank" rel="noopener">隐私政策</a>。</li>
            </ul>
            <p>这些第三方受其自身隐私政策约束，并被禁止将您的数据用于无关目的。</p>
          </section>

          <section>
            <h2>7. 数据保留</h2>
            <p>只要您的账户处于活跃状态，我们就会保留您的数据。当您请求删除账户时：</p>
            <ul>
              <li>您的账户将立即停用，您将无法再登录。</li>
              <li>开始 30 天的宽限期，在此期间您可以联系我们恢复账户并恢复所有数据。</li>
              <li>30 天后，您的账户及所有关联数据（项目、工时记录、开支、偏好）将通过级联删除流程从我们的数据库中<strong>永久且不可逆地删除</strong>。</li>
            </ul>
            <p>如果您的订阅过期但账户保持活跃，我们将保留您的数据，以便您重新订阅后继续使用。免费用户可保留对所有历史数据的访问权限，但移动应用中仅当月的详细视图可用。</p>
          </section>

          <section>
            <h2>8. 您的权利</h2>
            <h3>8.1 GDPR 权利（EEA 和英国用户）</h3>
            <ul>
              <li><strong>访问权：</strong>通过应用内 CSV 导出功能请求获取您的个人数据副本。</li>
              <li><strong>更正权：</strong>随时在应用内编辑您的个人资料、项目、工时记录和开支。</li>
              <li><strong>删除权：</strong>从设置中删除您的账户。数据将在 30 天宽限期后永久删除。</li>
              <li><strong>可携带权：</strong>以 CSV 格式导出您所有选定年份的数据（工时记录和开支）。</li>
              <li><strong>反对权：</strong>随时禁用推送通知或特定数据处理。</li>
              <li><strong>撤回同意权：</strong>撤回任何基于同意的处理（如通知），不影响核心服务的使用。</li>
            </ul>
            <h3>8.2 CCPA 权利（加州用户）</h3>
            <ul>
              <li><strong>知情权：</strong>了解我们收集哪些个人信息以及如何使用（详见第 2 和第 3 节）。</li>
              <li><strong>删除权：</strong>通过账户删除请求删除您的个人信息。</li>
              <li><strong>选择不出售权：</strong>我们不出售您的个人信息，因此无需选择退出。本声明即作为我们的"请勿出售我的个人信息"声明。</li>
              <li><strong>不受歧视权：</strong>我们不会因您行使上述任何权利而歧视您。</li>
            </ul>
            <p>如需行使上述任何权利，请通过 <a href="mailto:privacy@freelancehub.app">privacy@freelancehub.app</a> 联系我们。我们将在 30 天内（GDPR）或 45 天内（CCPA）回复。</p>
          </section>

          <section>
            <h2>9. Cookie 和本地存储</h2>
            <p>移动应用不使用 Cookie。Web 仪表板使用浏览器 <strong>localStorage</strong> 存储您的身份验证令牌和语言偏好，以便您在页面刷新后保持登录状态。此数据除用于验证 API 请求外，绝不会离开您的浏览器。我们不使用跟踪 Cookie、广告 Cookie 或第三方分析 Cookie。</p>
          </section>

          <section>
            <h2>10. 儿童隐私</h2>
            <p>本服务不面向 13 岁以下（COPPA）或 16 岁以下（GDPR）的儿童。我们不会故意收集儿童的个人信息。如果您认为儿童已向我们提供了个人数据，请联系我们，我们将立即删除。</p>
          </section>

          <section>
            <h2>11. 国际数据传输</h2>
            <p>您的数据可能在您所在国家以外的国家处理，包括美国。当从 EEA 或英国传输数据时，我们依靠标准合同条款（SCC）等适当保障措施，确保数据保护水平与您所在地区相当。</p>
          </section>

          <section>
            <h2>12. 政策变更</h2>
            <p>我们可能不时更新本隐私政策。我们将通过在应用中显示通知或向您注册的邮箱发送电子邮件来通知您重大变更。本页面顶部的"最后更新"日期表示政策最后修订的时间。变更生效后继续使用服务即表示接受更新后的政策。</p>
          </section>

          <section>
            <h2>13. 联系我们</h2>
            <p>如果您对本隐私政策或您的个人数据有任何疑问、疑虑或请求，请通过以下方式联系我们：</p>
            <ul>
              <li>邮箱：<a href="mailto:privacy@freelancehub.app">privacy@freelancehub.app</a></li>
              <li>邮件主题："隐私政策咨询"</li>
            </ul>
            <p>我们致力于及时、透明地解决您的隐私关切。</p>
          </section>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useLocaleStore } from '../stores/locale'

const { t } = useI18n()
const localeStore = useLocaleStore()

const locale = computed(() => localeStore.locale)
const localeLabel = computed(() => (locale.value === 'zh' ? '中文' : 'English'))

const handleLocaleCommand = (cmd) => {
  if (cmd === 'en' || cmd === 'zh') {
    localeStore.setLocale(cmd)
  }
}
</script>

<style scoped>
.privacy-page {
  min-height: 100vh;
  background: #f8fafc;
}
.privacy-header {
  background: #fff;
  border-bottom: 1px solid #e2e8f0;
  position: sticky;
  top: 0;
  z-index: 10;
}
.header-inner {
  max-width: 820px;
  margin: 0 auto;
  padding: 14px 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.back-link {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: #64748b;
  text-decoration: none;
  font-size: 14px;
  font-weight: 500;
}
.back-link:hover {
  color: #2563eb;
}
.locale-trigger {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  cursor: pointer;
  color: #64748b;
  padding: 6px 10px;
  border-radius: 6px;
  border: 1px solid #e2e8f0;
  background: #fff;
  font-size: 13px;
}
.locale-trigger:hover {
  background: #f1f5f9;
}
.privacy-content {
  padding: 32px 24px 64px;
}
.doc-container {
  max-width: 820px;
  margin: 0 auto;
  background: #fff;
  border-radius: 12px;
  padding: 48px 56px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.04);
}
.doc-container h1 {
  font-size: 28px;
  font-weight: 700;
  color: #0f172a;
  margin-bottom: 8px;
}
.last-updated {
  color: #94a3b8;
  font-size: 13px;
  margin-bottom: 32px;
  padding-bottom: 20px;
  border-bottom: 1px solid #f1f5f9;
}
.doc-container section {
  margin-bottom: 28px;
}
.doc-container h2 {
  font-size: 18px;
  font-weight: 600;
  color: #1e293b;
  margin-bottom: 12px;
}
.doc-container h3 {
  font-size: 15px;
  font-weight: 600;
  color: #334155;
  margin-top: 16px;
  margin-bottom: 8px;
}
.doc-container p {
  color: #475569;
  line-height: 1.7;
  font-size: 14px;
  margin-bottom: 10px;
}
.doc-container ul {
  list-style: disc;
  padding-left: 22px;
  margin-bottom: 10px;
}
.doc-container li {
  color: #475569;
  line-height: 1.7;
  font-size: 14px;
  margin-bottom: 6px;
}
.doc-container strong {
  color: #1e293b;
  font-weight: 600;
}
.doc-container a {
  color: #2563eb;
  text-decoration: none;
}
.doc-container a:hover {
  text-decoration: underline;
}
@media (max-width: 640px) {
  .privacy-content {
    padding: 16px 12px 40px;
  }
  .doc-container {
    padding: 28px 20px;
  }
  .doc-container h1 {
    font-size: 22px;
  }
  .doc-container h2 {
    font-size: 16px;
  }
}
</style>
