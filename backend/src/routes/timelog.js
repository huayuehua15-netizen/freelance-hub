const express = require('express');
const router = express.Router();
const timelogController = require('../controllers/timelogController');
const authMiddleware = require('../middleware/auth');
const { requireAnnual } = require('../middleware/premium');

router.post('/batch-upsert', authMiddleware, requireAnnual, timelogController.batchUpsert);
router.get('/pull', authMiddleware, requireAnnual, timelogController.pull);
router.get('/list', authMiddleware, timelogController.list);
router.delete('/:timeLogId', authMiddleware, timelogController.remove);

module.exports = router;
