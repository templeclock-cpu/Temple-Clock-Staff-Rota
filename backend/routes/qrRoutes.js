const express = require('express');
const {
    generateDailyQR,
    getActiveQR,
    verifyQR,
    getQRHistory,
    expireQR,
} = require('../controllers/qrController');
const { protect, authorize, validateObjectId } = require('../middleware/auth');

const router = express.Router();

router.use(protect);

const adminOnly = authorize('admin');

// POST /api/qr/generate — Admin generates new daily QR (expires old ones)
router.post('/generate', adminOnly, generateDailyQR);

// GET /api/qr/active — Get current active QR code
router.get('/active', getActiveQR);

// POST /api/qr/verify — Staff verifies scanned QR token
router.post('/verify', verifyQR);

// GET /api/qr/history — Admin views QR history
router.get('/history', adminOnly, getQRHistory);

// PUT /api/qr/:id/expire — Admin manually expires a QR
router.put('/:id/expire', validateObjectId, adminOnly, expireQR);

module.exports = router;
