# Campus_Pool
Building an app for college students to share rides along the same route.

Auto Groups work as a small marketplace: students create a group listing, browse open listings, and send a join request with their own stops and departure time. The organizer approves or declines each request. Trips must share part of the same corridor in the same direction and depart within 15 minutes; groups hold three or four students and become ready at three.

Before deploying the updated API, apply the schema changes to the intended database by running `npm run prisma:push` from the `backend` directory.
