const prisma = require('../config/prisma');
const { hasSharedRouteSegment } = require('../utils/autoGroupMatching');

const ACTIVE_MEMBER_STATUSES = ['JOINED', 'CONFIRMED'];
const OPEN_GROUP_STATUSES = ['FORMING', 'READY'];
const READY_MEMBER_COUNT = 3;
const MATCH_WINDOW_MINUTES = 15;
const INTERACTIVE_TRANSACTION_OPTIONS = { maxWait: 10000, timeout: 15000 };

const fail = (statusCode, message) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  throw error;
};

const getRouteStops = async (tx, corridorId) => {
  const corridor = await tx.corridor.findUnique({
    where: { id: corridorId },
    include: {
      hubs: {
        orderBy: { sequence: 'asc' },
        include: { hub: { select: { id: true, name: true } } },
      },
    },
  });
  if (!corridor) fail(404, 'Selected route was not found.');
  return corridor;
};

const getTripDetails = (corridor, pickupHubId, destinationHubId) => {
  const sequenceByHubId = new Map(
    corridor.hubs.map(({ hub, sequence }) => [hub.id, sequence]),
  );
  if (
    !sequenceByHubId.has(pickupHubId) ||
    !sequenceByHubId.has(destinationHubId) ||
    sequenceByHubId.get(pickupHubId) === sequenceByHubId.get(destinationHubId)
  ) {
    fail(400, 'Choose two different stops on the selected route.');
  }
  if (sequenceByHubId.get(pickupHubId) > sequenceByHubId.get(destinationHubId)) {
    fail(400, 'Choose stops in the direction of travel on the selected route.');
  }

  return {
    pickupName: corridor.hubs.find(({ hub }) => hub.id === pickupHubId).hub.name,
    destinationName: corridor.hubs.find(({ hub }) => hub.id === destinationHubId).hub.name,
    sequenceByHubId,
  };
};

const parseDepartureTime = (value) => {
  const departureTime = new Date(value);
  if (!value || Number.isNaN(departureTime.getTime()) || departureTime <= new Date()) {
    fail(400, 'Desired departure time must be a future date and time.');
  }
  return departureTime;
};

const groupListingInclude = {
  corridor: { select: { id: true, name: true } },
  organizer: { select: { id: true, name: true, avatar: true } },
  members: {
    where: { status: { in: ACTIVE_MEMBER_STATUSES } },
    include: {
      user: { select: { id: true, name: true, avatar: true } },
      request: {
        select: {
          pickupHubId: true,
          destinationHubId: true,
          pickupName: true,
          destinationName: true,
        },
      },
    },
    orderBy: { joinedAt: 'asc' },
  },
};

const createAutoGroupListing = async (req, res, next) => {
  try {
    const { corridorId, pickupHubId, destinationHubId, desiredDepartureTime } = req.body;
    if (
      typeof corridorId !== 'string' ||
      typeof pickupHubId !== 'string' ||
      typeof destinationHubId !== 'string'
    ) {
      return res.status(400).json({
        success: false,
        message: 'corridorId, pickupHubId, and destinationHubId are required.',
      });
    }
    const maxMembers = Number(req.body.maxMembers ?? 4);
    if (!Number.isInteger(maxMembers) || maxMembers < READY_MEMBER_COUNT || maxMembers > 4) {
      return res.status(400).json({ success: false, message: 'Group size must be 3 or 4 students.' });
    }
    const departureTime = parseDepartureTime(desiredDepartureTime);

    const group = await prisma.$transaction(async (tx) => {
      const existingMembership = await tx.autoGroupMember.findFirst({
        where: { userId: req.user.id, status: { in: ACTIVE_MEMBER_STATUSES } },
      });
      if (existingMembership) {
        fail(409, 'Leave your current auto group before creating another group.');
      }

      const corridor = await getRouteStops(tx, corridorId);
      const trip = getTripDetails(corridor, pickupHubId, destinationHubId);
      const request = await tx.autoRequest.create({
        data: {
          userId: req.user.id,
          corridorId,
          pickupHubId,
          destinationHubId,
          pickupName: trip.pickupName,
          normalizedPickupName: trip.pickupName.trim().replace(/\s+/g, ' ').toLowerCase(),
          destinationName: trip.destinationName,
          normalizedDestinationName: trip.destinationName.trim().replace(/\s+/g, ' ').toLowerCase(),
          desiredDepartureTime: departureTime,
          status: 'MATCHED',
        },
      });
      const created = await tx.autoGroup.create({
        data: {
          organizerId: req.user.id,
          corridorId,
          pickupName: trip.pickupName,
          normalizedPickupName: trip.pickupName.trim().replace(/\s+/g, ' ').toLowerCase(),
          destinationName: trip.destinationName,
          normalizedDestinationName: trip.destinationName.trim().replace(/\s+/g, ' ').toLowerCase(),
          departureTime,
          maxMembers,
          status: 'FORMING',
          members: {
            create: { userId: req.user.id, requestId: request.id },
          },
        },
        include: groupListingInclude,
      });
      return created;
    }, INTERACTIVE_TRANSACTION_OPTIONS);

    res.status(201).json({ success: true, message: 'Your auto group is now listed.', data: group });
  } catch (error) {
    if (error.statusCode) return res.status(error.statusCode).json({ success: false, message: error.message });
    if (error.code === 'P2034') {
      return res.status(409).json({ success: false, message: 'Your group could not be listed because your membership changed. Please refresh and try again.' });
    }
    next(error);
  }
};

