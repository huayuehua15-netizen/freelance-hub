const { v4: uuidv4 } = require('uuid');
const TaxCategory = require('../models/TaxCategory');
const { ERROR_CODES } = require('../utils/constants');
const { t } = require('../utils/i18n');

/**
 * 获取用户可用的所有税务分类（系统默认 + 用户自定义）
 * - 系统默认分类 userId = null，所有用户共享
 * - 用户自定义分类 userId = 当前用户
 * - 排除已软删除的分类
 * - 按 irsLine 升序（系统默认在前），自定义分类按创建时间在后
 */
const list = async (req, res, next) => {
  try {
    const categories = await TaxCategory.find({
      $or: [
        { userId: null },
        { userId: req.userId },
      ],
      isDeleted: false,
    }).sort({ isCustom: 1, irsLine: 1, serverCreateTime: 1 });

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('common.success', req.lang),
      data: { categories },
      timestamp: Date.now(),
    });
  } catch (error) {
    next(error);
  }
};

/**
 * 创建自定义税务分类（Annual 会员专属）
 * - 权限由路由层 requireAnnual 中间件强制
 * - 校验 name 非空且长度合理
 * - irsLine 可选（自定义分类可能无对应 IRS 行号）
 */
const create = async (req, res, next) => {
  try {
    const { name, irsLine, isDeductible } = req.body;

    if (!name || typeof name !== 'string' || name.trim().length === 0) {
      return res.status(400).json({
        code: ERROR_CODES.BAD_REQUEST,
        msg: t('errors.taxCategory.nameRequired', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    if (name.trim().length > 100) {
      return res.status(400).json({
        code: ERROR_CODES.BAD_REQUEST,
        msg: t('errors.validation.invalidInput', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    const categoryId = uuidv4();
    const category = await TaxCategory.create({
      categoryId,
      userId: req.userId,
      name: name.trim(),
      irsLine: typeof irsLine === 'number' && irsLine >= 1 && irsLine <= 99 ? irsLine : null,
      irsForm: 'Schedule C',
      isDeductible: typeof isDeductible === 'boolean' ? isDeductible : true,
      isCustom: true,
    });

    return res.status(201).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('taxCategory.created', req.lang),
      data: category,
      timestamp: Date.now(),
    });
  } catch (error) {
    next(error);
  }
};

/**
 * 更新自定义税务分类
 * - 只能更新自己创建的分类（userId 匹配 + isCustom: true）
 * - 系统默认分类不可修改
 */
const update = async (req, res, next) => {
  try {
    const { categoryId } = req.params;
    const { name, irsLine, isDeductible } = req.body;

    const category = await TaxCategory.findOne({
      categoryId,
      userId: req.userId,
      isCustom: true,
      isDeleted: false,
    });

    if (!category) {
      return res.status(404).json({
        code: ERROR_CODES.NOT_FOUND,
        msg: t('errors.taxCategory.notFound', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    if (name !== undefined) {
      if (typeof name !== 'string' || name.trim().length === 0 || name.trim().length > 100) {
        return res.status(400).json({
          code: ERROR_CODES.BAD_REQUEST,
          msg: t('errors.validation.invalidInput', req.lang),
          data: null,
          timestamp: Date.now(),
        });
      }
      category.name = name.trim();
    }

    if (typeof irsLine === 'number') {
      category.irsLine = irsLine >= 1 && irsLine <= 99 ? irsLine : null;
    }

    if (typeof isDeductible === 'boolean') {
      category.isDeductible = isDeductible;
    }

    await category.save();

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('taxCategory.updated', req.lang),
      data: category,
      timestamp: Date.now(),
    });
  } catch (error) {
    next(error);
  }
};

/**
 * 软删除自定义税务分类
 * - 只能删除自己创建的分类
 * - 系统默认分类不可删除
 * - 软删除保持历史开支数据完整性（已使用该分类的开支仍可显示分类名）
 */
const remove = async (req, res, next) => {
  try {
    const { categoryId } = req.params;

    const category = await TaxCategory.findOne({
      categoryId,
      userId: req.userId,
      isCustom: true,
      isDeleted: false,
    });

    if (!category) {
      return res.status(404).json({
        code: ERROR_CODES.NOT_FOUND,
        msg: t('errors.taxCategory.notFound', req.lang),
        data: null,
        timestamp: Date.now(),
      });
    }

    category.isDeleted = true;
    await category.save();

    return res.status(200).json({
      code: ERROR_CODES.SUCCESS,
      msg: t('taxCategory.deleted', req.lang),
      data: null,
      timestamp: Date.now(),
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { list, create, update, remove };
