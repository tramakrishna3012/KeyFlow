function errorHandler(err, req, res, next) {
  // Log full error details for debugging (should go to secure logging system in production)
  if (process.env.NODE_ENV !== 'production') {
    console.error('[Look API Error]', err.stack || err.message);
  } else {
    // In production, log only error message and metadata (not full stack trace)
    console.error('[Look API Error]', {
      message: err.message,
      statusCode: err.statusCode,
      path: req.path,
      method: req.method,
      timestamp: new Date().toISOString()
    });
  }

  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';

  // Never send stack traces to client in production
  const response = {
    error: message
  };

  if (process.env.NODE_ENV === 'development') {
    response.stack = err.stack;
  }

  res.status(statusCode).json(response);
}

module.exports = {
  errorHandler
};
