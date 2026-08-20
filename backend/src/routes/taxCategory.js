const express = require('express');
const router = express.Router();
const taxCategoryController = require('../controllers/taxCategoryController');
const authMiddleware = require('../middleware/auth');
const { requireAnnual } = require('../middleware/premium');

/**
 * 税务分类路由
 * ===========================================================================
 * - GET    /list         所有用户可查看（系统默认 + 自己的自定义）
 * - POST   /             创建自定义分类（Annual 会员专属）
 * - PUT    /:categoryId  更新自定义分类（Annual 会员专属）
 * - DELETE /:categoryId  软删除自定义分类（Annual 会员专属）
 *
 * 权限设计：
 * - Free/Monthly 用户可查看系统默认分类，但不能创建自定义
 * - Annual 会员可创建自定义分类（对应 entitlements.customTaxCategory: true）
 * ===========================================================================
 */

router.get('/list', authMiddleware, taxCategoryController.list);
router.post('/', authMiddleware, requireAnnual, taxCategoryController.create);
router.put('/:categoryId', authMiddleware, requireAnnual, taxCategoryController.update);
router.delete('/:categoryId', authMiddleware, requireAnnual, taxCategoryController.remove);

module.exports = router;
