const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const helmet = require('helmet');
const compression = require('compression');
const connectDB = require('./config/db');
const { apiLimiter, authLimiter } = require('./middleware/rateLimiter');

// Load environment variables (override system env vars with .env values)
const path = require('path');
dotenv.config({ path: path.resolve(__dirname, '../.env'), override: true });

// Connect to MongoDB
connectDB();

const app = express();

// --------------- Scalability & Security Middleware ---------------

// Trust proxy if behind a load balancer / reverse proxy (Nginx, ALB, etc.)
app.set('trust proxy', 1);

// Security HTTP headers (HSTS, X-Frame-Options, X-Content-Type, etc.)
app.use(helmet());

// Gzip / Brotli compression for all responses (reduces payload ~70%)
app.use(compression());

// Global rate limiter — 100 req/min per IP
app.use('/api/', apiLimiter);

// Allow requests from Flutter app (restrict origins in production)
const allowedOrigins = [
  process.env.FRONTEND_URL || 'http://localhost:8080',
  'http://localhost:3000',
  'http://localhost:5000',
];
app.use(cors({
  origin: function (origin, callback) {
    // Allow requests with no origin (mobile apps, curl, server-to-server)
    if (!origin) return callback(null, true);
    if (allowedOrigins.includes(origin)) return callback(null, true);
    return callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
}));

// Parse JSON request bodies (10mb limit for base64 image uploads)
app.use(express.json({ limit: '10mb' }));

// Request timeout — 30 seconds (prevents hung connections)
app.use((req, res, next) => {
  req.setTimeout(30000);
  res.setTimeout(30000);
  next();
});

// --------------- Routes ---------------

// Stricter rate limit on auth routes (15 attempts / 15 min)
app.use('/api/auth', authLimiter, require('./routes/authRoutes'));
app.use('/api/users', require('./routes/userRoutes'));
app.use('/api/settings', require('./routes/settingsRoutes'));
app.use('/api/shifts', require('./routes/shiftRoutes'));
app.use('/api/attendance', require('./routes/attendanceRoutes'));
app.use('/api/leave', require('./routes/leaveRoutes'));
app.use('/api/payroll', require('./routes/payrollRoutes'));
app.use('/api/reports', require('./routes/reportRoutes'));
app.use('/api/alerts', require('./routes/alertRoutes'));
app.use('/api/qr', require('./routes/qrRoutes'));

// Health check endpoint (includes DB status)
app.get('/api/health', (req, res) => {
  const mongoose = require('mongoose');
  const dbState = mongoose.connection.readyState;
  // 0 = disconnected, 1 = connected, 2 = connecting, 3 = disconnecting
  const dbStatus = dbState === 1 ? 'connected' : dbState === 2 ? 'connecting' : 'disconnected';
  const httpStatus = dbState === 1 ? 200 : 503;
  res.status(httpStatus).json({
    status: dbState === 1 ? 'ok' : 'degraded',
    message: 'CareShift API is running',
    database: dbStatus,
  });
});

// --------------- Error Handler ---------------

// Handle 404 - route not found
app.use((req, res) => {
  res.status(404).json({ message: `Route ${req.originalUrl} not found` });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    message: 'Something went wrong on the server',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined,
  });
});

// --------------- Start Server ---------------

const PORT = process.env.PORT || 5000;

const server = app.listen(PORT, () => {
  console.log(`\n=================================`);
  console.log(`  CareShift API Server`);
  console.log(`  Port: ${PORT}`);
  console.log(`  Mode: ${process.env.NODE_ENV || 'development'}`);
  console.log(`  PID:  ${process.pid}`);
  console.log(`=================================\n`);
});

// Keep-alive timeout must exceed the load balancer idle timeout (default 60s)
server.keepAliveTimeout = 65000;
server.headersTimeout = 66000;

// --------------- Graceful Shutdown ---------------

function gracefulShutdown(signal) {
  console.log(`\n${signal} received — shutting down gracefully…`);
  server.close(() => {
    const mongoose = require('mongoose');
    mongoose.connection.close(false).then(() => {
      console.log('MongoDB connection closed.');
      process.exit(0);
    });
  });
  // Force exit after 10 seconds if connections aren't drained
  setTimeout(() => {
    console.error('Forced shutdown after timeout.');
    process.exit(1);
  }, 10000);
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
