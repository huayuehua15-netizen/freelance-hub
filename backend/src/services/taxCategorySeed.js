const TaxCategory = require('../models/TaxCategory');
const logger = require('../utils/logger');

/**
 * IRS Schedule C Part II 标准税务分类（10 个最常用类目）
 * ===========================================================================
 * 数据来源：IRS Form 1040 Schedule C (2024) Part II - Expenses
 * https://www.irs.gov/forms-pubs/about-schedule-c-form-1040
 *
 * 这 10 个类目覆盖了自由职业者 90%+ 的开支类型，按 IRS 官方行号归类，
 * 用户报税时可直接对照 Schedule C 填写，无需手动查找。
 * ===========================================================================
 */
const DEFAULT_TAX_CATEGORIES = [
  {
    categoryId: 'sys-advertising',
    name: 'Advertising',
    irsLine: 8,
    isDeductible: true,
    isCustom: false,
  },
  {
    categoryId: 'sys-car-truck',
    name: 'Car and Truck Expenses',
    irsLine: 9,
    isDeductible: true,
    isCustom: false,
  },
  {
    categoryId: 'sys-contract-labor',
    name: 'Contract Labor',
    irsLine: 11,
    isDeductible: true,
    isCustom: false,
  },
  {
    categoryId: 'sys-depreciation',
    name: 'Depreciation',
    irsLine: 13,
    isDeductible: true,
    isCustom: false,
  },
  {
    categoryId: 'sys-insurance',
    name: 'Insurance (other than health)',
    irsLine: 15,
    isDeductible: true,
    isCustom: false,
  },
  {
    categoryId: 'sys-legal-professional',
    name: 'Legal and Professional Services',
    irsLine: 17,
    isDeductible: true,
    isCustom: false,
  },
  {
    categoryId: 'sys-office-expense',
    name: 'Office Expense',
    irsLine: 18,
    isDeductible: true,
    isCustom: false,
  },
  {
    categoryId: 'sys-rent-lease',
    name: 'Rent or Lease',
    irsLine: 20,
    isDeductible: true,
    isCustom: false,
  },
  {
    categoryId: 'sys-supplies',
    name: 'Supplies',
    irsLine: 22,
    isDeductible: true,
    isCustom: false,
  },
  {
    categoryId: 'sys-travel-meals',
    name: 'Travel and Meals',
    irsLine: 24,
    isDeductible: true,
    isCustom: false,
  },
];

/**
 * 初始化系统默认税务分类
 * - 启动时调用一次，幂等：已存在的分类不会重复插入
 * - 使用 insertMany + ordered:false 容错，重复 categoryId 会被唯一索引拒绝但不影响其他
 */
const seedDefaultTaxCategories = async () => {
  try {
    // 检查是否已 seed 过（任意一条系统默认分类存在即认为已初始化）
    const existingCount = await TaxCategory.countDocuments({
      userId: null,
      isCustom: false,
      isDeleted: false,
    });

    if (existingCount >= DEFAULT_TAX_CATEGORIES.length) {
      logger.info(`[TaxCategory] Default categories already seeded (${existingCount} found)`);
      return;
    }

    // 标记 userId: null（系统默认），覆盖默认值
    const docs = DEFAULT_TAX_CATEGORIES.map((cat) => ({ ...cat, userId: null }));
    const result = await TaxCategory.insertMany(docs, { ordered: false });
    logger.info(`[TaxCategory] Seeded ${result.length} default tax categories`);
  } catch (error) {
    // insertMany 遇到重复 key 会抛部分错误，但不影响已成功的插入
    if (error.code === 11000 || error.name === 'BulkWriteError') {
      const inserted = error.result?.insertedCount || error.insertedDocs?.length || 0;
      logger.info(`[TaxCategory] Default categories already exist (inserted ${inserted} new)`);
    } else {
      logger.error(`[TaxCategory] Failed to seed default categories: ${error.message}`);
    }
  }
};

module.exports = { seedDefaultTaxCategories, DEFAULT_TAX_CATEGORIES };
