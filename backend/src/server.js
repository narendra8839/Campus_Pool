const dotenv = require('dotenv');

// Load environment variables before importing app and db
dotenv.config();

const app = require('./app');
const prisma = require('./config/prisma');

const PORT = process.env.PORT || 5000;

async function startServer() {
  try {
    // Test database connection if DATABASE_URL is provided
    if (process.env.DATABASE_URL) {
      await prisma.$connect();
      console.log('[Neon PostgreSQL] Connected successfully to database!');
    } else {
      console.warn('[Neon PostgreSQL] Warning: DATABASE_URL is not defined in .env');
    }

    const server = app.listen(PORT, () => {
      console.log(`===================================================`);
      console.log(`🚗 Campus Pool Backend Server Running (Postgres/Neon)`);
      console.log(`📡 Port: http://localhost:${PORT}`);
      console.log(`🩺 Health Check: http://localhost:${PORT}/health`);
      console.log(`📋 API Overview: http://localhost:${PORT}/api`);
      console.log(`⚙️  Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`===================================================`);
    });

    // Graceful shutdown
    const gracefulShutdown = async (signal) => {
      console.log(`\nReceived ${signal}. Gracefully shutting down...`);
      server.close(async () => {
        await prisma.$disconnect();
        console.log('[Neon PostgreSQL] Disconnected.');
        process.exit(0);
      });
    };

    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));
  } catch (error) {
    console.error(`[Server Error]: ${error.message}`);
  }
}

// Handle unhandled promise rejections
process.on('unhandledRejection', (err) => {
  console.error(`[UnhandledRejection Error]: ${err.message}`);
});

process.on('uncaughtException', (err) => {
  console.error(`[UncaughtException Error]: ${err.message}`);
});

startServer();
