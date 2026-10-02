const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.resolve(__dirname, '..');
const OUTPUT_DIR = process.env.SYNTHETIC_OUTPUT_DIR
  ? path.resolve(process.env.SYNTHETIC_OUTPUT_DIR)
  : path.join(ROOT, 'data', 'synthetic');
const ROUTES_FILE = path.join(ROOT, 'data', 'routes.json');
const REFERENCE_DATE = new Date('2026-09-21T12:00:00+05:30');
const SEED = 20260921;

const CONFIG = {
  users: 500,
  rides: 1000,
  bookings: 3000,
  reviews: 900,
  autoRequests: 600,
};

const statuses = {
  ride: ['COMPLETED', 'COMPLETED', 'COMPLETED', 'CANCELLED', 'SCHEDULED'],
  booking: ['COMPLETED', 'ACCEPTED', 'PENDING', 'REJECTED', 'CANCELLED'],
};

const names = [
  'Aarav Sharma', 'Ananya Patil', 'Vihaan Kulkarni', 'Isha Deshmukh',
  'Aditya Joshi', 'Meera Shah', 'Rohan Jadhav', 'Sneha More',
  'Kabir Pawar', 'Aditi Bhosale', 'Siddharth Naik', 'Riya Chavan',
];
const vehicleTypes = ['bike', 'scooty'];
const vehicleModels = {
  bike: ['Honda Shine', 'Bajaj Pulsar 150', 'TVS Apache'],
  scooty: ['Honda Activa', 'TVS Jupiter', 'Suzuki Access'],
};

function hashId(kind, value) {
  const hex = crypto.createHash('sha256').update(`${kind}:${value}`).digest('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-${(parseInt(hex.slice(16, 18), 16) & 0x3f | 0x80).toString(16)}${hex.slice(18, 20)}-${hex.slice(20, 32)}`;
}

function normalise(value) {
  return value.trim().replace(/\s+/g, ' ').toLowerCase();
}

function createRandom(seed) {
  let value = seed >>> 0;
  return () => {
    value = (value * 1664525 + 1013904223) >>> 0;
    return value / 0x100000000;
  };
}

function pick(random, values) {
  return values[Math.floor(random() * values.length)];
}

function integer(random, min, max) {
  return min + Math.floor(random() * (max - min + 1));
}

function isoDate(date) {
  return date.toISOString();
}

function csvValue(value) {
  const text = value == null ? '' : Array.isArray(value) || typeof value === 'object'
    ? JSON.stringify(value)
    : String(value);
  return `"${text.replace(/"/g, '""')}"`;
}

function writeJson(name, value) {
  fs.writeFileSync(path.join(OUTPUT_DIR, `${name}.json`), `${JSON.stringify(value, null, 2)}\n`);
}

function writeCsv(name, rows) {
  if (!rows.length) return;
  const headers = Object.keys(rows[0]);
  const lines = [
    headers.map(csvValue).join(','),
    ...rows.map((row) => headers.map((header) => csvValue(row[header])).join(',')),
  ];
  fs.writeFileSync(path.join(OUTPUT_DIR, `${name}.csv`), `${lines.join('\n')}\n`);
}

function loadRoutes() {
  const source = JSON.parse(fs.readFileSync(ROUTES_FILE, 'utf8'));
  if (!Array.isArray(source.corridors) || source.corridors.length !== 2) {
    throw new Error('routes.json must contain exactly two corridors');
  }

  const corridors = source.corridors.map((corridor) => {
    if (!Array.isArray(corridor.hubs) || corridor.hubs.length < 3) {
      throw new Error(`Corridor ${corridor.name} must contain at least three hubs`);
    }
    const hubs = corridor.hubs.map((hub, index) => ({
      id: hashId('hub', normalise(hub.name)),
      name: hub.name.trim(),
      normalizedName: normalise(hub.name),
      latitude: hub.latitude,
      longitude: hub.longitude,
      sequence: index + 1,
      type: hub.type || 'shared',
    }));
    return {
      id: corridor.id || hashId('corridor', corridor.name),
      name: corridor.name,
      sourceFile: corridor.sourceFile,
      originName: corridor.originName,
      destinationName: corridor.destinationName,
      hubs,
    };
  });

  return corridors;
}

function generateUsers(random) {
  return Array.from({ length: CONFIG.users }, (_, index) => {
    const isDriver = index < 350;
    const isBoth = index < 250;
    const vehicleType = pick(random, vehicleTypes);
    const displayName = `${names[index % names.length]} ${index + 1}`;
    return {
      id: hashId('user', index),
      name: displayName,
      email: `synthetic${String(index + 1).padStart(4, '0')}@synthetic.campus.pool`,
      phone: `91${String(7000000000 + index).padStart(10, '0')}`,
      college: 'VIT Pune',
      rollNumber: `SYN${String(index + 1).padStart(5, '0')}`,
      gender: index % 3 === 0 ? 'female' : index % 3 === 1 ? 'male' : 'prefer_not_to_say',
      roles: isDriver ? (isBoth ? ['rider', 'driver'] : ['driver']) : ['rider'],
      vehicleType: isDriver ? vehicleType : null,
      vehicleModel: isDriver ? pick(random, vehicleModels[vehicleType]) : null,
      vehiclePlate: isDriver ? `MH12${String.fromCharCode(65 + (index % 26))}${String(index).padStart(4, '0')}` : null,
      vehicleColor: isDriver ? pick(random, ['black', 'white', 'red', 'blue', 'silver']) : null,
      helmetProvided: isDriver ? random() > 0.15 : false,
      vehicleSeats: isDriver ? 1 : 0,
      ratingAvg: Number((3.8 + random() * 1.2).toFixed(2)),
      ratingCount: integer(random, 0, 35),
      isVerified: random() > 0.15,
      password: 'CampusPool123!',
    };
  });
}

function formatTime(minutes) {
  return `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`;
}

function generateSchedules(random, users) {
  const schedules = [];
  for (const user of users) {
    for (let dayOfWeek = 1; dayOfWeek <= 6; dayOfWeek += 1) {
      const hasClass = random() > 0.2;
      const startMinutes = integer(random, 8 * 60, 14 * 60);
      const duration = integer(random, 3 * 60, 4 * 60);
      schedules.push({
        id: hashId('schedule', `${user.id}:${dayOfWeek}`),
        userId: user.id,
        dayOfWeek,
        dayName: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][dayOfWeek - 1],
        hasClass,
        collegeStartTime: hasClass ? formatTime(startMinutes) : null,
        collegeEndTime: hasClass ? formatTime(Math.min(startMinutes + duration, 18 * 60)) : null,
        campusName: 'VIT College',
      });
    }
  }
  return schedules;
}

