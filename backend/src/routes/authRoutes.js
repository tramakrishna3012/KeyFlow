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

    // Enhanced password validation
    if (password.length < 12) {
      return res.status(400).json({ error: 'Password must be at least 12 characters long' });
    }

    // Check password complexity
    const hasUpperCase = /[A-Z]/.test(password);
    const hasLowerCase = /[a-z]/.test(password);
    const hasNumber = /[0-9]/.test(password);
    const hasSpecialChar = /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password);

    if (!hasUpperCase || !hasLowerCase || !hasNumber || !hasSpecialChar) {
      return res.status(400).json({ 
        error: 'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character' 
      });
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
      `SELECT u.id, u.email, u.full_name, u.full_name as fullName, u.role, u.is_active, u.created_at, o.name as organizationName
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
