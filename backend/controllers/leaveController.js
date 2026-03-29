const Leave = require('../models/Leave');
const User = require('../models/User');
const Settings = require('../models/Settings');

// ── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Calculate working days between two dates (Mon-Fri only).
 */
function countWorkingDays(start, end) {
    let count = 0;
    const d = new Date(start);
    d.setHours(0, 0, 0, 0);
    const endDate = new Date(end);
    endDate.setHours(0, 0, 0, 0);

    while (d <= endDate) {
        const day = d.getDay();
        if (day !== 0 && day !== 6) count++;
        d.setDate(d.getDate() + 1);
    }
    return count;
}

/**
 * Calculate total hours for leave based on working days and daily hours.
 * Default: 8 hours per day (40 hours / 5 days).
 */
function calculateTotalHours(startDate, endDate, weeklyHours = 40) {
    const dailyHours = weeklyHours / 5;
    const workingDays = countWorkingDays(startDate, endDate);
    return parseFloat((workingDays * dailyHours).toFixed(2));
}

/**
 * Human-readable leave type label.
 */
const leaveTypeLabels = {
    annual: 'Annual Leave',
    sick: 'Sick Leave (SSP)',
    maternity: 'Maternity Leave',
    paternity: 'Paternity Leave',
    shared_parental: 'Shared Parental Leave',
    adoption: 'Adoption Leave',
    parental: 'Parental Leave',
    dependants: 'Time off for Dependants',
    compassionate: 'Compassionate Leave',
    neonatal: 'Neonatal Care Leave',
    carers: "Carer's Leave",
    public_duties: 'Public Duties',
    study: 'Study / Training Leave',
    unpaid: 'Unpaid Leave',
};

// ── Create Leave Request ─────────────────────────────────────────────────────

