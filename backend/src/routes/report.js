const express = require('express');
const router = express.Router();
const reportController = require('../controllers/reportController');
const authMiddleware = require('../middleware/auth');
const { requireMonthly, requireAnnual } = require('../middleware/premium');

router.get('/monthly', authMiddleware, requireMonthly, reportController.getMonthly);
router.get('/annual', authMiddleware, requireAnnual, reportController.getAnnual);
// Monthly reports are generated locally by the mobile app.  A server export is
// an Annual/Web entitlement and must not become an accidental Monthly feature.
router.get('/export', authMiddleware, requireAnnual, reportController.exportPdf);
router.get('/export-csv', authMiddleware, requireAnnual, reportController.exportCsv);

module.exports = router;
