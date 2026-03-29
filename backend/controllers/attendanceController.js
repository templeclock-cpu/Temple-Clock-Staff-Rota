const { validationResult } = require('express-validator');
const Attendance = require('../models/Attendance');
const Shift = require('../models/Shift');
const Settings = require('../models/Settings');

// Load configurable settings from DB (cached for performance)
let _cachedSettings = null;
let _settingsCachedAt = 0;
const SETTINGS_CACHE_MS = 60000; // refresh every 60s

async function getSettings() {
  const now = Date.now();
  if (!_cachedSettings || now - _settingsCachedAt > SETTINGS_CACHE_MS) {
    _cachedSettings = await Settings.findOne({ key: 'global' });
    if (!_cachedSettings) _cachedSettings = await Settings.create({ key: 'global' });
    _settingsCachedAt = now;
  }
  return _cachedSettings;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Haversine formula — distance in metres between two lat/lng points.
 */
function haversineDistance(lat1, lng1, lat2, lng2) {
  const R = 6371e3; // Earth radius in metres
  const toRad = (deg) => (deg * Math.PI) / 180;

  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
    Math.cos(toRad(lat2)) *
    Math.sin(dLng / 2) *
    Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Build a full Date from a shift's date + time string ("HH:mm").
 */
function buildShiftDateTime(shiftDate, timeStr) {
  const [hours, minutes] = timeStr.split(':').map(Number);
  const d = new Date(shiftDate);
  d.setHours(hours, minutes, 0, 0);
  return d;
}

// ── Clock In ─────────────────────────────────────────────────────────────────

// @desc    Clock in for a shift
// @route   POST /api/attendance/clock-in
// @access  Private
const clockIn = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { shiftId, location, imageUrl } = req.body;
    const staffId = req.user._id;

    // 1. Shift must exist
    const shift = await Shift.findById(shiftId);
    if (!shift) {
      return res.status(404).json({ message: 'Shift not found' });
    }

    // 2. Shift must belong to this staff member (admins can bypass)
    if (
      req.user.role !== 'admin' &&
      shift.staffId.toString() !== staffId.toString()
    ) {
      return res
        .status(403)
        .json({ message: 'This shift is not assigned to you' });
    }

    // 3. Prevent duplicate clock-in
    const existing = await Attendance.findOne({ staffId, shiftId });
    if (existing) {
      return res
        .status(409)
        .json({ message: 'Already clocked in for this shift' });
    }

    // 4. Load settings for geofence + grace period
    const settings = await getSettings();
    const ALLOWED_RADIUS = settings.geofenceRadius || 200;
    const GRACE_PERIOD = settings.gracePeriodMinutes || 10;

    // 5. Geofence — check within allowed radius if shift has coordinates
    if (
      settings.geofenceEnabled &&
      shift.coordinates &&
      shift.coordinates.lat != null &&
      shift.coordinates.lng != null
    ) {
      if (!location || location.lat == null || location.lng == null) {
        return res
          .status(400)
          .json({ message: 'Location is required for this shift' });
      }

      const distance = haversineDistance(
        location.lat,
        location.lng,
        shift.coordinates.lat,
        shift.coordinates.lng
      );

      if (distance > ALLOWED_RADIUS) {
        return res.status(403).json({
          message: `You are ${Math.round(distance)}m away. Must be within ${ALLOWED_RADIUS}m of the shift location.`,
        });
      }
    }

    // 6. Calculate late minutes (only count time beyond grace period)
    const now = new Date();
    const scheduledStart = buildShiftDateTime(shift.date, shift.startTime);
    const diffMinutes = Math.floor(
      (now.getTime() - scheduledStart.getTime()) / 60000
    );

    let lateMinutes = 0;
    let status = 'on-time';

    if (diffMinutes > GRACE_PERIOD) {
      lateMinutes = diffMinutes - GRACE_PERIOD;
      status = 'late';
    }

    // 6. Create record
    const attendance = await Attendance.create({
      staffId,
      shiftId,
      clockInTime: now,
      lateMinutes,
      status,
      location: location || undefined,
      imageUrl: imageUrl || undefined,
    });

    await attendance.populate('staffId', 'name email');
    await attendance.populate('shiftId', 'date startTime endTime location');

    res.status(201).json(attendance);
  } catch (error) {
    // Mongoose duplicate-key error (race condition safety net)
    if (error.code === 11000) {
      return res
        .status(409)
        .json({ message: 'Already clocked in for this shift' });
    }
    console.error('ClockIn error:', error.message);
    res.status(500).json({ message: 'Server error' });
  }
};

// ── Clock Out ────────────────────────────────────────────────────────────────

// @desc    Clock out from a shift
// @route   POST /api/attendance/clock-out
// @access  Private
const clockOut = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { shiftId, imageUrl } = req.body;
    const staffId = req.user._id;

    // 1. Find the attendance record
    const attendance = await Attendance.findOne({ staffId, shiftId });
    if (!attendance) {
      return res
        .status(404)
        .json({ message: 'No clock-in record found for this shift' });
    }

    // 2. Must not already be clocked out
    if (attendance.clockOutTime) {
      return res
        .status(409)
        .json({ message: 'Already clocked out for this shift' });
    }

    // 3. Get shift for end-time calculation
    const shift = await Shift.findById(shiftId);
    if (!shift) {
      return res.status(404).json({ message: 'Shift not found' });
    }

    // 4. Load settings for grace period
    const settings = await getSettings();
    const GRACE_PERIOD = settings.gracePeriodMinutes || 10;

    // 5. Calculate extra hours
    const now = new Date();
    const scheduledEnd = buildShiftDateTime(shift.date, shift.endTime);
    const outDiffMinutes = Math.floor(
      (now.getTime() - scheduledEnd.getTime()) / 60000
    );

    let extraHours = 0;
    if (outDiffMinutes > GRACE_PERIOD) {
      extraHours = parseFloat((outDiffMinutes / 60).toFixed(2));
    }

    // 6. Final status — preserve 'late' info when overtime applies
    let finalStatus = attendance.status;
    if (extraHours > 0) {
      finalStatus = attendance.status === 'late' ? 'late-overtime' : 'overtime';
    }

    // 6. Update
    attendance.clockOutTime = now;
    attendance.extraHours = extraHours;
    attendance.status = finalStatus;
    if (imageUrl) attendance.clockOutImageUrl = imageUrl;

    await attendance.save();
    await attendance.populate('staffId', 'name email');
    await attendance.populate('shiftId', 'date startTime endTime location');

    res.json(attendance);
  } catch (error) {
    console.error('ClockOut error:', error.message);
    res.status(500).json({ message: 'Server error' });
  }
};

