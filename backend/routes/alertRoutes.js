const express = require('express');
const {
    createAlert,
    sendAlertToStaff,
    getAlerts,
    getMyAlerts,
    getMyUnreadCount,
    markAlertReadByStaff,
    markAlertRead,
    getUnreadCount,
} = require('../controllers/alertController');
const { protect, authorize, validateObjectId } = require('../middleware/auth');

const router = express.Router();

router.use(protect);

// Staff: send a running-late alert
router.post('/', createAlert);

// Admin: send alert to a specific staff member
router.post('/send', authorize('admin'), sendAlertToStaff);

// Staff: get my alerts (from admin)
router.get('/my', getMyAlerts);

// Staff: get my unread count
router.get('/my/unread-count', getMyUnreadCount);

// Admin: view all alerts
router.get('/', authorize('admin'), getAlerts);

// Admin: unread count
router.get('/unread-count', authorize('admin'), getUnreadCount);

// Staff: mark own alert as read
router.put('/:id/read-staff', validateObjectId, markAlertReadByStaff);

// Admin: mark alert as read
router.put('/:id/read', validateObjectId, authorize('admin'), markAlertRead);

module.exports = router;