function chooseVitCommutePair(random, hubs, reverse) {
  const vitIndex = hubs.length - 1;
  if (reverse) {
    const destination = hubs[integer(random, 0, vitIndex - 1)];
    return [hubs[vitIndex], destination];
  }
  const origin = hubs[integer(random, 0, vitIndex - 1)];
  return [origin, hubs[vitIndex]];
}

function generateRides(random, corridors, users, schedules) {
  const drivers = users.filter((user) => user.roles.includes('driver'));
  const scheduleByUserDay = new Map(schedules.map((schedule) => [
    `${schedule.userId}:${schedule.dayOfWeek}`,
    schedule,
  ]));
  return Array.from({ length: CONFIG.rides }, (_, index) => {
    const corridor = corridors[index % corridors.length];
    const reverse = index % 2 === 1;
    const [origin, destination] = chooseVitCommutePair(random, corridor.hubs, reverse);
    const driver = drivers[index % drivers.length];
    let dayOffset = (index % 90) - 44;
    let date = new Date(REFERENCE_DATE.getTime() + dayOffset * 86400000);
    let schedule = scheduleByUserDay.get(`${driver.id}:${date.getDay()}`);
    for (let attempt = 0; !schedule?.hasClass && attempt < 7; attempt += 1) {
      dayOffset += 1;
      date = new Date(REFERENCE_DATE.getTime() + dayOffset * 86400000);
      schedule = scheduleByUserDay.get(`${driver.id}:${date.getDay()}`);
    }
    if (!schedule?.hasClass) {
      throw new Error(`No class schedule found for driver ${driver.id}`);
    }
    const [startHour, startMinute] = schedule.collegeStartTime.split(':').map(Number);
    const [endHour, endMinute] = schedule.collegeEndTime.split(':').map(Number);
    const classStart = startHour * 60 + startMinute;
    const classEnd = endHour * 60 + endMinute;
    const departureMinutes = reverse ? classEnd + 15 : classStart - 30;
    const departure = new Date(date);
    departure.setHours(Math.floor(departureMinutes / 60), departureMinutes % 60, 0, 0);
    const isPast = departure < REFERENCE_DATE;
    const vehicle = pick(random, vehicleTypes);
    const totalSeats = 1;
    const status = isPast ? pick(random, statuses.ride) : 'SCHEDULED';
    return {
      id: hashId('ride', index),
      driverId: driver.id,
      corridorId: corridor.id,
      originHubId: origin.id,
      destinationHubId: destination.id,
      originName: origin.name,
      originLat: origin.latitude,
      originLng: origin.longitude,
      destName: destination.name,
      destLat: destination.latitude,
      destLng: destination.longitude,
      departureTime: isoDate(departure),
      totalSeats,
      availableSeats: totalSeats,
      vehicleType: vehicle,
      helmetProvided: random() > 0.15,
      contribution: integer(random, 0, 30),
      notes: pick(random, ['', 'Morning campus commute', 'Pickup near the hub', 'Please arrive five minutes early']),
      status,
      classDate: date.toISOString().slice(0, 10),
      scheduleId: schedule.id,
      collegeStartTime: schedule.collegeStartTime,
      collegeEndTime: schedule.collegeEndTime,
      ridePurpose: reverse ? 'return_from_college' : 'travel_to_college',
      originSequence: corridor.hubs.find((hub) => hub.id === origin.id).sequence,
      destinationSequence: corridor.hubs.find((hub) => hub.id === destination.id).sequence,
    };
  });
}

