const hasSharedRouteSegment = (requests, sequenceByHubId) => {
  if (requests.length < 2) return false;

  let direction;
  let sharedStart = -Infinity;
  let sharedEnd = Infinity;

  for (const request of requests) {
    const pickupSequence = sequenceByHubId.get(request.pickupHubId);
    const destinationSequence = sequenceByHubId.get(request.destinationHubId);
    if (!Number.isInteger(pickupSequence) || !Number.isInteger(destinationSequence)) {
      return false;
    }

    const requestDirection = Math.sign(destinationSequence - pickupSequence);
    if (requestDirection === 0 || (direction && requestDirection !== direction)) {
      return false;
    }
    direction = requestDirection;
    sharedStart = Math.max(sharedStart, Math.min(pickupSequence, destinationSequence));
    sharedEnd = Math.min(sharedEnd, Math.max(pickupSequence, destinationSequence));
  }

  return sharedStart < sharedEnd;
};

module.exports = { hasSharedRouteSegment };
