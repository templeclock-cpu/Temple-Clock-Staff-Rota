const Settings = require('../models/Settings');

// @desc    Get app settings
// @route   GET /api/settings
// @access  Private
const getSettings = async (req, res) => {
    try {
        let settings = await Settings.findOne({ key: 'global' });
        if (!settings) {
            settings = await Settings.create({ key: 'global' });
        }
        res.json(settings);
    } catch (error) {
        console.error('GetSettings error:', error.message);
        res.status(500).json({ message: 'Server error' });
    }
};

// @desc    Update app settings
// @route   PUT /api/settings
// @access  Private/Admin
const updateSettings = async (req, res) => {
    try {
        const allowedFields = [
            'gracePeriodMinutes',
            'geofenceEnabled',
            'geofenceRadius',
            'annualLeaveHours',
            'requireLeaveApproval',
            'minNoticeDays',
            'defaultHourlyRate',
            'overtimeMultiplier',
            'emailNotifications',
            'pushNotifications',
        ];

        let settings = await Settings.findOne({ key: 'global' });
        if (!settings) {
            settings = await Settings.create({ key: 'global' });
        }

        for (const field of allowedFields) {
            if (req.body[field] !== undefined) {
                const val = req.body[field];
                // Type & bounds validation for numeric fields
                if (['gracePeriodMinutes', 'geofenceRadius', 'annualLeaveHours',
                     'minNoticeDays', 'defaultHourlyRate', 'overtimeMultiplier'].includes(field)) {
                    if (typeof val !== 'number' || val < 0) continue; // skip invalid
                }
                if (['geofenceEnabled', 'requireLeaveApproval',
                     'emailNotifications', 'pushNotifications'].includes(field)) {
                    if (typeof val !== 'boolean') continue; // skip invalid
                }
                settings[field] = val;
            }
        }

        await settings.save();
        res.json(settings);
    } catch (error) {
        console.error('UpdateSettings error:', error.message);
        res.status(500).json({ message: 'Server error' });
    }
};

module.exports = { getSettings, updateSettings };
