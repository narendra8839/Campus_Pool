const dotenv = require('dotenv');

// Load environment variables before importing app and db
dotenv.config();

const app = require('./app');
const prisma = require('./config/prisma');

const PORT = process.env.PORT || 5000;
const DATABASE_CONNECT_ATTEMPTS = 3;

async function connectToDatabase() {
  if (!process.env.DATABASE_URL) {
    console.warn('[Neon PostgreSQL] Warning: DATABASE_URL is not defined in .env');
    return;
  }

  let lastError;
  for (let attempt = 1; attempt <= DATABASE_CONNECT_ATTEMPTS; attempt += 1) {
    try {
      await prisma.$connect();
      console.log('[Neon PostgreSQL] Connected successfully to database!');
      return;
    } catch (error) {
      lastError = error;
      if (attempt < DATABASE_CONNECT_ATTEMPTS) {
        const delayMs = attempt * 2000;
        console.warn(
          `[Neon PostgreSQL] Connection attempt ${attempt} failed; retrying in ${delayMs}ms.`,
        );
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }
    }
  }

  throw lastError;
}

async function startServer() {
  try {
    await connectToDatabase();
    const server = app.listen(PORT, '0.0.0.0', () => {
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
    process.exitCode = 1;
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
