const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  searchPlaces,
  reverseGeocode,
} = require('../src/services/nominatimService');
const { search, reverse } = require('../src/controllers/geocodingController');

test('search normalizes results and caches repeated queries', async () => {
  const originalFetch = global.fetch;
  const requests = [];
  global.fetch = async (url, options) => {
    requests.push({ url: new URL(url), options });
    return {
      ok: true,
      status: 200,
      json: async () => [{
        place_id: 123,
        display_name: 'Kothrud, Pune, Maharashtra, India',
        lat: '18.5074',
        lon: '73.8077',
        type: 'suburb',
        address: { suburb: 'Kothrud' },
      }],
    };
  };

  try {
    const first = await searchPlaces(' Kothrud   Pune ');
    const second = await searchPlaces('kothrud pune');

    assert.deepEqual(second, first);
    assert.equal(requests.length, 1);
    assert.equal(requests[0].url.pathname, '/search');
    assert.equal(requests[0].url.searchParams.get('format'), 'jsonv2');
    assert.equal(requests[0].url.searchParams.get('addressdetails'), '1');
    assert.match(requests[0].options.headers['User-Agent'], /CampusPool/);
    assert.deepEqual(first[0], {
      placeId: '123',
      displayName: 'Kothrud, Pune, Maharashtra, India',
      latitude: 18.5074,
      longitude: 73.8077,
      type: 'suburb',
      address: { suburb: 'Kothrud' },
    });
  } finally {
    global.fetch = originalFetch;
  }
});

test('reverse geocoding sends coordinates and parses the address', async () => {
  const originalFetch = global.fetch;
  let requestUrl;
  global.fetch = async (url) => {
    requestUrl = new URL(url);
    return {
      ok: true,
      status: 200,
      json: async () => ({
        place_id: 456,
        display_name: 'Kothrud, Pune, India',
        lat: '18.5',
        lon: '73.8',
        address: { suburb: 'Kothrud' },
      }),
    };
  };

  try {
    const place = await reverseGeocode(18.5, 73.8);
    assert.equal(requestUrl.pathname, '/reverse');
    assert.equal(requestUrl.searchParams.get('lat'), '18.5');
    assert.equal(requestUrl.searchParams.get('lon'), '73.8');
    assert.equal(place.displayName, 'Kothrud, Pune, India');
    assert.equal(place.latitude, 18.5);
  } finally {
    global.fetch = originalFetch;
  }
});

test('forward geocoding rejects queries shorter than three characters', async () => {
  let statusCode;
  let body;
  const response = {
    status(code) {
      statusCode = code;
      return this;
    },
    json(value) {
      body = value;
      return this;
    },
  };

  await search({ query: { q: 'ab' } }, response, (error) => {
    throw error;
  });

  assert.equal(statusCode, 400);
  assert.match(body.message, /3 and 200/);
});

test('reverse geocoding rejects out-of-range coordinates', async () => {
  let statusCode;
  const response = {
    status(code) {
      statusCode = code;
      return this;
    },
    json() {
      return this;
    },
  };

  await reverse({ query: { lat: '91', lon: '0' } }, response, (error) => {
    throw error;
  });

  assert.equal(statusCode, 400);
});
