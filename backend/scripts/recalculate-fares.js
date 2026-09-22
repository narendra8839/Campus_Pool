const prisma = require('../src/config/prisma');
const { fareForDistance, routeDistanceKilometres } = require('../src/utils/fareCalculator');

async function main() {
  const rides = await prisma.ride.findMany({
    select: {
      id: true,
      originLat: true,
      originLng: true,
      destLat: true,
      destLng: true,
      waypoints: true,
    },
  });

  for (const ride of rides) {
    const distance = routeDistanceKilometres(
      { latitude: ride.originLat, longitude: ride.originLng },
      { latitude: ride.destLat, longitude: ride.destLng },
      Array.isArray(ride.waypoints) ? ride.waypoints : [],
    );
    await prisma.ride.update({
      where: { id: ride.id },
      data: { contribution: fareForDistance(distance) },
    });
  }

  console.log(`Recalculated fares for ${rides.length} rides at ₹5/km per seat.`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