// ── Admin Override ───────────────────────────────────────────────────────────

// @desc    Admin override an attendance record
// @route   PUT /api/attendance/:id/override
// @access  Private/Admin
const adminOverride = async (req, res) => {
  try {
    const attendance = await Attendance.findById(req.params.id);
    if (!attendance) {
      return res
        .status(404)
        .json({ message: 'Attendance record not found' });
    }

    const { clockInTime, clockOutTime, lateMinutes, extraHours, status, notes } =
      req.body;

    if (clockInTime !== undefined) attendance.clockInTime = clockInTime;
    if (clockOutTime !== undefined) attendance.clockOutTime = clockOutTime;
    if (lateMinutes !== undefined) attendance.lateMinutes = lateMinutes;
    if (extraHours !== undefined) attendance.extraHours = extraHours;
    if (status !== undefined) attendance.status = status;
    if (notes !== undefined) attendance.notes = notes;

    attendance.overriddenBy = req.user._id;

    await attendance.save();
    await attendance.populate('staffId', 'name email');
    await attendance.populate('shiftId', 'date startTime endTime location');
    await attendance.populate('overriddenBy', 'name email');

    res.json(attendance);
  } catch (error) {
    console.error('AdminOverride error:', error.message);
    res.status(500).json({ message: 'Server error' });
  }
};

// ── Get Attendance Records ───────────────────────────────────────────────────

// @desc    Get attendance records (admin sees all, staff sees own)
// @route   GET /api/attendance
// @access  Private
const getAttendance = async (req, res) => {
  try {
    let query = {};

    // Staff can only see their own records
    if (req.user.role === 'staff') {
      query.staffId = req.user._id;
    }

    // Admin can filter by staff
    if (req.query.staffId && req.user.role === 'admin') {
      query.staffId = req.query.staffId;
    }

    // Filter by shift
    if (req.query.shiftId) {
      query.shiftId = req.query.shiftId;
    }

    // Filter by date (matches clockInTime within that day)
    if (req.query.date) {
      const filterDate = new Date(req.query.date);
      const nextDay = new Date(filterDate);
      nextDay.setDate(nextDay.getDate() + 1);
      query.clockInTime = { $gte: filterDate, $lt: nextDay };
    }

    const records = await Attendance.find(query)
      .populate('staffId', 'name email role')
      .populate('shiftId', 'date startTime endTime location')
      .populate('overriddenBy', 'name email')
      .sort({ clockInTime: -1 });

    res.json(records);
  } catch (error) {
    console.error('GetAttendance error:', error.message);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Get single attendance record
// @route   GET /api/attendance/:id
// @access  Private
const getAttendanceById = async (req, res) => {
  try {
    const attendance = await Attendance.findById(req.params.id)
      .populate('staffId', 'name email role')
      .populate('shiftId', 'date startTime endTime location')
      .populate('overriddenBy', 'name email');

    if (!attendance) {
      return res
        .status(404)
        .json({ message: 'Attendance record not found' });
    }

    // Staff can only view their own records
    if (
      req.user.role === 'staff' &&
      attendance.staffId._id.toString() !== req.user._id.toString()
    ) {
      return res
        .status(403)
        .json({ message: 'Not authorized to view this record' });
    }

    res.json(attendance);
  } catch (error) {
    console.error('GetAttendanceById error:', error.message);
    res.status(500).json({ message: 'Server error' });
  }
};

// ── Stats for Today (Admin Dashboard) ────────────────────────────────────────

// @desc    Get attendance stats for today
// @route   GET /api/attendance/stats/today
// @access  Private
const getAttendanceStatsToday = async (req, res) => {
  try {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const endOfDay = new Date(startOfDay);
    endOfDay.setDate(endOfDay.getDate() + 1);

    const todayRecords = await Attendance.find({
      clockInTime: { $gte: startOfDay, $lt: endOfDay },
    });

    const activeShifts = todayRecords.filter(
      (r) => r.clockInTime && !r.clockOutTime
    ).length;
    const lateCount = todayRecords.filter((r) => r.lateMinutes > 0).length;
    const completedShifts = todayRecords.filter(
      (r) => r.clockOutTime != null
    ).length;
    const extraHoursTotal = todayRecords.reduce(
      (sum, r) => sum + (r.extraHours || 0),
      0
    );

    res.json({
      activeShifts,
      lateCount,
      completedShifts,
      extraHoursTotal: parseFloat(extraHoursTotal.toFixed(2)),
    });
  } catch (error) {
    console.error('getAttendanceStatsToday error:', error.message);
    res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  clockIn,
  clockOut,
  adminOverride,
  getAttendance,
  getAttendanceById,
  getAttendanceStatsToday,
};
