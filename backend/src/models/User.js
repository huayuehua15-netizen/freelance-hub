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
  isDeleted: { type: Boolean, default: false },
  deletedAt: { type: Date, default: null },
}, {
  timestamps: { createdAt: 'serverCreateTime', updatedAt: 'serverUpdateTime' },
});

userSchema.index({ userEmail: 1, isDeleted: 1 });

module.exports = mongoose.model('User', userSchema);