function generateBookings(random, rides, users) {
  const bookings = [];
  const rideSeats = new Map(rides.map((ride) => [ride.id, ride.totalSeats]));
  for (let index = 0; index < CONFIG.bookings; index += 1) {
    const ride = rides[index % rides.length];
    const passenger = users[(index * 7 + 11) % users.length];
    const corridor = routesById.get(ride.corridorId);
    const originIndex = corridor.hubs.findIndex((hub) => hub.id === ride.originHubId);
    const destinationIndex = corridor.hubs.findIndex((hub) => hub.id === ride.destinationHubId);
    const pickup = corridor.hubs[originIndex];
    const drop = corridor.hubs[destinationIndex];
    let status = pick(random, statuses.booking);
    const seatsRequested = 1;
    if (['ACCEPTED', 'COMPLETED'].includes(status) && rideSeats.get(ride.id) < seatsRequested) {
      status = 'REJECTED';
    }
    if (['ACCEPTED', 'COMPLETED'].includes(status)) {
      rideSeats.set(ride.id, rideSeats.get(ride.id) - seatsRequested);
    }
    bookings.push({
      id: hashId('booking', index),
      rideId: ride.id,
      passengerId: passenger.id === ride.driverId ? users[(index + 1) % users.length].id : passenger.id,
      pickupName: pickup.name,
      pickupLat: pickup.latitude,
      pickupLng: pickup.longitude,
      dropName: drop.name,
      dropLat: drop.latitude,
      dropLng: drop.longitude,
      seatsRequested,
      status,
      passengerNote: pick(random, ['', 'I will wait at the hub', 'Please confirm pickup']),
      driverResponseNote: status === 'REJECTED' ? 'No seats available' : '',
      fareAmount: ride.contribution,
      verificationOtp: String(1000 + (index % 9000)),
      createdAt: isoDate(new Date(new Date(ride.departureTime).getTime() - integer(random, 1, 72) * 3600000)),
      updatedAt: isoDate(new Date(REFERENCE_DATE.getTime() - integer(random, 0, 20) * 3600000)),
    });
  }
  rides.forEach((ride) => {
    ride.availableSeats = rideSeats.get(ride.id);
  });
  return bookings;
}

