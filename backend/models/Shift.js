const mongoose = require('mongoose');

const shiftSchema = new mongoose.Schema(
  {
    staffId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Staff member is required'],
    },
    date: {
      type: Date,
      required: [true, 'Shift date is required'],
    },
    startTime: {
      type: String,
      required: [true, 'Start time is required'],
      // Format: "09:00"
    },
    endTime: {
      type: String,
      required: [true, 'End time is required'],
      // Format: "17:00"
    },
    location: {
      type: String,
      trim: true,
    },
    coordinates: {
      lat: { type: Number },
      lng: { type: Number },
    },
    notes: {
      type: String,
      trim: true,
    },
    status: {
      type: String,
      enum: ['scheduled', 'completed', 'cancelled'],
      default: 'scheduled',
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
  },
  {
    timestamps: true,
  }
);

// Indexes for common query patterns (shifts by staff, by date range, by status)
shiftSchema.index({ staffId: 1, date: 1 });
shiftSchema.index({ date: 1, status: 1 });

module.exports = mongoose.model('Shift', shiftSchema);