// @desc    Submit a leave request
// @route   POST /api/leave
// @access  Private
const createLeaveRequest = async (req, res) => {
    try {
        const { leaveType, startDate, endDate, reason } = req.body;
        const staffId = req.user._id;

        // Manual validation
        if (!leaveType || !startDate || !endDate) {
            return res.status(400).json({ message: 'leaveType, startDate, and endDate are required' });
        }

        const validTypes = [
            'annual', 'sick', 'maternity', 'paternity', 'shared_parental',
            'adoption', 'parental', 'dependants', 'compassionate', 'neonatal',
            'carers', 'public_duties', 'study', 'unpaid',
        ];
        if (!validTypes.includes(leaveType)) {
            return res.status(400).json({ message: 'Invalid leave type' });
        }

        // 1. Validate dates
        const start = new Date(startDate);
        const end = new Date(endDate);

        if (end < start) {
            return res
                .status(400)
                .json({ message: 'End date must be on or after start date' });
        }

        // 2. Sick leave can be today; other types must be future
        if (leaveType !== 'sick' && leaveType !== 'dependants') {
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            if (start < today) {
                return res
                    .status(400)
                    .json({ message: 'Leave start date must be today or in the future' });
            }
        }

        // 3. Check for overlapping leave requests (pending or approved)
        const overlap = await Leave.findOne({
            staffId,
            status: { $in: ['pending', 'approved'] },
            $or: [
                { startDate: { $lte: end }, endDate: { $gte: start } },
            ],
        });

        if (overlap) {
            return res.status(409).json({
                message: 'You already have a leave request overlapping these dates',
            });
        }

        // 4. Calculate total hours
        const user = await User.findById(staffId);
        const totalHours = calculateTotalHours(start, end, user.weeklyHours || 40);

        if (totalHours <= 0) {
            return res
                .status(400)
                .json({ message: 'Selected dates contain no working days' });
        }

        // 5. For annual leave — check balance
        if (leaveType === 'annual') {
            if (user.annualLeaveBalance < totalHours) {
                return res.status(400).json({
                    message: `Insufficient annual leave balance. Requested: ${totalHours}h, Available: ${user.annualLeaveBalance}h`,
                });
            }
        }

        // 6. Create record
        const leave = await Leave.create({
            staffId,
            leaveType,
            startDate: start,
            endDate: end,
            totalHours,
            reason: reason || '',
            status: 'pending',
        });

        await leave.populate('staffId', 'name email');

        res.status(201).json(leave);
    } catch (error) {
        console.error('CreateLeaveRequest error:', error.message);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Approve Leave ────────────────────────────────────────────────────────────

// @desc    Approve a leave request
// @route   PUT /api/leave/:id/approve
// @access  Private/Admin
const approveLeave = async (req, res) => {
    try {
        const leave = await Leave.findById(req.params.id);
        if (!leave) {
            return res.status(404).json({ message: 'Leave request not found' });
        }

        if (leave.status !== 'pending') {
            return res.status(400).json({
                message: `Cannot approve a leave request that is already ${leave.status}`,
            });
        }

        // For annual leave — deduct balance
        if (leave.leaveType === 'annual') {
            const user = await User.findById(leave.staffId);
            if (user.annualLeaveBalance < leave.totalHours) {
                return res.status(400).json({
                    message: `Insufficient balance. Requested: ${leave.totalHours}h, Available: ${user.annualLeaveBalance}h`,
                });
            }
            user.annualLeaveBalance -= leave.totalHours;
            await user.save();
        }

        leave.status = 'approved';
        leave.approvedBy = req.user._id;
        await leave.save();

        await leave.populate('staffId', 'name email');
        await leave.populate('approvedBy', 'name email');

        res.json(leave);
    } catch (error) {
        console.error('ApproveLeave error:', error.message);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Reject Leave ─────────────────────────────────────────────────────────────

// @desc    Reject a leave request
// @route   PUT /api/leave/:id/reject
// @access  Private/Admin
const rejectLeave = async (req, res) => {
    try {
        const leave = await Leave.findById(req.params.id);
        if (!leave) {
            return res.status(404).json({ message: 'Leave request not found' });
        }

        if (leave.status !== 'pending') {
            return res.status(400).json({
                message: `Cannot reject a leave request that is already ${leave.status}`,
            });
        }

        leave.status = 'rejected';
        leave.rejectedReason = req.body.reason || '';
        await leave.save();

        await leave.populate('staffId', 'name email');

        res.json(leave);
    } catch (error) {
        console.error('RejectLeave error:', error.message);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Cancel Leave ─────────────────────────────────────────────────────────────

// @desc    Cancel own pending leave request
// @route   PUT /api/leave/:id/cancel
// @access  Private
const cancelLeave = async (req, res) => {
    try {
        const leave = await Leave.findById(req.params.id);
        if (!leave) {
            return res.status(404).json({ message: 'Leave request not found' });
        }

        // Staff can only cancel their own
        if (
            req.user.role !== 'admin' &&
            leave.staffId.toString() !== req.user._id.toString()
        ) {
            return res
                .status(403)
                .json({ message: 'Not authorized to cancel this request' });
        }

        if (leave.status !== 'pending' && leave.status !== 'approved') {
            return res.status(400).json({
                message: `Cannot cancel a leave request that is already ${leave.status}`,
            });
        }

        if (leave.status === 'approved' && leave.leaveType === 'annual') {
            // Refund the balance since it was already approved
            const user = await User.findById(leave.staffId);
            user.annualLeaveBalance += leave.totalHours;
            await user.save();
        }

        leave.status = 'cancelled';
        await leave.save();

        await leave.populate('staffId', 'name email');

        res.json(leave);
    } catch (error) {
        console.error('CancelLeave error:', error.message);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Get Leave Requests ───────────────────────────────────────────────────────

// @desc    Get leave requests (admin sees all, staff sees own)
// @route   GET /api/leave
// @access  Private
const getLeaveRequests = async (req, res) => {
    try {
        let query = {};

        // Staff can only see their own
        if (req.user.role === 'staff') {
            query.staffId = req.user._id;
        }

        // Filters (admin can filter by staffId)
        if (req.query.staffId && req.user.role === 'admin') {
            query.staffId = req.query.staffId;
        }

        // Filter by status
        if (req.query.status) {
            query.status = req.query.status;
        }

        // Filter by leave type
        if (req.query.leaveType) {
            query.leaveType = req.query.leaveType;
        }

        const records = await Leave.find(query)
            .populate('staffId', 'name email role')
            .populate('approvedBy', 'name email')
            .sort({ createdAt: -1 });

        res.json(records);
    } catch (error) {
        console.error('GetLeaveRequests error:', error.message);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Get Single Leave ─────────────────────────────────────────────────────────

// @desc    Get single leave request
// @route   GET /api/leave/:id
// @access  Private
const getLeaveById = async (req, res) => {
    try {
        const mongoose = require('mongoose');
        if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
            return res.status(400).json({ message: 'Invalid leave request ID' });
        }
        const leave = await Leave.findById(req.params.id)
            .populate('staffId', 'name email role')
            .populate('approvedBy', 'name email');

        if (!leave) {
            return res.status(404).json({ message: 'Leave request not found' });
        }

        // Staff can only view their own
        if (
            req.user.role === 'staff' &&
            leave.staffId._id.toString() !== req.user._id.toString()
        ) {
            return res
                .status(403)
                .json({ message: 'Not authorized to view this request' });
        }

        res.json(leave);
    } catch (error) {
        console.error('GetLeaveById error:', error.message);
        res.status(500).json({ message: 'Server error' });
    }
};

// ── Get Leave Balance ────────────────────────────────────────────────────────

// @desc    Get staff leave balance summary
// @route   GET /api/leave/balance/:staffId
// @access  Private
const getLeaveBalance = async (req, res) => {
    try {
        const { staffId } = req.params;

        // Staff can only view their own balance
        if (
            req.user.role === 'staff' &&
            staffId !== req.user._id.toString()
        ) {
            return res
                .status(403)
                .json({ message: 'Not authorized to view this balance' });
        }

        const user = await User.findById(staffId);
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        // Get approved leave totals by type for current year
        const yearStart = new Date(new Date().getFullYear(), 0, 1);
        const yearEnd = new Date(new Date().getFullYear(), 11, 31);

        const approvedLeave = await Leave.aggregate([
            {
                $match: {
                    staffId: user._id,
                    status: 'approved',
                    startDate: { $gte: yearStart, $lte: yearEnd },
                },
            },
            {
                $group: {
                    _id: '$leaveType',
                    totalHours: { $sum: '$totalHours' },
                    count: { $sum: 1 },
                },
            },
        ]);

        // Pending leave
        const pendingLeave = await Leave.aggregate([
            {
                $match: {
                    staffId: user._id,
                    status: 'pending',
                },
            },
            {
                $group: {
                    _id: '$leaveType',
                    totalHours: { $sum: '$totalHours' },
                    count: { $sum: 1 },
                },
            },
        ]);

        // Build summary
        const leaveUsed = {};
        const leavePending = {};

        for (const item of approvedLeave) {
            leaveUsed[item._id] = {
                hours: item.totalHours,
                count: item.count,
                label: leaveTypeLabels[item._id] || item._id,
            };
        }

        for (const item of pendingLeave) {
            leavePending[item._id] = {
                hours: item.totalHours,
                count: item.count,
                label: leaveTypeLabels[item._id] || item._id,
            };
        }

        // Total annual used
        const annualUsed = leaveUsed.annual?.hours || 0;
        const annualPending = leavePending.annual?.hours || 0;

        // Get configurable entitlement from Settings
        const settings = await Settings.findOne({ key: 'global' });
        const annualEntitlement = settings?.annualLeaveHours || 224;

        res.json({
            staffId: user._id,
            staffName: user.name,
            weeklyHours: user.weeklyHours || 40,
            annualEntitlement,
            annualLeaveBalance: user.annualLeaveBalance,
            annualUsed,
            annualPending,
            leaveUsed,
            leavePending,
        });
    } catch (error) {
        console.error('GetLeaveBalance error:', error.message);
        res.status(500).json({ message: 'Server error' });
    }
};

module.exports = {
    createLeaveRequest,
    approveLeave,
    rejectLeave,
    cancelLeave,
    getLeaveRequests,
    getLeaveById,
    getLeaveBalance,
};
