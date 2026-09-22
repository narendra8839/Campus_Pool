const FARE_PER_KILOMETRE = 5;

function distanceBetweenKilometres(first, second) {
  const earthRadiusKilometres = 6371;
  const latitudeDifference = ((second.latitude - first.latitude) * Math.PI) / 180;
  const longitudeDifference = ((second.longitude - first.longitude) * Math.PI) / 180;
  const firstLatitude = (first.latitude * Math.PI) / 180;
  const secondLatitude = (second.latitude * Math.PI) / 180;
  const haversine = Math.sin(latitudeDifference / 2) ** 2
    + Math.cos(firstLatitude) * Math.cos(secondLatitude)
    * Math.sin(longitudeDifference / 2) ** 2;

  return earthRadiusKilometres * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
}

function coordinate(value) {
  if (!value || !Number.isFinite(Number(value.latitude)) || !Number.isFinite(Number(value.longitude))) {
    return null;
  }
  return { latitude: Number(value.latitude), longitude: Number(value.longitude) };
}

function routeDistanceKilometres(origin, destination, waypoints = []) {
  const points = waypoints
    .map((point) => coordinate({
      latitude: point.latitude ?? point.lat,
      longitude: point.longitude ?? point.lng,
    }))
    .filter(Boolean);
  const start = coordinate(origin);
  const end = coordinate(destination);

  if (points.length >= 2) {
    return points.slice(1).reduce(
      (distance, point, index) => distance + distanceBetweenKilometres(points[index], point),
      0,
    );
  }
  if (start && end) return distanceBetweenKilometres(start, end);
  return 0;
}

function fareForDistance(distanceKilometres) {
  return Math.round(distanceKilometres * FARE_PER_KILOMETRE * 100) / 100;
}

module.exports = {
  FARE_PER_KILOMETRE,
  fareForDistance,
  routeDistanceKilometres,
};
