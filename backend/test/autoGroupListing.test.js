const assert = require('node:assert/strict');
const { test } = require('node:test');
const prisma = require('../src/config/prisma');
const {
  createAutoGroupListing,
  decideAutoGroupJoinRequest,
  requestToJoinAutoGroup,
} = require('../src/controllers/autoGroupListingController');
const { getMyAutoGroups } = require('../src/controllers/autoGroupController');

const nowPlus = (minutes) => new Date(Date.now() + minutes * 60 * 1000);

const corridor = {
  hubs: [
    { sequence: 0, hub: { id: 'hub-0', name: 'Start' } },
    { sequence: 1, hub: { id: 'hub-1', name: 'Middle' } },
    { sequence: 2, hub: { id: 'hub-2', name: 'Near end' } },
    { sequence: 3, hub: { id: 'hub-3', name: 'End' } },
  ],
};

const group = {
  id: 'group-1',
  organizerId: 'organizer-1',
  corridorId: 'corridor-1',
  departureTime: nowPlus(60),
  maxMembers: 4,
  status: 'FORMING',
  members: [
    {
      userId: 'organizer-1',
      request: { pickupHubId: 'hub-0', destinationHubId: 'hub-3' },
    },
  ],
};

const mockResponse = () => ({
  statusCode: 200,
  body: undefined,
  status(code) {
    this.statusCode = code;
    return this;
  },
  json(body) {
    this.body = body;
    return this;
  },
});

const withTransactionMock = async (transaction, run) => {
  const original = prisma.$transaction;
  prisma.$transaction = transaction;
  try {
    await run();
  } finally {
    prisma.$transaction = original;
  }
};

test('creates a visible group listing with the organizer as its first member', async () => {
  const calls = {};
  const tx = {
    autoGroupMember: { findFirst: async () => null },
    corridor: { findUnique: async () => corridor },
    autoRequest: {
      create: async ({ data }) => {
        calls.request = data;
        return { id: 'owner-request-1' };
      },
    },
    autoGroup: {
      create: async ({ data }) => {
        calls.group = data;
        return { id: 'group-1', ...data };
      },
    },
  };
  const response = mockResponse();
  let transactionOptions;

  await withTransactionMock((callback, options) => {
    transactionOptions = options;
    return callback(tx);
  }, async () => {
    await createAutoGroupListing(
      {
        user: { id: 'organizer-1' },
        body: {
          corridorId: 'corridor-1',
          pickupHubId: 'hub-0',
          destinationHubId: 'hub-3',
          desiredDepartureTime: nowPlus(60).toISOString(),
          maxMembers: 4,
        },
      },
      response,
      assert.fail,
    );
  });

  assert.equal(response.statusCode, 201);
  assert.equal(calls.group.organizerId, 'organizer-1');
  assert.equal(calls.group.status, 'FORMING');
  assert.equal(calls.group.members.create.userId, 'organizer-1');
  assert.equal(calls.request.status, 'MATCHED');
  assert.equal(transactionOptions.maxWait, 10000);
  assert.equal(transactionOptions.timeout, 15000);
});

test('creates a group listing traveling in reverse along the corridor', async () => {
  const calls = {};
  const tx = {
    autoGroupMember: { findFirst: async () => null },
    corridor: { findUnique: async () => corridor },
    autoRequest: {
      create: async ({ data }) => {
        calls.request = data;
        return { id: 'owner-request-1' };
      },
    },
    autoGroup: {
      create: async ({ data }) => {
        calls.group = data;
        return { id: 'group-1', ...data };
      },
    },
  };
  const response = mockResponse();

  await withTransactionMock((callback) => callback(tx), async () => {
    await createAutoGroupListing(
      {
        user: { id: 'organizer-1' },
        body: {
          corridorId: 'corridor-1',
          pickupHubId: 'hub-3',
          destinationHubId: 'hub-0',
          desiredDepartureTime: nowPlus(60).toISOString(),
        },
      },
      response,
      assert.fail,
    );
  });

  assert.equal(response.statusCode, 201);
  assert.equal(calls.request.pickupName, 'End');
  assert.equal(calls.request.destinationName, 'Start');
  assert.equal(calls.group.pickupName, 'End');
  assert.equal(calls.group.destinationName, 'Start');
});

