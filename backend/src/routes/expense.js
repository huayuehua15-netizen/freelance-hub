const express = require('express');
const router = express.Router();
const expenseController = require('../controllers/expenseController');
const authMiddleware = require('../middleware/auth');
const { requireAnnual } = require('../middleware/premium');

router.post('/batch-upsert', authMiddleware, requireAnnual, expenseController.batchUpsert);
router.get('/pull', authMiddleware, requireAnnual, expenseController.pull);
router.get('/list', authMiddleware, expenseController.list);
router.delete('/:expenseId', authMiddleware, expenseController.remove);

module.exports = router;