const browseAutoGroups = async (req, res, next) => {
  try {
    const groups = await prisma.autoGroup.findMany({
      where: {
        AND: [
          { organizerId: { not: null } },
          { organizerId: { not: req.user.id } },
          {
            members: {
              none: {
                userId: req.user.id,
                status: { in: ACTIVE_MEMBER_STATUSES },
              },
            },
          },
        ],
        status: { in: OPEN_GROUP_STATUSES },
        departureTime: { gt: new Date() },
        members: { some: { status: { in: ACTIVE_MEMBER_STATUSES } } },
      },
      include: {
        ...groupListingInclude,
        joinRequests: {
          where: { userId: req.user.id },
          select: {
            id: true,
            status: true,
            pickupName: true,
            destinationName: true,
          },
        },
      },
      orderBy: { departureTime: 'asc' },
      take: 100,
    });
    const data = groups.filter((group) => group.members.length < group.maxMembers);
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    next(error);
  }
};

const requestToJoinAutoGroup = async (req, res, next) => {
  try {
    const { pickupHubId, destinationHubId, desiredDepartureTime } = req.body;
    if (typeof pickupHubId !== 'string' || typeof destinationHubId !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'pickupHubId and destinationHubId are required.',
      });
    }
    const departureTime = parseDepartureTime(desiredDepartureTime);

    const result = await prisma.$transaction(async (tx) => {
      const group = await tx.autoGroup.findUnique({
        where: { id: req.params.id },
        include: {
          ...groupListingInclude,
          members: {
            where: { status: { in: ACTIVE_MEMBER_STATUSES } },
            include: { request: { select: { pickupHubId: true, destinationHubId: true } } },
          },
        },
      });
      if (!group || !group.organizerId) fail(404, 'Auto group listing not found.');
      if (group.organizerId === req.user.id) fail(400, 'You cannot request to join your own group.');
      if (!OPEN_GROUP_STATUSES.includes(group.status) || group.departureTime <= new Date()) {
        fail(400, 'This group is no longer accepting join requests.');
      }
      if (group.members.length >= group.maxMembers) fail(409, 'This group is already full.');
      if (Math.abs(departureTime.getTime() - group.departureTime.getTime()) > MATCH_WINDOW_MINUTES * 60000) {
        fail(400, 'Your departure time must be within 15 minutes of this group.');
      }

      const activeMembership = await tx.autoGroupMember.findFirst({
        where: { userId: req.user.id, status: { in: ACTIVE_MEMBER_STATUSES } },
      });
      if (activeMembership) fail(409, 'Leave your current auto group before requesting to join another.');

      const corridor = await getRouteStops(tx, group.corridorId);
      const trip = getTripDetails(corridor, pickupHubId, destinationHubId);
      if (!hasSharedRouteSegment(
        [
          ...group.members.map(({ request }) => request),
          { pickupHubId, destinationHubId },
        ],
        trip.sequenceByHubId,
      )) {
        fail(400, 'Your trip must share part of this group’s route in the same direction.');
      }

      const previous = await tx.autoGroupJoinRequest.findUnique({
        where: { groupId_userId: { groupId: group.id, userId: req.user.id } },
      });
      if (previous?.status === 'PENDING') fail(409, 'Your join request is already waiting for the organizer.');
      if (previous?.status === 'ACCEPTED') fail(409, 'You are already a member of this group.');

      const request = await tx.autoGroupJoinRequest.upsert({
        where: { groupId_userId: { groupId: group.id, userId: req.user.id } },
        create: {
          groupId: group.id,
          userId: req.user.id,
          pickupHubId,
          destinationHubId,
          pickupName: trip.pickupName,
          destinationName: trip.destinationName,
          desiredDepartureTime: departureTime,
        },
        update: {
          pickupHubId,
          destinationHubId,
          pickupName: trip.pickupName,
          destinationName: trip.destinationName,
          desiredDepartureTime: departureTime,
          status: 'PENDING',
        },
      });
      return request;
    }, {
      ...INTERACTIVE_TRANSACTION_OPTIONS,
      isolationLevel: 'Serializable',
    });

    res.status(201).json({
      success: true,
      message: 'Join request sent to the group organizer.',
      data: result,
    });
  } catch (error) {
    if (error.statusCode) return res.status(error.statusCode).json({ success: false, message: error.message });
    if (error.code === 'P2034') {
      return res.status(409).json({ success: false, message: 'The group changed while you requested to join. Please try again.' });
    }
    next(error);
  }
};