function generateReviews(random, rides, bookings, users) {
  const candidates = [];
  const seen = new Set();
  const commentSets = {
    1: {
      reviews: [
        'The driver never arrived at the agreed pickup point.',
        'The driver cancelled the ride without warning.',
        'I could not reach the driver when it was time to leave.',
        'The driver left before I reached the pickup location.',
        'The pickup details changed without any notice.',
        'The driver did not show up after confirming the ride.',
        'I was left waiting with no explanation from the driver.',
        'The ride did not happen and I received no useful update.',
        'The driver ignored several messages about the pickup.',
        'The agreed pickup was missed and no alternative was offered.',
      ],
      followUps: [
        'I was left stranded.',
        'No one responded when I asked for an update.',
        'The trip disrupted my plans completely.',
        'I would not book this ride again.',
        'This was a very frustrating experience.',
        'I could not rely on this pickup.',
      ],
    },
    2: {
      reviews: [
        'The ride started much later than the agreed time.',
        'The driver was difficult to contact before pickup.',
        'The pickup point was confusing and took too long to resolve.',
        'The driver provided very little information about the delay.',
        'The vehicle was not comfortable for the trip.',
        'The route took longer than I expected.',
        'The driver changed the pickup plan at the last minute.',
        'The ride was completed, but the coordination was poor.',
        'I had to wait longer than expected for the driver.',
        'The trip felt poorly organized from the start.',
      ],
      followUps: [
        'The experience was below what I expected.',
        'Better communication would have helped.',
        'The delay made the trip inconvenient.',
        'I probably would not choose this ride again.',
        'The trip was more stressful than necessary.',
        'There was not much effort to keep me informed.',
      ],
    },
    3: {
      reviews: [
        'The ride was average overall.',
        'The trip met the basic expectations.',
        'The pickup and drop-off were both ordinary.',
        'The driver and I had a routine trip to campus.',
        'The ride was acceptable from start to finish.',
        'The experience was much like a typical commute.',
        'The trip went as expected without anything notable.',
        'The ride was neither especially good nor especially bad.',
        'The service was adequate for this journey.',
        'The trip was uneventful and straightforward.',
      ],
      followUps: [
        'Nothing in particular stood out.',
        'The overall experience was simply okay.',
        'It was a standard ride.',
        'I have no major feedback about the trip.',
        'The ride was fine for a regular commute.',
        'There were no notable surprises.',
      ],
    },
    4: {
      reviews: [
        'The driver was friendly and the pickup was well organized.',
        'The ride was comfortable and the driver was considerate.',
        'The driver communicated clearly before we set off.',
        'The trip to campus was smooth and pleasant.',
        'The driver arrived on time and made the ride easy.',
        'The vehicle was clean and comfortable for the journey.',
        'The driver chose a convenient route to campus.',
        'The pickup went smoothly and the trip was enjoyable.',
        'The driver was helpful throughout most of the ride.',
        'I had a good trip and felt comfortable as a passenger.',
      ],
      followUps: [
        'I would be happy to ride with them again.',
        'Overall, it was a good experience.',
        'The trip was pleasant from beginning to end.',
        'I appreciated the clear communication.',
        'The ride was a good option for my commute.',
        'I would recommend this ride to other students.',
      ],
    },
    5: {
      reviews: [
        'The driver was exceptionally friendly and arrived right on time.',
        'The ride was excellent and the driver communicated throughout.',
        'The pickup was effortless and the trip was very comfortable.',
        'The driver made sure I reached campus safely and promptly.',
        'Everything about the ride was smooth and well organized.',
        'The vehicle was spotless and the driver was very considerate.',
        'The route was efficient and the conversation was welcoming.',
        'The driver was reliable, courteous, and easy to coordinate with.',
        'I had a fantastic trip and would gladly book again.',
        'The ride exceeded my expectations in every way.',
      ],
      followUps: [
        'I would happily travel with this driver again.',
        'This was one of my best rides to campus.',
        'I highly recommend this driver.',
        'The whole experience was excellent.',
        'I felt safe and well looked after throughout.',
        'I would give this ride my strongest recommendation.',
      ],
    },
  };
  const reviewTemplates = Object.entries(commentSets).flatMap(([rating, set]) =>
    set.reviews.flatMap((review) => set.followUps.map((followUp) => ({
      rating: Number(rating),
      comment: `${review} ${followUp}`,
    }))),
  );
  for (const booking of bookings) {
    if (!['COMPLETED', 'ACCEPTED'].includes(booking.status)) continue;
    const ride = rides.find((item) => item.id === booking.rideId);
    const key = `${ride.id}:${booking.passengerId}:${ride.driverId}`;
    if (seen.has(key)) continue;
    seen.add(key);
    candidates.push({ ride, reviewerId: booking.passengerId });
  }
  return candidates.slice(0, CONFIG.reviews).map(({ ride, reviewerId }, index) => ({
      ...pick(random, reviewTemplates),
      id: hashId('review', index),
      rideId: ride.id,
      reviewerId,
      revieweeId: ride.driverId,
      createdAt: isoDate(new Date(new Date(ride.departureTime).getTime() + 3600000)),
      updatedAt: isoDate(new Date(new Date(ride.departureTime).getTime() + 3600000)),
  }));
}

