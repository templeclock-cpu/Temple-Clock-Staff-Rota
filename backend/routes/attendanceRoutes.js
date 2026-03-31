const express = require('express');
const { body } = require('express-validator');
const {
  clockIn,
  clockOut,
  adminOverride,
  getAttendance,
  getAttendanceById,
  getAttendanceStatsToday,
} = require('../controllers/attendanceController');
const { protect, authorize, validateObjectId } = require('../middleware/auth');

const router = express.Router();

// All routes require authentication
router.use(protect);

// GET /api/attendance/stats/today - Today's stats (must be before /:id)
router.get('/stats/today', getAttendanceStatsToday);

// GET /api/attendance/my-history - Staff's own records (alias to getAttendance which filters by role)
router.get('/my-history', getAttendance);

// GET /api/attendance - List records (admin: all, staff: own)
router.get('/', getAttendance);

// GET /api/attendance/:id - Single record
router.get('/:id', validateObjectId, getAttendanceById);

// POST /api/attendance/clock-in
router.post(
  '/clock-in',
  [
    body('shiftId').notEmpty().withMessage('Shift ID is required'),
  ],
  clockIn
);

// POST /api/attendance/clock-out
router.post(
  '/clock-out',
  [
    body('shiftId').notEmpty().withMessage('Shift ID is required'),
  ],
  clockOut
);

// PUT /api/attendance/:id/override - Admin override
router.put('/:id/override', validateObjectId, authorize('admin'), adminOverride);

module.exports = router;
