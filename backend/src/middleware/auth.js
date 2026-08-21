const jwt = require('jsonwebtoken');
const { JWT_SECRET } = require('../config/env');
const { get } = require('../services/db');

async function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Authentication token required' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const user = await get('SELECT id, organization_id, email, full_name, role, is_active FROM users WHERE id = ?', [decoded.userId]);
    
    if (!user?.is_active) {
      return res.status(403).json({ error: 'User account is inactive or not found' });
    }

    req.user = user;
    next();
  } catch (err) {
    console.warn('[Auth Middleware Warning]', err.message);
    return res.status(403).json({ error: 'Invalid or expired authentication token' });
  }
}

function requireRole(allowedRoles = []) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Unauthenticated' });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        error: `Forbidden: requires one of the following roles: [${allowedRoles.join(', ')}]`
      });
    }

    next();
  };
}

module.exports = {
  authenticateToken,
  requireRole
};
