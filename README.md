# Campus_Pool
Building an app for college students to share rides along the same route.

Auto Groups work as a small marketplace: students create a group listing, browse open listings, and send a join request with their own stops and departure time. The organizer approves or declines each request. Trips must share part of the same corridor in the same direction and depart within 15 minutes; groups hold three or four students and become ready at three.

Bike and scooter rides default to accepting passengers of any gender. Bikers can select a passenger gender preference, and seekers can filter by biker gender; incompatible rides and booking requests are excluded. Matching uses self-declared profile gender, and an undisclosed gender only matches rides set to any gender.

Ride offers prefill the start from the biker's current location (with permission); the biker can adjust it on the map. The destination is searched and confirmed on the map. The app previews the OSRM road route before publishing, and the backend stores the route geometry with the ride.

Seekers select pickup and drop-off points by tapping within 50 m of the biker's route; the selected coordinates are stored with the booking. The backend verifies both points are within 75 m of the route and that pickup comes before drop-off. For older rides without saved route geometry, the app and backend recalculate a route from the saved endpoints when possible. Bikers can open a map preview of the route and the seeker's two points from the request queue.

Flutter debug builds try the local API before the hosted API. To explicitly select a local API, run with `--dart-define=API_BASE_URL=http://localhost:5000/api` (use `http://10.0.2.2:5000/api` for an Android emulator). Restart the backend after controller changes and restart the Flutter app after changing the API URL.

Before deploying the updated API, apply the schema changes to the intended database by running `npm run prisma:push` from the `backend` directory.
