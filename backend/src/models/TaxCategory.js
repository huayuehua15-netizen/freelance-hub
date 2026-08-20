const mongoose = require('mongoose');

/**
 * 税务分类模型
 * ===========================================================================
 * 设计理念：
 * - userId = null 表示系统默认分类（IRS Schedule C 标准类目，所有用户可见）
 * - userId = <具体用户> 表示用户自定义分类（仅该用户可见，Annual 会员专属）
 * - categoryId 是客户端同步用的稳定 ID（系统默认用固定 UUID，自定义用 UUIDv4）
 * - irsLine 对应 IRS Schedule C Part II 的行号，方便报税时对照
 * - 软删除（isDeleted）保持数据完整性，已使用的分类删除后历史开支仍可归类
 * ===========================================================================
 */
const taxCategorySchema = new mongoose.Schema({
  categoryId: { type: String, required: true },
  userId: { type: String, default: null, index: true },
  name: { type: String, required: true, trim: true, maxlength: 100 },
  // IRS Schedule C Part II 行号，自定义分类可为 null
  irsLine: { type: Number, default: null, min: 1, max: 99 },
  irsForm: { type: String, default: 'Schedule C' },
  // 是否可抵扣（用于报表统计可抵扣开支总额）
  isDeductible: { type: Boolean, default: true },
  // 是否用户自定义（系统默认 false）
  isCustom: { type: Boolean, default: false },
  isDeleted: { type: Boolean, default: false },
}, {
  timestamps: { createdAt: 'serverCreateTime', updatedAt: 'serverUpdateTime' },
});

// 复合唯一索引：同一用户（含系统 null）下 categoryId 唯一
// 系统默认分类的 userId 为 null，所有用户共享
taxCategorySchema.index({ userId: 1, categoryId: 1 }, { unique: true });

// 查询常用索引：按用户列出所有可用分类
taxCategorySchema.index({ userId: 1, isDeleted: 1 });

module.exports = mongoose.model('TaxCategory', taxCategorySchema);
