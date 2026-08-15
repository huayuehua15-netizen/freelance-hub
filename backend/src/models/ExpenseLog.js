const mongoose = require('mongoose');

const expenseLogSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true },
  expenseId: { type: String, required: true },
  projectId: { type: String, default: null },
  amount: { type: Number, required: true, min: 0 },
  currency: { type: String, default: 'USD' },
  expenseDate: { type: Number, required: true },
  category: { type: String, required: true },
  isTaxDeductible: { type: Boolean, default: true },
  merchant: { type: String, default: '' },
  note: { type: String, default: '' },
  receiptUrl: { type: String, default: '' },
  isDeleted: { type: Boolean, default: false },
}, {
  timestamps: { createdAt: 'serverCreateTime', updatedAt: 'serverUpdateTime' },
});

expenseLogSchema.index({ userId: 1, expenseId: 1 }, { unique: true });
expenseLogSchema.index({ userId: 1, serverUpdateTime: 1 });
expenseLogSchema.index({ userId: 1, expenseDate: 1 });

module.exports = mongoose.model('ExpenseLog', expenseLogSchema);
