const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const dataDir = path.resolve(__dirname, '..', 'data', process.env.SYNTHETIC_DATASET || 'synthetic');
const read = (name) => JSON.parse(fs.readFileSync(path.join(dataDir, `${name}.json`), 'utf8'));

async function main() {
  const users = read('users');
  const routes = read('routes');
  const schedules = read('student-schedules');
  const rides = read('rides');
  const bookings = read('bookings');
  const reviews = read('reviews');
  const requests = read('auto-requests');
  const password = await bcrypt.hash('CampusPool123!', 10);

  await prisma.$transaction(async (tx) => {
    const oldUsers = await tx.user.findMany({
      where: {
        OR: [
          { email: { endsWith: '@synthetic.campus.pool' } },
          { email: { endsWith: '@seed.campus.pool' } },
        ],
      },
      select: { id: true },
    });
    const oldIds = oldUsers.map((user) => user.id);
    if (oldIds.length) {
      await tx.review.deleteMany({ where: { OR: [{ reviewerId: { in: oldIds } }, { revieweeId: { in: oldIds } }] } });
      await tx.autoGroupMember.deleteMany({ where: { userId: { in: oldIds } } });
      await tx.autoRequest.deleteMany({ where: { userId: { in: oldIds } } });
      await tx.booking.deleteMany({ where: { passengerId: { in: oldIds } } });
      await tx.ride.deleteMany({ where: { driverId: { in: oldIds } } });
      await tx.studentSchedule.deleteMany({ where: { userId: { in: oldIds } } });
      await tx.user.deleteMany({ where: { id: { in: oldIds } } });
    }
    await tx.autoGroup.deleteMany({ where: { id: { startsWith: 'synthetic-group-' } } });

    const oldCorridors = await tx.corridor.findMany({
      where: { sourceFile: { in: routes.map((route) => route.sourceFile) } },
      select: { id: true },
    });
    const corridorIds = oldCorridors.map((corridor) => corridor.id);
    if (corridorIds.length) {
      await tx.corridorHub.deleteMany({ where: { corridorId: { in: corridorIds } } });
      await tx.corridor.deleteMany({ where: { id: { in: corridorIds } } });
    }

    await tx.user.createMany({
      data: users.map(({ password: _, ...user }) => ({ ...user, password })),
    });
    for (const route of routes) {
      await tx.corridor.create({
        data: {
          id: route.id,
          name: route.name,
          sourceFile: route.sourceFile,
          originName: route.originName,
          destinationName: route.destinationName,
          routeData: route,
          hubs: {
            create: route.hubs.map((hub) => ({
              id: `${route.id.slice(0, 8)}-${hub.id.slice(9, 18)}-${hub.sequence}`,
              sequence: hub.sequence,
              hub: {
                connectOrCreate: {
                  where: { normalizedName: hub.normalizedName },
                  create: {
                    id: hub.id,
                    name: hub.name,
                    normalizedName: hub.normalizedName,
                    latitude: hub.latitude,
                    longitude: hub.longitude,
                  },
                },
              },
            })),
          },
        },
      });
    }
    await tx.studentSchedule.createMany({ data: schedules });
    await tx.ride.createMany({ data: rides.map(({ originSequence, destinationSequence, classDate, scheduleId, collegeStartTime, collegeEndTime, ridePurpose, ...ride }) => ride) });
    await tx.booking.createMany({ data: bookings });
    await tx.review.createMany({ data: reviews });
    await tx.autoRequest.createMany({ data: requests });
    const matchedRequests = requests.filter((request) => request.status === 'MATCHED');
    const grouped = new Map();
    for (const request of matchedRequests) {
      const key = `${request.normalizedPickupName}:${request.normalizedDestinationName}:${request.desiredDepartureTime}`;
      const bucket = grouped.get(key) || [];
      bucket.push(request);
      grouped.set(key, bucket);
    }
    let groupIndex = 0;
    for (const bucket of grouped.values()) {
      for (let offset = 0; offset < bucket.length; offset += 4) {
        const members = bucket.slice(offset, offset + 4);
        if (members.length < 3) continue;
        const first = members[0];
        const group = await tx.autoGroup.create({
          data: {
            id: `synthetic-group-${String(groupIndex).padStart(4, '0')}`,
            pickupName: first.pickupName,
            normalizedPickupName: first.normalizedPickupName,
            destinationName: first.destinationName,
            normalizedDestinationName: first.normalizedDestinationName,
            departureTime: first.desiredDepartureTime,
            status: 'READY',
            members: {
              create: members.map((request) => ({
                id: `synthetic-member-${request.id}`,
                userId: request.userId,
                requestId: request.id,
              })),
            },
          },
        });
        void group;
        groupIndex += 1;
      }
    }
  }, { maxWait: 120000, timeout: 120000 });

  console.log(`Imported synthetic dataset from ${dataDir}`);
  console.log(JSON.stringify({ users: users.length, schedules: schedules.length, rides: rides.length, bookings: bookings.length, reviews: reviews.length, autoRequests: requests.length }));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}).finally(() => prisma.$disconnect());
