const express = require('express');
const router = express.Router();
const webhookController = require('../controllers/webhookController');

router.post('/revenuecat', webhookController.handleRevenuecatWebhook);

module.exports = router;
