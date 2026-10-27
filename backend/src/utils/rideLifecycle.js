const RIDE_TRANSITIONS = {
  SCHEDULED: new Set(['ONGOING', 'CANCELLED']),
  ONGOING: new Set(['COMPLETED']),
  COMPLETED: new Set(),
  CANCELLED: new Set(),
};

function canTransitionRideStatus(currentStatus, nextStatus) {
  return RIDE_TRANSITIONS[currentStatus]?.has(nextStatus) ?? false;
}

module.exports = { canTransitionRideStatus };
