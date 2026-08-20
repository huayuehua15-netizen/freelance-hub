const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authLimiter, refreshLimiter, passwordResetLimiter } = require('../middleware/rateLimit');
const authMiddleware = require('../middleware/auth');

router.post('/register', authLimiter, authController.register);
router.post('/login', authLimiter, authController.login);
router.post('/refresh', refreshLimiter, authController.refresh);
// 忘记密码：更严格的独立限流（防邮件轰炸，而非防爆破）
router.post('/forgot-password', passwordResetLimiter, authController.forgotPassword);
// 重置密码：公开（凭一次性 token 认证）
router.post('/reset-password', passwordResetLimiter, authController.resetPassword);
// 邮箱验证：公开（凭一次性 token 认证）
router.post('/verify-email', passwordResetLimiter, authController.verifyEmail);
router.post('/resend-verification', authLimiter, authMiddleware, authController.resendVerification);
router.get('/me', authMiddleware, authController.getMe);
router.post('/logout', authMiddleware, authController.logout);
router.delete('/account', authMiddleware, authController.deleteAccount);

module.exports = router;
