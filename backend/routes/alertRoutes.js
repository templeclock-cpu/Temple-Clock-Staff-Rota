const express = require('express');
const router = express.Router();
const {
  createAlert,
  getAlerts,
  markAlertAsRead,
} = require('../controllers/alertController');
const { protect } = require('../middleware/authMiddleware');

router.route('/')
  .post(protect, createAlert)
  .get(protect, getAlerts);

router.put('/:id/read', protect, markAlertAsRead);

module.exports = router;
