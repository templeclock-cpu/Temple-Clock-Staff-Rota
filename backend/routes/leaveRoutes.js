const express = require('express');
const {
    createLeaveRequest,
    approveLeave,
    rejectLeave,
    cancelLeave,
    getLeaveRequests,
    getLeaveById,
    getLeaveBalance,
} = require('../controllers/leaveController');
const { protect, authorize, validateObjectId } = require('../middleware/auth');

const router = express.Router();

// All routes require authentication
router.use(protect);

// GET /api/leave - List leave requests (admin: all, staff: own)
router.get('/', getLeaveRequests);

// GET /api/leave/balance/:staffId - Leave balance summary
// IMPORTANT: This MUST come BEFORE /:id to prevent conflict
router.get('/balance/:staffId', validateObjectId, getLeaveBalance);

// GET /api/leave/:id - Single leave request
router.get('/:id', validateObjectId, getLeaveById);

// POST /api/leave - Submit leave request
router.post('/', createLeaveRequest);

// PUT /api/leave/:id/approve - Admin approve
router.put('/:id/approve', validateObjectId, authorize('admin'), approveLeave);

// PUT /api/leave/:id/reject - Admin reject
router.put('/:id/reject', validateObjectId, authorize('admin'), rejectLeave);

// PUT /api/leave/:id/cancel - Cancel own pending request
router.put('/:id/cancel', validateObjectId, cancelLeave);

module.exports = router;
