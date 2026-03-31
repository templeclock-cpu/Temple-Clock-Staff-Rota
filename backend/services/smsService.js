// services/smsService.js
// Twilio SMS service — OPTIONAL.
// Only sends SMS if TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and
// TWILIO_FROM_NUMBER environment variables are configured.

let client = null;
let fromNumber = null;
let enabled = false;

function init() {
    const sid = process.env.TWILIO_ACCOUNT_SID;
    const token = process.env.TWILIO_AUTH_TOKEN;
    fromNumber = process.env.TWILIO_FROM_NUMBER;

    if (sid && token && fromNumber) {
        try {
            const twilio = require('twilio');
            client = twilio(sid, token);
            enabled = true;
            console.log('  ✓ Twilio SMS service enabled');
        } catch (err) {
            console.log('  ⚠ Twilio package not available — SMS disabled');
        }
    } else {
        console.log('  ⚠ Twilio env vars not set — SMS disabled');
    }
}

// Initialize on first require
init();

/**
 * Send an SMS message.
 * @param {string} to - Phone number (E.164 format, e.g. +447700900123)
 * @param {string} message - Text content
 * @returns {Promise<object|null>} Twilio message object or null if disabled
 */
async function sendSMS(to, message) {
    if (!enabled || !client) {
        console.log(`[SMS skipped] To: ${to.slice(0, 4)}***`);
        return null;
    }

    try {
        const result = await client.messages.create({
            to,
            from: fromNumber,
            body: message,
        });
        console.log(`[SMS sent] SID: ${result.sid}`);
        return result;
    } catch (error) {
        console.error(`[SMS error] ${error.message}`);
        return null;
    }
}

/**
 * Send shift assignment notification.
 */
async function notifyShiftAssigned(phone, staffName, date, startTime, endTime) {
    return sendSMS(
        phone,
        `Hi ${staffName}, you've been assigned a shift on ${date} from ${startTime} to ${endTime}. — CareShift`
    );
}

/**
 * Send leave decision notification.
 */
async function notifyLeaveDecision(phone, staffName, status, startDate, endDate) {
    const action = status === 'approved' ? 'approved ✅' : 'rejected ❌';
    return sendSMS(
        phone,
        `Hi ${staffName}, your leave request (${startDate} to ${endDate}) has been ${action}. — CareShift`
    );
}

module.exports = {
    sendSMS,
    notifyShiftAssigned,
    notifyLeaveDecision,
    isEnabled: () => enabled,
};
