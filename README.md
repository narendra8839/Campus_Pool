# Campus_Pool
Building an app for college students to share rides along the same route.

The Auto Groups feature lets students choose a mapped corridor, pickup stop, drop-off stop, and departure time. Requests can join a group when they travel in the same direction, share a non-zero segment of that corridor, and depart within 15 minutes of the group. Destinations do not need to match; groups are limited to four students and become ready at three.

After reviewing the target database, apply the new nullable corridor and stop references by running `npm run prisma:push` from the `backend` directory before deploying the updated API.
