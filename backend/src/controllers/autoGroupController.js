const prisma = require('../config/prisma');
const { hasSharedRouteSegment } = require('../utils/autoGroupMatching');

const MATCH_WINDOW_MINUTES = 15;
const READY_MEMBER_COUNT = 3;

const normalisePlace = (value) => value.trim().replace(/\s+/g, ' ').toLowerCase();

const includeMembers = {
  include: {
    corridor: { select: { id: true, name: true } },
    members: {
      where: { status: { not: 'LEFT' } },
      include: {
        user: { select: { id: true, name: true, phone: true, avatar: true, rollNumber: true } },
        request: {
          select: {
            pickupName: true,
            destinationName: true,
            desiredDepartureTime: true,
            pickupHubId: true,
            destinationHubId: true,
          },
        },
      },
      orderBy: { joinedAt: 'asc' },
    },
  },
};

// POST /api/auto-groups/requests
// Match students on the same directed corridor with an overlapping route segment.
const createAutoRequest = async (req, res, next) => {
  try {
    const { corridorId, pickupHubId, destinationHubId, desiredDepartureTime } = req.body;
    if (
      typeof corridorId !== 'string' ||
      typeof pickupHubId !== 'string' ||
      typeof destinationHubId !== 'string' ||
      !desiredDepartureTime
    ) {
      return res.status(400).json({ success: false, message: 'corridorId, pickupHubId, destinationHubId, and desiredDepartureTime are required' });
    }

    const departureTime = new Date(desiredDepartureTime);
    if (Number.isNaN(departureTime.getTime()) || departureTime <= new Date()) {
      return res.status(400).json({ success: false, message: 'Desired departure time must be a future date and time' });
    }

    const windowStart = new Date(departureTime.getTime() - MATCH_WINDOW_MINUTES * 60 * 1000);
    const windowEnd = new Date(departureTime.getTime() + MATCH_WINDOW_MINUTES * 60 * 1000);

    const result = await prisma.$transaction(async (tx) => {
      const corridor = await tx.corridor.findUnique({
        where: { id: corridorId },
        include: {
          hubs: {
            orderBy: { sequence: 'asc' },
            include: { hub: { select: { id: true, name: true } } },
          },
        },
      });
      if (!corridor) {
        const error = new Error('Selected route was not found.');
        error.statusCode = 404;
        throw error;
      }

      const sequenceByHubId = new Map(
        corridor.hubs.map(({ hub, sequence }) => [hub.id, sequence]),
      );
      if (
        !sequenceByHubId.has(pickupHubId) ||
        !sequenceByHubId.has(destinationHubId) ||
        sequenceByHubId.get(pickupHubId) === sequenceByHubId.get(destinationHubId)
      ) {
        const error = new Error('Choose two different stops on the selected route.');
        error.statusCode = 400;
        throw error;
      }

      const pickupName = corridor.hubs.find(({ hub }) => hub.id === pickupHubId).hub.name;
      const destinationName = corridor.hubs.find(({ hub }) => hub.id === destinationHubId).hub.name;
      const normalizedPickupName = normalisePlace(pickupName);
      const normalizedDestinationName = normalisePlace(destinationName);

      const activeRequest = await tx.autoRequest.findFirst({
        where: { userId: req.user.id, status: { in: ['OPEN', 'MATCHED'] } },
      });
      if (activeRequest) {
        const error = new Error('You already have an active auto-group request. Leave or cancel it before creating another.');
        error.statusCode = 409;
        throw error;
      }

      const request = await tx.autoRequest.create({
        data: {
          userId: req.user.id,
          corridorId,
          pickupHubId,
          destinationHubId,
          pickupName,
          normalizedPickupName,
          destinationName,
          normalizedDestinationName,
          desiredDepartureTime: departureTime,
        },
      });

      const candidates = await tx.autoGroup.findMany({
        where: {
          status: { in: ['FORMING', 'READY'] },
          corridorId,
          departureTime: { gte: windowStart, lte: windowEnd },
        },
        ...includeMembers,
        orderBy: { createdAt: 'asc' },
      });
      const group = candidates.find((candidate) =>
        candidate.members.length < candidate.maxMembers &&
        hasSharedRouteSegment(
          [
            ...candidate.members.map((member) => member.request),
            { pickupHubId, destinationHubId },
          ],
          sequenceByHubId,
        ),
      );

      const targetGroup = group || await tx.autoGroup.create({
        data: {
          corridorId,
          pickupName,
          normalizedPickupName,
          destinationName,
          normalizedDestinationName,
          departureTime,
          maxMembers: 4,
        },
        ...includeMembers,
      });

      await tx.autoGroupMember.create({ data: { groupId: targetGroup.id, userId: req.user.id, requestId: request.id } });
      const memberCount = targetGroup.members.length + 1;
      const status = memberCount >= READY_MEMBER_COUNT ? 'READY' : 'FORMING';
      await tx.autoGroup.update({ where: { id: targetGroup.id }, data: { status } });
      await tx.autoRequest.update({ where: { id: request.id }, data: { status: 'MATCHED' } });

      return tx.autoGroup.findUnique({ where: { id: targetGroup.id }, ...includeMembers });
    });

    res.status(201).json({
      success: true,
      message: result.members.length >= READY_MEMBER_COUNT ? 'Auto group is ready. Confirm when your group agrees on the ride.' : 'Request added. We will form the group when more students match.',
      data: result,
    });
  } catch (error) {
    if (error.statusCode) return res.status(error.statusCode).json({ success: false, message: error.message });
    next(error);
  }
};