test('creates a pending join request for a compatible trip', async () => {
  const joinRequest = { id: 'join-request-1', status: 'PENDING' };
  const tx = {
    autoGroup: { findUnique: async () => group },
    autoGroupMember: { findFirst: async () => null },
    corridor: { findUnique: async () => corridor },
    autoGroupJoinRequest: {
      findUnique: async () => null,
      upsert: async ({ create }) => ({ ...joinRequest, ...create }),
    },
  };
  const response = mockResponse();

  await withTransactionMock((callback) => callback(tx), async () => {
    await requestToJoinAutoGroup(
      {
        user: { id: 'student-2' },
        params: { id: 'group-1' },
        body: {
          pickupHubId: 'hub-1',
          destinationHubId: 'hub-3',
          desiredDepartureTime: nowPlus(65).toISOString(),
        },
      },
      response,
      assert.fail,
    );
  });

  assert.equal(response.statusCode, 201);
  assert.equal(response.body.data.status, 'PENDING');
  assert.equal(response.body.data.pickupName, 'Middle');
  assert.equal(response.body.data.destinationName, 'End');
});

test('rejects a join pickup before the organizer pickup stop', async () => {
  const groupStartingAtMiddle = {
    ...group,
    members: [
      {
        userId: 'organizer-1',
        request: { pickupHubId: 'hub-1', destinationHubId: 'hub-3' },
      },
    ],
  };
  const tx = {
    autoGroup: { findUnique: async () => groupStartingAtMiddle },
    autoGroupMember: { findFirst: async () => null },
    corridor: { findUnique: async () => corridor },
  };
  const response = mockResponse();

  await withTransactionMock((callback) => callback(tx), async () => {
    await requestToJoinAutoGroup(
      {
        user: { id: 'student-2' },
        params: { id: 'group-1' },
        body: {
          pickupHubId: 'hub-0',
          destinationHubId: 'hub-3',
          desiredDepartureTime: nowPlus(65).toISOString(),
        },
      },
      response,
      assert.fail,
    );
  });

  assert.equal(response.statusCode, 400);
  assert.equal(
    response.body.message,
    'Choose a pickup stop at or after the organizer’s pickup stop.',
  );
});

test('does not approve a pending join request with pickup before organizer', async () => {
  const groupStartingAtMiddle = {
    ...group,
    members: [
      {
        userId: 'organizer-1',
        request: { pickupHubId: 'hub-1', destinationHubId: 'hub-3' },
      },
    ],
  };
  const tx = {
    autoGroup: { findUnique: async () => groupStartingAtMiddle },
    autoGroupJoinRequest: {
      findUnique: async () => ({
        id: 'join-request-1',
        groupId: 'group-1',
        userId: 'student-2',
        pickupHubId: 'hub-0',
        destinationHubId: 'hub-3',
        pickupName: 'Start',
        destinationName: 'End',
        desiredDepartureTime: nowPlus(65),
        status: 'PENDING',
      }),
    },
    autoGroupMember: { findFirst: async () => null },
    corridor: { findUnique: async () => corridor },
  };
  const response = mockResponse();

  await withTransactionMock((callback) => callback(tx), async () => {
    await decideAutoGroupJoinRequest(
      {
        user: { id: 'organizer-1' },
        params: { id: 'group-1', requestId: 'join-request-1' },
        body: { decision: 'ACCEPT' },
      },
      response,
      assert.fail,
    );
  });

  assert.equal(response.statusCode, 400);
  assert.equal(
    response.body.message,
    'Choose a pickup stop at or after the organizer’s pickup stop.',
  );
});

test('allows joining a reverse-direction group at or after organizer pickup', async () => {
  const reverseGroup = {
    ...group,
    members: [
      {
        userId: 'organizer-1',
        request: { pickupHubId: 'hub-3', destinationHubId: 'hub-0' },
      },
    ],
  };
  const tx = {
    autoGroup: { findUnique: async () => reverseGroup },
    autoGroupMember: { findFirst: async () => null },
    corridor: { findUnique: async () => corridor },
    autoGroupJoinRequest: {
      findUnique: async () => null,
      upsert: async ({ create }) => ({ id: 'join-request-1', status: 'PENDING', ...create }),
    },
  };
  const response = mockResponse();

  await withTransactionMock((callback) => callback(tx), async () => {
    await requestToJoinAutoGroup(
      {
        user: { id: 'student-2' },
        params: { id: 'group-1' },
        body: {
          pickupHubId: 'hub-2',
          destinationHubId: 'hub-0',
          desiredDepartureTime: nowPlus(65).toISOString(),
        },
      },
      response,
      assert.fail,
    );
  });

  assert.equal(response.statusCode, 201);
  assert.equal(response.body.data.pickupName, 'Near end');
});

