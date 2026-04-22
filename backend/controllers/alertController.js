const Alert = require('../models/Alert');

// @desc    Create a new alert (e.g., staff reporting late)
// @route   POST /api/alerts
// @access  Private
const createAlert = async (req, res) => {
  try {
    const { shiftId, alertType, message, estimatedDelay, targetStaffId } = req.body;

    const alert = await Alert.create({
      staffId: req.user._id,
      shiftId,
      alertType: alertType || 'running_late',
      message,
      estimatedDelay: estimatedDelay || 0,
      targetStaffId,
    });

    res.status(201).json(alert);
  } catch (error) {
    console.error('CreateAlert error:', error.message);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Get alerts (Admin sees all for office, Staff sees alerts targeted to them)
// @route   GET /api/alerts
// @access  Private
const getAlerts = async (req, res) => {
  try {
    let query = {};

    if (req.user.role === 'admin') {
      // Admins usually look for alerts reported BY staff to the office
      if (req.query.unreadOnly === 'true') {
        query.readByAdmin = false;
      }
    } else {
      // Staff look for alerts targeted TO them (admin notices)
      query.targetStaffId = req.user._id;
      if (req.query.unreadOnly === 'true') {
        query.readByStaff = false;
      }
    }

    const alerts = await Alert.find(query)
      .populate('staffId', 'name email role')
      .populate('targetStaffId', 'name email')
      .populate('shiftId', 'date startTime endTime location')
      .sort({ createdAt: -1 });

    res.json(alerts);
  } catch (error) {
    console.error('GetAlerts error:', error.message);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Update alert status (Mark as read)
// @route   PUT /api/alerts/:id/read
// @access  Private
const markAlertAsRead = async (req, res) => {
  try {
    const alert = await Alert.findById(req.params.id);
    if (!alert) {
      return res.status(404).json({ message: 'Alert not found' });
    }

    if (req.user.role === 'admin') {
      alert.readByAdmin = true;
    } else {
      alert.readByStaff = true;
    }

    await alert.save();
    res.json(alert);
  } catch (error) {
    console.error('MarkAlertAsRead error:', error.message);
    res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  createAlert,
  getAlerts,
  markAlertAsRead,
};
