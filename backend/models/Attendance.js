const mongoose = require('mongoose');

const attendanceSchema = new mongoose.Schema(
  {
    staffId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Staff member is required'],
    },
    shiftId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Shift',
      required: [true, 'Shift is required'],
    },
    clockInTime: {
      type: Date,
    },
    clockOutTime: {
      type: Date,
    },
    lateMinutes: {
      type: Number,
      default: 0,
    },
    extraHours: {
      type: Number,
      default: 0,
    },
    location: {
      lat: { type: Number },
      lng: { type: Number },
    },
    imageUrl: {
      type: String,
      trim: true,
    },
    clockOutImageUrl: {
      type: String,
      trim: true,
    },
    status: {
      type: String,
      enum: ['on-time', 'late', 'overtime', 'late-overtime', 'absent'],
      default: 'on-time',
    },
    notes: {
      type: String,
      trim: true,
    },
    overriddenBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
  },
  {
    timestamps: true,
  }
);

// Prevent duplicate clock-in: one attendance record per staff per shift
attendanceSchema.index({ staffId: 1, shiftId: 1 }, { unique: true });
// Index for date-range queries (timesheets, payroll generation)
attendanceSchema.index({ staffId: 1, clockInTime: 1 });

module.exports = mongoose.model('Attendance', attendanceSchema);