const decideAutoGroupJoinRequest = async (req, res, next) => {
  try {
    const decision = req.body.decision?.toString().toUpperCase();
    if (!['ACCEPT', 'DECLINE'].includes(decision)) {
      return res.status(400).json({ success: false, message: 'decision must be ACCEPT or DECLINE.' });
    }

    const result = await prisma.$transaction(async (tx) => {
      const group = await tx.autoGroup.findUnique({
        where: { id: req.params.id },
        include: {
          members: {
            where: { status: { in: ACTIVE_MEMBER_STATUSES } },
            include: { request: { select: { pickupHubId: true, destinationHubId: true } } },
          },
        },
      });
      if (!group || group.organizerId !== req.user.id) fail(404, 'Auto group listing not found.');

      const request = await tx.autoGroupJoinRequest.findUnique({
        where: { id: req.params.requestId },
      });
      if (!request || request.groupId !== group.id) fail(404, 'Join request not found.');
      if (request.status !== 'PENDING') fail(409, 'This join request has already been handled.');
      if (decision === 'DECLINE') {
        return tx.autoGroupJoinRequest.update({
          where: { id: request.id },
          data: { status: 'DECLINED' },
          include: { user: { select: { id: true, name: true, avatar: true } } },
        });
      }

      if (!OPEN_GROUP_STATUSES.includes(group.status) || group.departureTime <= new Date()) {
        fail(400, 'This group is no longer accepting members.');
      }
      if (group.members.length >= group.maxMembers) fail(409, 'This group is already full.');
      const activeMembership = await tx.autoGroupMember.findFirst({
        where: { userId: request.userId, status: { in: ACTIVE_MEMBER_STATUSES } },
      });
      if (activeMembership) fail(409, 'This student is already in another active auto group.');

      const corridor = await getRouteStops(tx, group.corridorId);
      const trip = getTripDetails(corridor, request.pickupHubId, request.destinationHubId);
      if (Math.abs(request.desiredDepartureTime.getTime() - group.departureTime.getTime()) > MATCH_WINDOW_MINUTES * 60000 ||
        !hasSharedRouteSegment(
          [
            ...group.members.map(({ request: memberRequest }) => memberRequest),
            { pickupHubId: request.pickupHubId, destinationHubId: request.destinationHubId },
          ],
          trip.sequenceByHubId,
        )) {
        fail(400, 'This request no longer matches the group’s route or departure time.');
      }

      const autoRequest = await tx.autoRequest.create({
        data: {
          userId: request.userId,
          corridorId: group.corridorId,
          pickupHubId: request.pickupHubId,
          destinationHubId: request.destinationHubId,
          pickupName: request.pickupName,
          normalizedPickupName: request.pickupName.trim().replace(/\s+/g, ' ').toLowerCase(),
          destinationName: request.destinationName,
          normalizedDestinationName: request.destinationName.trim().replace(/\s+/g, ' ').toLowerCase(),
          desiredDepartureTime: request.desiredDepartureTime,
          status: 'MATCHED',
        },
      });
      await tx.autoGroupMember.create({
        data: { groupId: group.id, userId: request.userId, requestId: autoRequest.id },
      });
      const newStatus = group.members.length + 1 >= READY_MEMBER_COUNT ? 'READY' : 'FORMING';
      await tx.autoGroup.update({ where: { id: group.id }, data: { status: newStatus } });
      await tx.autoGroupJoinRequest.updateMany({
        where: {
          userId: request.userId,
          id: { not: request.id },
          status: 'PENDING',
        },
        data: { status: 'WITHDRAWN' },
      });
      return tx.autoGroupJoinRequest.update({
        where: { id: request.id },
        data: { status: 'ACCEPTED' },
        include: { user: { select: { id: true, name: true, avatar: true } } },
      });
    }, {
      ...INTERACTIVE_TRANSACTION_OPTIONS,
      isolationLevel: 'Serializable',
    });

    res.json({
      success: true,
      message: decision === 'ACCEPT' ? 'Student added to your auto group.' : 'Join request declined.',
      data: result,
    });
  } catch (error) {
    if (error.statusCode) return res.status(error.statusCode).json({ success: false, message: error.message });
    if (error.code === 'P2034') {
      return res.status(409).json({ success: false, message: 'The group changed while you handled this request. Please try again.' });
    }
    next(error);
  }
};

module.exports = {
  browseAutoGroups,
  createAutoGroupListing,
  decideAutoGroupJoinRequest,
  requestToJoinAutoGroup,
};
