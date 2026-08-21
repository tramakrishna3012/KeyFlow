const express = require('express');
const router = express.Router();
const { registerUser, loginUser } = require('../services/authService');
const { authenticateToken } = require('../middleware/auth');
const { get } = require('../services/db');

router.post('/register', async (req, res, next) => {
  try {
    const { email, password, fullName, role, organizationName } = req.body;
    if (!email || !password || !fullName) {
      return res.status(400).json({ error: 'email, password, and fullName are required' });
    }

    if (password.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters long' });
    }

    const result = await registerUser({
      email,
      password,
      fullName,
      role: role || 'member',
      organizationName: organizationName || 'Look Enterprise Org',
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.status(201).json(result);
  } catch (err) {
    next(err);
  }
});

router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'email and password are required' });
    }

    const result = await loginUser({
      email,
      password,
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.json(result);
  } catch (err) {
    next(err);
  }
});

router.get('/me', authenticateToken, async (req, res, next) => {
  try {
    const user = await get(
      `SELECT u.id, u.email, u.full_name as fullName, u.role, u.is_active, u.created_at, o.name as organizationName
       FROM users u
       LEFT JOIN organizations o ON u.organization_id = o.id
       WHERE u.id = ?`,
      [req.user.id]
    );

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
