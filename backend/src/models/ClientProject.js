const mongoose = require('mongoose');

const clientProjectSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true },
  projectId: { type: String, required: true },
  clientName: { type: String, required: true },
  clientEmail: { type: String, default: '' },
  projectName: { type: String, required: true },
  hourlyRate: { type: Number, required: true, min: 0 },
  currency: { type: String, default: 'USD' },
  status: { type: String, enum: ['active', 'archived', 'completed'], default: 'active' },
  isDeleted: { type: Boolean, default: false },
}, {
  timestamps: { createdAt: 'serverCreateTime', updatedAt: 'serverUpdateTime' },
});

clientProjectSchema.index({ userId: 1, projectId: 1 }, { unique: true });
clientProjectSchema.index({ userId: 1, serverUpdateTime: 1 });

module.exports = mongoose.model('ClientProject', clientProjectSchema);