function generateAutoRequests(random, corridors, users) {
  return Array.from({ length: CONFIG.autoRequests }, (_, index) => {
    const corridor = corridors[index % corridors.length];
    const pickup = corridor.hubs[index % Math.max(1, corridor.hubs.length - 2)];
    const destination = corridor.hubs[corridor.hubs.length - 1];
    const departure = new Date(REFERENCE_DATE.getTime() + ((index % 30) - 15) * 86400000);
    departure.setHours(8, (index % 4) * 15, 0, 0);
    return {
      id: hashId('auto-request', index),
      userId: users[(index * 3) % users.length].id,
      pickupName: pickup.name,
      normalizedPickupName: pickup.normalizedName,
      destinationName: destination.name,
      normalizedDestinationName: destination.normalizedName,
      desiredDepartureTime: isoDate(departure),
      status: index % 7 === 0 ? 'CANCELLED' : index % 3 === 0 ? 'MATCHED' : 'OPEN',
    };
  });
}

let routesById;

function main() {
  const random = createRandom(SEED);
  const corridors = loadRoutes();
  routesById = new Map(corridors.map((corridor) => [corridor.id, corridor]));
  const users = generateUsers(random);
  const schedules = generateSchedules(random, users);
  const rides = generateRides(random, corridors, users, schedules);
  const bookings = generateBookings(random, rides, users);
  const reviews = generateReviews(random, rides, bookings, users);
  const autoRequests = generateAutoRequests(random, corridors, users);
  const routeCatalog = corridors.map((corridor) => ({
    ...corridor,
    hubs: corridor.hubs.map(({ id, name, normalizedName, latitude, longitude, sequence, type }) => ({
      id, name, normalizedName, latitude, longitude, sequence, type,
    })),
  }));
  const manifest = {
    seed: SEED,
    referenceDate: REFERENCE_DATE.toISOString(),
    window: {
      start: new Date(REFERENCE_DATE.getTime() - 44 * 86400000).toISOString(),
      end: new Date(REFERENCE_DATE.getTime() + 45 * 86400000).toISOString(),
    },
    counts: {
      users: users.length,
      schedules: schedules.length,
      corridors: routeCatalog.length,
      hubs: new Set(routeCatalog.flatMap((corridor) => corridor.hubs.map((hub) => hub.id))).size,
      rides: rides.length,
      bookings: bookings.length,
      reviews: reviews.length,
      autoRequests: autoRequests.length,
    },
    password: 'CampusPool123!',
  };

  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  writeJson('manifest', manifest);
  writeJson('routes', routeCatalog);
  writeJson('users', users);
  writeJson('student-schedules', schedules);
  writeJson('rides', rides);
  writeJson('bookings', bookings);
  writeJson('reviews', reviews);
  writeJson('auto-requests', autoRequests);
  writeCsv('users', users);
  writeCsv('student-schedules', schedules);
  writeCsv('rides', rides);
  writeCsv('bookings', bookings);
  writeCsv('reviews', reviews);
  writeCsv('auto-requests', autoRequests);
  console.log(`Generated synthetic data in ${OUTPUT_DIR}`);
  console.log(JSON.stringify(manifest.counts));
}

if (require.main === module) {
  main();
}

module.exports = { createRandom, generateReviews };
