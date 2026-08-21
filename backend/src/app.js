const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { rateLimiter } = require('./middleware/rateLimiter');
const { errorHandler } = require('./middleware/errorHandler');

const authRoutes = require('./routes/authRoutes');
const activityRoutes = require('./routes/activityRoutes');
const adminRoutes = require('./routes/adminRoutes');
const complianceRoutes = require('./routes/complianceRoutes');

const app = express();

// Security Headers & Cross-Origin Resource Sharing
app.use(helmet());
app.use(cors({
  origin: '*', // Configurable in production
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

// Global Error Handler
app.use(errorHandler);

module.exports = app;
