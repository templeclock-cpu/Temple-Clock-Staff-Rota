const express = require('express');
const { body } = require('express-validator');
const {
  createShift,
  getShifts,
  getShiftById,
  updateShift,
  deleteShift,
  getShiftStats,
} = require('../controllers/shiftController');
const { protect, authorize, validateObjectId } = require('../middleware/auth');

const router = express.Router();

// All routes below require authentication
router.use(protect);

// GET /api/shifts/stats - Get shift statistics
router.get('/stats', getShiftStats);

// GET /api/shifts/my-shifts - Get current user's shifts (alias)
router.get('/my-shifts', getShifts);

// GET /api/shifts - Get shifts (admin sees all, staff sees own)
router.get('/', getShifts);

// GET /api/shifts/:id - Get single shift
router.get('/:id', validateObjectId, getShiftById);

// POST /api/shifts - Create shift (admin only)
router.post(
  '/',
  authorize('admin'),
  [
    body('staffId').notEmpty().withMessage('Staff member is required'),
    body('date').notEmpty().withMessage('Date is required'),
    body('startTime').notEmpty().withMessage('Start time is required'),
    body('endTime').notEmpty().withMessage('End time is required'),
  ],
  createShift
);

// PUT /api/shifts/:id - Update shift (admin only)
router.put('/:id', validateObjectId, authorize('admin'), updateShift);

// DELETE /api/shifts/:id - Delete shift (admin only)
router.delete('/:id', validateObjectId, authorize('admin'), deleteShift);

module.exports = router;
