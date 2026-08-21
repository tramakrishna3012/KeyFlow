const requestBuckets = new Map();

function rateLimiter({ windowMs = 60 * 1000, maxRequests = 100, message = 'Too many requests, please try again later.' } = {}) {
  return (req, res, next) => {
    const ip = req.ip || req.connection.remoteAddress || 'unknown-ip';
    const now = Date.now();

    let bucket = requestBuckets.get(ip);
    if (!bucket) {
      bucket = { count: 1, resetTime: now + windowMs };
      requestBuckets.set(ip, bucket);
    } else {
      if (now > bucket.resetTime) {
        bucket.count = 1;
        bucket.resetTime = now + windowMs;
      } else {
        bucket.count += 1;
        if (bucket.count > maxRequests) {
          return res.status(429).json({
            error: message,
            retryAfterSeconds: Math.ceil((bucket.resetTime - now) / 1000)
          });
        }
      }
    }

    // Cleanup stale entries occasionally
    if (requestBuckets.size > 10000) {
      for (const [key, val] of requestBuckets.entries()) {
        if (now > val.resetTime) {
          requestBuckets.delete(key);
        }
      }
    }

    next();
  };
}

module.exports = {
  rateLimiter
};
