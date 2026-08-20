const mongoose = require('mongoose');

// RevenueCat webhook 事件幂等去重表。
// RC 保证 at-least-once 投递且重试复用同一 event.id —— 唯一索引让重复
// 投递在插入时即失败，调用方据此直接返回 200，防止重放续命会员。
const webhookEventSchema = new mongoose.Schema({
  eventId: { type: String, required: true, unique: true },
  type: { type: String, required: true },
  appUserId: { type: String, required: true },
  receivedAt: { type: Date, default: Date.now },
});

// 保留 90 天审计痕迹；cleanupService 定期清理过期行。
webhookEventSchema.index({ receivedAt: 1 }, { expireAfterSeconds: 90 * 24 * 3600 });

module.exports = mongoose.model('WebhookEvent', webhookEventSchema);
