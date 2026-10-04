import { jwttoken } from '#utils/jwt.js';
import { cookies } from '#utils/cookies.js';
import logger from '#config/logger.js';

export const authenticateToken = (req, res, next) => {
  try {
    let token = cookies.get(req, 'token');

    if (!token && req.headers.authorization) {
      const parts = req.headers.authorization.split(' ');
      if (parts.length === 2 && parts[0] === 'Bearer') {
        token = parts[1];
      }
    }

    if (!token) {
      return res.status(401).json({
        error: 'Authentication required',
        message: 'No authorization token provided',
      });
    }

    const decoded = jwttoken.verify(token);
    req.user = decoded;
    next();
  } catch (err) {
    logger.error('Authentication error:', err.message);
    return res.status(401).json({
      error: 'Invalid token',
      message: 'Token is invalid or expired',
    });
  }
};

export const requireRole = (roles = []) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        message: 'User must be authenticated',
      });
    }

    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        error: 'Access denied',
        message: 'Insufficient permissions',
      });
    }

    next();
  };
};
