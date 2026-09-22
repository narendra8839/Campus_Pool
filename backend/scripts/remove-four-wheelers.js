const prisma = require('../src/config/prisma');

async function main() {
  const deletedRides = await prisma.ride.deleteMany({
    where: { vehicleType: { notIn: ['bike', 'scooty'] } },
  });
  const resetUsers = await prisma.user.updateMany({
    where: { vehicleType: { notIn: ['bike', 'scooty'] } },
    data: { vehicleType: 'bike', vehicleModel: '', vehiclePlate: '', vehicleColor: '', vehicleSeats: 1 },
  });

  console.log(`Deleted ${deletedRides.count} four-wheeler rides and reset ${resetUsers.count} user vehicle records.`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
