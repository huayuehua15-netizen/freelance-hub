const nodemailer = require('nodemailer');
const config = require('../config/env');
const logger = require('../utils/logger');

/**
 * 邮件服务：SMTP 通过环境变量配置（nodemailer）。
 *
 * 设计取舍：
 * - 未配置 SMTP 时服务不阻塞任何流程：注册/找回密码照常返回成功，
 *   验证/重置链接降级打印到服务端日志（开发模式可用），并在启动时
 *   按环境给出明确警告——绝不静默吞掉用户找回密码的能力。
 * - 邮件验证为非阻断式（注册即可用），发送失败不影响账户创建。
 */
let transporter = null;

const isConfigured = () =>
  !!(config.smtp.host && config.smtp.port && config.smtp.from);

function getTransporter() {
  if (!isConfigured()) return null;
  if (transporter) return transporter;
  transporter = nodemailer.createTransport({
    host: config.smtp.host,
    port: config.smtp.port,
    secure: config.smtp.port === 465,
    // 强制 STARTTLS：非 465 端口（587/2525 等）也必须走 TLS 加密，防验证/重置链接被中间人截获
    requireTLS: true,
    auth: config.smtp.user
      ? { user: config.smtp.user, pass: config.smtp.pass }
      : undefined,
  });
  return transporter;
}

/**
 * 发送邮件。返回 true/false，绝不抛错（调用方业务不依赖邮件成败）。
 */
async function sendMail({ to, subject, text, html }) {
  const tx = getTransporter();
  if (!tx) {
    // 未配置 SMTP：降级为日志输出（dev 可直接从日志取链接完成全流程测试）
    logger.info(`[email:dev-fallback] to=${to} subject="${subject}"\n${text}`);
    return false;
  }
  try {
    await tx.sendMail({
      from: config.smtp.from,
      to,
      subject,
      text,
      html,
    });
    return true;
  } catch (err) {
    logger.error(`[email] send failed to ${to}: ${err.message}`);
    return false;
  }
}

const brandWrap = (title, body, ctaLabel, ctaUrl, footer) => `
  <div style="font-family:Roboto,Arial,sans-serif;max-width:520px;margin:0 auto;padding:24px;border:1px solid #e2e8f0;border-radius:12px">
    <h2 style="color:#2563EB;margin:0 0 16px">Freelance Hub</h2>
    <p style="font-size:15px;color:#1e293b">${title}</p>
    <p style="font-size:14px;color:#475569;line-height:1.6">${body}</p>
    <p style="text-align:center;margin:24px 0">
      <a href="${ctaUrl}" style="background:#2563EB;color:#fff;padding:12px 28px;border-radius:8px;text-decoration:none;font-size:15px">${ctaLabel}</a>
    </p>
    <p style="font-size:12px;color:#94a3b8;word-break:break-all">Or copy this link: ${ctaUrl}</p>
    <hr style="border:none;border-top:1px solid #e2e8f0;margin:16px 0" />
    <p style="font-size:12px;color:#94a3b8">${footer}</p>
  </div>`;

async function sendVerificationEmail(user, verifyUrl) {
  return sendMail({
    to: user.userEmail,
    subject: 'Verify your email — Freelance Hub',
    text: `Welcome to Freelance Hub!\n\nVerify your email address: ${verifyUrl}\n\nIf you did not create this account, you can ignore this email.`,
    html: brandWrap(
      'Confirm your email address',
      'Welcome aboard! Click the button below to verify your email. Verification keeps your account recoverable and unlocks account support.',
      'Verify Email',
      verifyUrl,
      'If you did not sign up for Freelance Hub, please ignore this email.'
    ),
  });
}

async function sendPasswordResetEmail(user, resetUrl) {
  return sendMail({
    to: user.userEmail,
    subject: 'Reset your password — Freelance Hub',
    text: `A password reset was requested for your Freelance Hub account.\n\nReset your password: ${resetUrl}\n\nThis link expires in 1 hour. If you did not request this, your account is safe — no changes were made.`,
    html: brandWrap(
      'Password reset requested',
      'We received a request to reset the password for your account. Click the button below to choose a new one.',
      'Reset Password',
      resetUrl,
      'This link expires in 1 hour and can be used only once. If you did not request a reset, you can safely ignore this email.'
    ),
  });
}

module.exports = {
  isConfigured,
  sendMail,
  sendVerificationEmail,
  sendPasswordResetEmail,
};
