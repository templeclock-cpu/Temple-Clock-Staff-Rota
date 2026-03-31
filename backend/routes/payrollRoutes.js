const express = require('express');
const {
    generatePayroll,
    getPayroll,
    getStaffPayroll,
    adjustPayroll,
    finalizePayroll,
} = require('../controllers/payrollController');
const { protect, authorize, validateObjectId } = require('../middleware/auth');

const router = express.Router();

// All payroll routes require admin authentication
router.use(protect);
router.use(authorize('admin'));

// GET /api/payroll - List payroll records (optionally ?month=YYYY-MM)
router.get('/', getPayroll);

// POST /api/payroll/generate - Generate/recalculate payroll for a month
router.post('/generate', generatePayroll);

// GET /api/payroll/:staffId - Get single staff's payroll history
router.get('/:staffId', validateObjectId, getStaffPayroll);

// PUT /api/payroll/:id/adjust - Add adjustment to payroll record
router.put('/:id/adjust', validateObjectId, adjustPayroll);

// PUT /api/payroll/:id/finalize - Lock payroll record
router.put('/:id/finalize', validateObjectId, finalizePayroll);

module.exports = router;
