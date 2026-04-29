const emailWorker = require('./emailWorker');
const notificationWorker = require('./notificationWorker');
require('./refundWorker');

console.log('=================================');
console.log('BullMQ Workers Starting...');
console.log('=================================');
console.log('✓ Email worker started');
console.log('✓ Notification worker started');
console.log('✓ Refund worker started');
console.log('=================================');
console.log('Workers are running. Press Ctrl+C to stop.');
console.log('=================================');

// Graceful shutdown
const gracefulShutdown = async (signal) => {
  console.log(`\n${signal} received. Shutting down workers gracefully...`);
  
  try {
    await Promise.all([
      emailWorker.close(),
      notificationWorker.close()
    ]);
    console.log('✓ All workers closed successfully');
    process.exit(0);
  } catch (error) {
    console.error('✗ Error during shutdown:', error.message);
    process.exit(1);
  }
};

process.on('SIGINT', gracefulShutdown);
process.on('SIGTERM', gracefulShutdown);

// Handle uncaught errors
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  gracefulShutdown('SIGTERM');
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  gracefulShutdown('SIGTERM');
});
