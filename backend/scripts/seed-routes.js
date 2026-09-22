/* Deterministic route-aware demo data. Run with: npm run seed:routes */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const root = path.resolve(__dirname, '..', '..');
const id = (kind, value) => {
  const hex = crypto.createHash('sha256').update(`${kind}:${value}`).digest('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-${(parseInt(hex.slice(16, 18), 16) & 0x3f | 0x80).toString(16)}${hex.slice(18, 20)}-${hex.slice(20, 32)}`;
};
const normalise = (value) => value.trim().replace(/\s+/g, ' ').toLowerCase();

function readCorridor(file, number) {
  const routeData = JSON.parse(
    fs.readFileSync(path.join(__dirname, '..', 'data', 'routes.json'), 'utf8'),
  );
  const corridor = routeData.corridors.find((item) => item.sourceFile === file);
  if (!corridor) throw new Error(`No normalized corridor data found for ${file}`);
  return {
    ...corridor,
    name: corridor.name || `Corridor ${number}`,
    hubs: corridor.hubs.map((hub) => ({ ...hub })),
  };
}

async function main() {
  const corridors = [readCorridor('Corridor_1.txt', 1), readCorridor('Corridor_2.txt', 2)];
  // Delete only generated records, making reruns safe without disturbing real accounts.
  const generatedUsers = await prisma.user.findMany({ where: { email: { endsWith: '@seed.campus.pool' } }, select: { id: true } });
  const userIds = generatedUsers.map((user) => user.id);
  if (userIds.length) {
    await prisma.review.deleteMany({ where: { reviewerId: { in: userIds } } });
    await prisma.autoGroupMember.deleteMany({ where: { userId: { in: userIds } } });
    await prisma.autoRequest.deleteMany({ where: { userId: { in: userIds } } });
    await prisma.booking.deleteMany({ where: { passengerId: { in: userIds } } });
    await prisma.ride.deleteMany({ where: { driverId: { in: userIds } } });
    await prisma.user.deleteMany({ where: { id: { in: userIds } } });
  }
  await prisma.autoGroup.deleteMany({ where: { id: id('auto-group', 'seed') } });
  await prisma.corridorHub.deleteMany({ where: { corridor: { sourceFile: { in: corridors.map((c) => c.sourceFile) } } } });
  await prisma.corridor.deleteMany({ where: { sourceFile: { in: corridors.map((c) => c.sourceFile) } } });
  const password = await bcrypt.hash('CampusPool123!', 10);
  const users = [];
  for (let i = 0; i < 8; i += 1) {
    users.push(await prisma.user.create({
      data: {
        id: id('user', i), name: `VIT Seed User ${i + 1}`, email: `user${i + 1}@seed.campus.pool`,
        password, phone: `90000000${String(i).padStart(2, '0')}`, college: 'VIT Pune',
        rollNumber: `SEED${String(i + 1).padStart(3, '0')}`, vehicleType: i % 2 ? 'scooty' : 'bike', vehicleSeats: 1,
      },
    }));
  }
  const routeRecords = [];
  for (const route of corridors) {
    const corridor = await prisma.corridor.create({
      data: { id: id('corridor', route.name), name: route.name, sourceFile: route.sourceFile, originName: route.originName, destinationName: route.destinationName, routeData: route },
    });
    const links = [];
    for (const [sequence, item] of route.hubs.entries()) {
      const hub = await prisma.hub.upsert({
        where: { normalizedName: normalise(item.name) },
        update: { latitude: item.latitude, longitude: item.longitude },
        create: { id: id('hub', item.name), name: item.name, normalizedName: normalise(item.name), latitude: item.latitude, longitude: item.longitude },
      });
      links.push(await prisma.corridorHub.create({ data: { id: id('corridor-hub', `${route.name}:${hub.id}`), corridorId: corridor.id, hubId: hub.id, sequence } }));
    }
    routeRecords.push({ corridor, links });
  }
  const vit = await prisma.hub.findUnique({ where: { normalizedName: 'vit college' } });
  const rides = [];
  for (let i = 0; i < routeRecords.length; i += 1) {
    const { corridor, links } = routeRecords[i];
    const origin = links[0];
    const end = links[links.length - 2] || links[links.length - 1];
    const date = i === 0 ? '2027-01-11' : '2027-01-12';
    const morning = await prisma.ride.create({ data: {
      id: id('ride', `${i}:morning`), driverId: users[i].id, corridorId: corridor.id, originHubId: origin.hubId, destinationHubId: vit.id,
      originName: corridor.originName, destName: corridor.destinationName, departureTime: new Date(`${date}T07:45:00+05:30`),
      totalSeats: 1, availableSeats: 1, vehicleType: 'bike', waypoints: route.hubs || [],
    } });
    const evening = await prisma.ride.create({ data: {
      id: id('ride', `${i}:evening`), driverId: users[i + 2].id, corridorId: corridor.id, originHubId: vit.id, destinationHubId: end.hubId,
      originName: corridor.destinationName, destName: route.hubs[route.hubs.length - 2].name, departureTime: new Date(`${date}T17:30:00+05:30`),
      totalSeats: 1, availableSeats: 1, vehicleType: 'scooty', waypoints: route.hubs || [],
    } });
    rides.push(morning, evening);
  }
  const booking = await prisma.booking.create({ data: {
    id: id('booking', 'seed'), rideId: rides[0].id, passengerId: users[2].id, pickupName: 'Market Yard Corner',
    dropName: 'VIT College', seatsRequested: 1, status: 'ACCEPTED', fareAmount: 50, verificationOtp: '1234',
  } });
  await prisma.ride.update({ where: { id: rides[0].id }, data: { availableSeats: 0 } });
  await prisma.review.create({ data: { id: id('review', 'seed'), rideId: rides[0].id, reviewerId: users[0].id, revieweeId: users[2].id, rating: 5, comment: 'Great commute.' } });
  const group = await prisma.autoGroup.create({ data: { id: id('auto-group', 'seed'), pickupName: corridors[0].originName, normalizedPickupName: normalise(corridors[0].originName), destinationName: 'VIT College', normalizedDestinationName: 'vit college', departureTime: new Date('2027-01-13T07:30:00+05:30') } });
  for (let i = 3; i < 6; i += 1) {
    const request = await prisma.autoRequest.create({ data: { id: id('auto-request', i), userId: users[i].id, pickupName: corridors[0].originName, normalizedPickupName: normalise(corridors[0].originName), destinationName: 'VIT College', normalizedDestinationName: 'vit college', desiredDepartureTime: group.departureTime, status: 'MATCHED' } });
    await prisma.autoGroupMember.create({ data: { id: id('auto-member', i), groupId: group.id, userId: users[i].id, requestId: request.id } });
  }
  await prisma.autoGroup.update({ where: { id: group.id }, data: { status: 'READY' } });
  console.log(`Seeded ${corridors.length} corridors, ${rides.length} rides, 1 booking, 1 review and 3 auto requests.`);
}

main().catch((error) => { console.error(error); process.exitCode = 1; }).finally(() => prisma.$disconnect());