test('rejects joining a reverse-direction group with a pickup before organizer', async () => {
  const reverseGroup = {
    ...group,
    members: [
      {
        userId: 'organizer-1',
        request: { pickupHubId: 'hub-2', destinationHubId: 'hub-0' },
      },
    ],
  };
  const tx = {
    autoGroup: { findUnique: async () => reverseGroup },
    autoGroupMember: { findFirst: async () => null },
    corridor: { findUnique: async () => corridor },
  };
  const response = mockResponse();

  await withTransactionMock((callback) => callback(tx), async () => {
    await requestToJoinAutoGroup(
      {
        user: { id: 'student-2' },
        params: { id: 'group-1' },
        body: {
          pickupHubId: 'hub-3',
          destinationHubId: 'hub-0',
          desiredDepartureTime: nowPlus(65).toISOString(),
        },
      },
      response,
      assert.fail,
    );
  });

  assert.equal(response.statusCode, 400);
  assert.equal(
    response.body.message,
    'Choose a pickup stop at or after the organizer’s pickup stop.',
  );
});

test('accepting a pending join request adds a member and updates group readiness', async () => {
  const calls = {};
  const tx = {
    autoGroup: {
      findUnique: async () => ({
        ...group,
        members: [
          ...group.members,
          { userId: 'member-2', request: { pickupHubId: 'hub-0', destinationHubId: 'hub-2' } },
        ],
      }),
      update: async ({ data }) => { calls.groupUpdate = data; },
    },
    autoGroupJoinRequest: {
      findUnique: async () => ({
        id: 'join-request-1',
        groupId: 'group-1',
        userId: 'student-3',
        pickupHubId: 'hub-1',
        destinationHubId: 'hub-3',
        pickupName: 'Middle',
        destinationName: 'End',
        desiredDepartureTime: nowPlus(65),
        status: 'PENDING',
      }),
      updateMany: async ({ where, data }) => { calls.withdraw = { where, data }; },
      update: async ({ data }) => ({ id: 'join-request-1', ...data }),
    },
    autoGroupMember: { findFirst: async () => null, create: async ({ data }) => { calls.member = data; } },
    corridor: { findUnique: async () => corridor },
    autoRequest: { create: async ({ data }) => { calls.request = data; return { id: 'accepted-request-1' }; } },
  };
  const response = mockResponse();

  await withTransactionMock((callback) => callback(tx), async () => {
    await decideAutoGroupJoinRequest(
      {
        user: { id: 'organizer-1' },
        params: { id: 'group-1', requestId: 'join-request-1' },
        body: { decision: 'ACCEPT' },
      },
      response,
      assert.fail,
    );
  });

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.data.status, 'ACCEPTED');
  assert.equal(calls.member.userId, 'student-3');
  assert.equal(calls.member.requestId, 'accepted-request-1');
  assert.equal(calls.groupUpdate.status, 'READY');
  assert.equal(calls.withdraw.data.status, 'WITHDRAWN');
});

test('my groups excludes cancelled listings', async () => {
  const originalFindMany = prisma.autoGroup.findMany;
  let query;
  prisma.autoGroup.findMany = async (args) => {
    query = args;
    return [];
  };
  const response = mockResponse();

  try {
    await getMyAutoGroups(
      { user: { id: 'organizer-1' } },
      response,
      assert.fail,
    );
  } finally {
    prisma.autoGroup.findMany = originalFindMany;
  }

  assert.deepEqual(query.where.status, { not: 'CANCELLED' });
  assert.equal(response.body.count, 0);
});

test('my groups includes pending join requests for group organizers', async () => {
  const originalFindMany = prisma.autoGroup.findMany;
  const pendingRequest = {
    id: 'join-request-1',
    userId: 'student-2',
    status: 'PENDING',
    user: { id: 'student-2', name: 'Student Two', avatar: null },
  };
  prisma.autoGroup.findMany = async (args) => {
    assert.deepEqual(args.include.joinRequests.where, {
      status: { in: ['PENDING', 'DECLINED'] },
    });
    return [{
      id: 'group-1',
      organizerId: 'organizer-1',
      members: [{ userId: 'organizer-1', status: 'JOINED' }],
      joinRequests: [pendingRequest],
    }];
  };
  const response = mockResponse();

  try {
    await getMyAutoGroups(
      { user: { id: 'organizer-1' } },
      response,
      assert.fail,
    );
  } finally {
    prisma.autoGroup.findMany = originalFindMany;
  }

  assert.equal(response.body.data[0].isOrganizer, true);
  assert.deepEqual(response.body.data[0].joinRequests, [pendingRequest]);
});
