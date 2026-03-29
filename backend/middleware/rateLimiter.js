// middleware/rateLimiter.js
// Rate limiting to prevent abuse and ensure fair concurrent access.

const rateLimit = require('express-rate-limit');

const isDev = process.env.NODE_ENV !== 'production';

// General API rate limiter — 100 req/min in production, 500 in dev
const apiLimiter = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: isDev ? 500 : 100,
    standardHeaders: true,  // Return rate limit info in `RateLimit-*` headers
    legacyHeaders: false,   // Disable `X-RateLimit-*` headers
    message: { message: 'Too many requests, please try again later.' },
});

// Stricter limiter for auth routes — 15 attempts / 15 min (prod), 60 in dev
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: isDev ? 60 : 15,
    standardHeaders: true,
    legacyHeaders: false,
    message: { message: 'Too many login attempts, please try again after 15 minutes.' },
});

module.exports = { apiLimiter, authLimiter };