const getMyAutoGroups = async (req, res, next) => {
  try {
    const groups = await prisma.autoGroup.findMany({
      where: { members: { some: { userId: req.user.id, status: { not: 'LEFT' } } } },
      ...includeMembers,
      orderBy: { departureTime: 'asc' },
    });
    res.json({ success: true, count: groups.length, data: groups });
  } catch (error) { next(error); }
};

const getAutoGroup = async (req, res, next) => {
  try {
    const group = await prisma.autoGroup.findFirst({
      where: { id: req.params.id, members: { some: { userId: req.user.id, status: { not: 'LEFT' } } } },
      ...includeMembers,
    });
    if (!group) return res.status(404).json({ success: false, message: 'Auto group not found' });
    res.json({ success: true, data: group });
  } catch (error) { next(error); }
};

const confirmAutoGroup = async (req, res, next) => {
  try {
    const group = await prisma.autoGroup.findUnique({ where: { id: req.params.id }, ...includeMembers });
    if (!group) return res.status(404).json({ success: false, message: 'Auto group not found' });
    if (!['READY', 'CONFIRMED'].includes(group.status)) return res.status(400).json({ success: false, message: 'A group needs at least 3 members before confirmation' });
    const member = group.members.find((item) => item.userId === req.user.id);
    if (!member) return res.status(403).json({ success: false, message: 'You are not a member of this group' });

    const updated = await prisma.$transaction(async (tx) => {
      await tx.autoGroupMember.update({ where: { id: member.id }, data: { status: 'CONFIRMED' } });
      const currentMembers = await tx.autoGroupMember.findMany({ where: { groupId: group.id, status: { not: 'LEFT' } } });
      if (currentMembers.length >= READY_MEMBER_COUNT && currentMembers.every((item) => item.status === 'CONFIRMED' || item.id === member.id)) {
        await tx.autoGroup.update({ where: { id: group.id }, data: { status: 'CONFIRMED' } });
      }
      return tx.autoGroup.findUnique({ where: { id: group.id }, ...includeMembers });
    });
    res.json({ success: true, message: 'Your attendance has been confirmed.', data: updated });
  } catch (error) { next(error); }
};

const leaveAutoGroup = async (req, res, next) => {
  try {
    const membership = await prisma.autoGroupMember.findFirst({ where: { groupId: req.params.id, userId: req.user.id, status: { not: 'LEFT' } } });
    if (!membership) return res.status(404).json({ success: false, message: 'Active group membership not found' });
    const group = await prisma.$transaction(async (tx) => {
      await tx.autoGroupMember.update({ where: { id: membership.id }, data: { status: 'LEFT' } });
      await tx.autoRequest.update({ where: { id: membership.requestId }, data: { status: 'CANCELLED' } });
      const activeCount = await tx.autoGroupMember.count({ where: { groupId: req.params.id, status: { not: 'LEFT' } } });
      await tx.autoGroup.update({ where: { id: req.params.id }, data: { status: activeCount === 0 ? 'CANCELLED' : activeCount >= READY_MEMBER_COUNT ? 'READY' : 'FORMING' } });
      return tx.autoGroup.findUnique({ where: { id: req.params.id }, ...includeMembers });
    });
    res.json({ success: true, message: 'You left the auto group.', data: group });
  } catch (error) { next(error); }
};

module.exports = { createAutoRequest, getMyAutoGroups, getAutoGroup, confirmAutoGroup, leaveAutoGroup };
