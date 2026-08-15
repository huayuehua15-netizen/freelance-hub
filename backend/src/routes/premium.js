const express = require('express');
const router = express.Router();
const premiumController = require('../controllers/premiumController');
const authMiddleware = require('../middleware/auth');

router.get('/entitlement', authMiddleware, premiumController.getEntitlement);

module.exports = router;
