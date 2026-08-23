const notFound = (req, res, next) => {
  const error = new Error(`Not Found - ${req.originalUrl}`);
  res.status(404);
  next(error);
};

const errorHandler = (err, req, res, next) => {
  let statusCode = res.statusCode === 200 ? 500 : res.statusCode;
  let message = err.message;

  // Handle Prisma Unique Constraint Violation
  if (err.code === 'P2002') {
    statusCode = 400;
    const target = err.meta?.target ? err.meta.target.join(', ') : 'field';
    message = `A record with this ${target} already exists.`;
  }

  // Handle Prisma Record Not Found
  if (err.code === 'P2025') {
    statusCode = 404;
    message = 'Requested record not found in the database.';
  }

  // Handle Prisma Foreign Key Constraint Failure
  if (err.code === 'P2003') {
    statusCode = 400;
    message = 'Invalid reference: Related record does not exist.';
  }

  res.status(statusCode).json({
    success: false,
    message,
    stack: process.env.NODE_ENV === 'production' ? null : err.stack,
  });
};

module.exports = { notFound, errorHandler };
