const mongoose = require('mongoose');

const timeLogSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true },
  timeLogId: { type: String, required: true },
  projectId: { type: String, required: true },
  startTime: { type: Number, required: true },
  endTime: { type: Number, default: null },
  duration: { type: Number, default: 0 },
  isBillable: { type: Boolean, default: true },
  billableAmount: { type: Number, default: 0 },
  tag: { type: String, default: '' },
  note: { type: String, default: '' },
  isDeleted: { type: Boolean, default: false },
}, {
  timestamps: { createdAt: 'serverCreateTime', updatedAt: 'serverUpdateTime' },
});

timeLogSchema.index({ userId: 1, timeLogId: 1 }, { unique: true });
timeLogSchema.index({ userId: 1, serverUpdateTime: 1 });
timeLogSchema.index({ userId: 1, startTime: 1 });

module.exports = mongoose.model('TimeLog', timeLogSchema);
