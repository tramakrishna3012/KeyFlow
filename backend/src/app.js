const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { rateLimiter } = require('./middleware/rateLimiter');
const { errorHandler } = require('./middleware/errorHandler');

const authRoutes = require('./routes/authRoutes');
const activityRoutes = require('./routes/activityRoutes');
const adminRoutes = require('./routes/adminRoutes');
const complianceRoutes = require('./routes/complianceRoutes');
const appRoutes = require('./routes/appRoutes');
const sessionRoutes = require('./routes/sessionRoutes');
const clipboardRoutes = require('./routes/clipboardRoutes');

const app = express();

const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',')
  : ['http://localhost:3000', 'http://127.0.0.1:3000'];

// Security Headers & Cross-Origin Resource Sharing
app.use(helmet());
app.use(cors({
  origin: (origin, callback) => {
    const isAllowed = !origin ||
      allowedOrigins.includes('*') ||
      allowedOrigins.includes(origin) ||
      origin.endsWith('.pages.dev') ||
      origin.endsWith('.workers.dev') ||
      origin.includes('localhost') ||
      origin.includes('127.0.0.1') ||
      process.env.NODE_ENV !== 'production';

    if (isAllowed) {
      callback(null, true);
    } else {
      callback(new Error('Cross-Origin Request blocked by CORS policy'));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Body Parsing & IP Rate Limiting
app.use(express.json({ limit: '5mb' }));
app.use(rateLimiter({ windowMs: 60 * 1000, maxRequests: 200 }));

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'Look System API',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// API Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/activity', activityRoutes);
app.use('/api/v1/admin', adminRoutes);
app.use('/api/v1/compliance', complianceRoutes);
app.use('/api/v1/app', appRoutes);
app.use('/api/v1/sessions', sessionRoutes);
app.use('/api/v1/clipboard', clipboardRoutes);

// Compatibility Aliases
app.use('/api/sessions', sessionRoutes);
app.use('/api/clipboard', clipboardRoutes);

// Global Error Handler
app.use(errorHandler);

module.exports = app;
