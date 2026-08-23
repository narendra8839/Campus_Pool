require('dotenv').config();
const prisma = require('./src/config/prisma');

async function testConnection() {
  console.log('--------------------------------------------------');
  console.log('🚀 Checking Neon PostgreSQL Connection & Tables...');
  console.log('--------------------------------------------------');
  try {
    const dbInfo = await prisma.$queryRaw`SELECT version(), current_database(), current_user;`;
    console.log('✅ PostgreSQL Connection: SUCCESS');
    console.log('   Database:', dbInfo[0].current_database);
    console.log('   User:', dbInfo[0].current_user);
    console.log('   Engine Version:', dbInfo[0].version.split(' ')[0], dbInfo[0].version.split(' ')[1]);

    // Check table counts
    const userCount = await prisma.user.count();
    const rideCount = await prisma.ride.count();
    const bookingCount = await prisma.booking.count();
    const reviewCount = await prisma.review.count();

    console.log('\n📊 Database Tables Verified:');
    console.log(`   - users: ${userCount} records`);
    console.log(`   - rides: ${rideCount} records`);
    console.log(`   - bookings: ${bookingCount} records`);
    console.log(`   - reviews: ${reviewCount} records`);
    console.log('\n🎉 ALL SYSTEMS GO: Neon PostgreSQL is connected and ready to use!');
    console.log('--------------------------------------------------');
    
    await prisma.$disconnect();
    process.exit(0);
  } catch (error) {
    console.error('❌ Connection Failed:', error.message);
    await prisma.$disconnect();
    process.exit(1);
  }
}

testConnection();
