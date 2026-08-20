const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  userId: { type: String, required: true, unique: true, index: true },
  userEmail: { type: String, required: true, unique: true, sparse: true, lowercase: true, trim: true },
  userName: { type: String, default: '' },
  passwordHash: { type: String, required: true },
  currency: { type: String, default: 'USD' },
  timezone: { type: String, default: 'America/New_York' },
  premiumType: { type: String, enum: ['free', 'monthly', 'annual'], default: 'free' },
  expireTime: { type: Number, default: null },
  trialEndTime: { type: Number, default: null },
  lastSyncTime: { type: Number, default: 0 },
  refreshToken: { type: String, default: null },
  // 邮箱验证（非阻断）：token 只存哈希，明文仅出现在邮件链接中；24h 过期（与重置 token 对齐，见 authController VERIFY_TTL_MS）
  emailVerified: { type: Boolean, default: false },
  emailVerifyTokenHash: { type: String, default: null },
  emailVerifyExpiresAt: { type: Date, default: null },
  // 最后一次发送验证邮件时间：重发防轰炸的独立限频依据（勿复用 serverUpdateTime）
  lastVerificationSentAt: { type: Date, default: null },
  // 密码重置：token 哈希 + 1 小时过期
  resetTokenHash: { type: String, default: null },
  resetTokenExpiresAt: { type: Date, default: null },
  isDeleted: { type: Boolean, default: false },
  deletedAt: { type: Date, default: null },
}, {
  timestamps: { createdAt: 'serverCreateTime', updatedAt: 'serverUpdateTime' },
});

userSchema.index({ userEmail: 1, isDeleted: 1 });

module.exports = mongoose.model('User', userSchema);
