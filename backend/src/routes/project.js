const express = require('express');
const router = express.Router();
const projectController = require('../controllers/projectController');
const authMiddleware = require('../middleware/auth');
const { requireAnnual } = require('../middleware/premium');

router.post('/batch-upsert', authMiddleware, requireAnnual, projectController.batchUpsert);
router.get('/pull', authMiddleware, requireAnnual, projectController.pull);
router.get('/list', authMiddleware, projectController.list);
router.delete('/:projectId', authMiddleware, projectController.remove);

module.exports = router;
