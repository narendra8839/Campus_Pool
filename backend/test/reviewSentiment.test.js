const test = require('node:test');
const assert = require('node:assert/strict');
const { analyzeReviewSentiment } = require('../src/controllers/reviewController');

function mockResponse() {
  return {
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
  };
}

test('rejects blank and oversized sentiment text before calling the model', async () => {
  const response = mockResponse();
  let called = false;
  const originalFetch = global.fetch;
  global.fetch = async () => {
    called = true;
    throw new Error('unexpected model request');
  };

  try {
    await analyzeReviewSentiment({ body: { text: '   ' } }, response);
    assert.equal(response.statusCode, 400);
    await analyzeReviewSentiment({ body: { text: 'x'.repeat(5001) } }, response);
  } finally {
    global.fetch = originalFetch;
  }

  assert.equal(response.statusCode, 400);
  assert.equal(called, false);
});

test('forwards valid text and returns the model prediction', async () => {
  const response = mockResponse();
  const originalFetch = global.fetch;
  const originalUrl = process.env.SENTIMENT_SERVICE_URL;
  const originalApiKey = process.env.SENTIMENT_API_KEY;
  const requests = [];
  process.env.SENTIMENT_SERVICE_URL = 'http://sentiment.test/';
  process.env.SENTIMENT_API_KEY = 'test-sentiment-secret';
  global.fetch = async (url, options) => {
    requests.push({ url, options });
    if (requests.length === 1) {
      return {
        ok: true,
        json: async () => ({ event_id: 'event-123' }),
      };
    }
    return {
      ok: true,
      text: async () => 'event: complete\ndata: [{"sentiment":"positive","confidence":0.96}]\n\n',
    };
  };

  try {
    await analyzeReviewSentiment({ body: { text: '  Smooth ride  ' } }, response);
  } finally {
    global.fetch = originalFetch;
    if (originalUrl === undefined) delete process.env.SENTIMENT_SERVICE_URL;
    else process.env.SENTIMENT_SERVICE_URL = originalUrl;
    if (originalApiKey === undefined) delete process.env.SENTIMENT_API_KEY;
    else process.env.SENTIMENT_API_KEY = originalApiKey;
  }

  assert.equal(
    requests[0].url,
    'http://sentiment.test/gradio_api/call/v2/predict',
  );
  assert.deepEqual(JSON.parse(requests[0].options.body), {
    text: 'Smooth ride',
    api_key: 'test-sentiment-secret',
  });
  assert.equal(
    requests[1].url,
    'http://sentiment.test/gradio_api/call/predict/event-123',
  );
  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body.data, { sentiment: 'positive', confidence: 0.96 });
});

test('reports failed Gradio prediction events as unavailable', async () => {
  const response = mockResponse();
  const originalFetch = global.fetch;
  const originalApiKey = process.env.SENTIMENT_API_KEY;
  const originalConsoleError = console.error;
  process.env.SENTIMENT_API_KEY = 'test-sentiment-secret';
  console.error = () => {};
  let requestCount = 0;
  global.fetch = async () => {
    requestCount += 1;
    return requestCount === 1
      ? { ok: true, json: async () => ({ event_id: 'event-123' }) }
      : { ok: true, text: async () => 'event: error\ndata: "Model failed"\n\n' };
  };

  try {
    await analyzeReviewSentiment({ body: { text: 'Nice driver' } }, response);
  } finally {
    global.fetch = originalFetch;
    console.error = originalConsoleError;
    if (originalApiKey === undefined) delete process.env.SENTIMENT_API_KEY;
    else process.env.SENTIMENT_API_KEY = originalApiKey;
  }

  assert.equal(response.statusCode, 503);
  assert.equal(response.body.success, false);
});

test('reports the model as unavailable when inference fails', async () => {
  const response = mockResponse();
  const originalFetch = global.fetch;
  const originalConsoleError = console.error;
  const originalApiKey = process.env.SENTIMENT_API_KEY;
  process.env.SENTIMENT_API_KEY = 'test-sentiment-secret';
  global.fetch = async () => {
    throw new Error('connection refused');
  };
  console.error = () => {};

  try {
    await analyzeReviewSentiment({ body: { text: 'Nice driver' } }, response);
  } finally {
    global.fetch = originalFetch;
    console.error = originalConsoleError;
    if (originalApiKey === undefined) delete process.env.SENTIMENT_API_KEY;
    else process.env.SENTIMENT_API_KEY = originalApiKey;
  }

  assert.equal(response.statusCode, 503);
  assert.equal(response.body.success, false);
});

test('does not call the inference service without a configured shared secret', async () => {
  const response = mockResponse();
  const originalFetch = global.fetch;
  const originalApiKey = process.env.SENTIMENT_API_KEY;
  const originalConsoleError = console.error;
  let called = false;
  delete process.env.SENTIMENT_API_KEY;
  global.fetch = async () => {
    called = true;
    throw new Error('unexpected model request');
  };
  console.error = () => {};

  try {
    await analyzeReviewSentiment({ body: { text: 'Nice driver' } }, response);
  } finally {
    global.fetch = originalFetch;
    console.error = originalConsoleError;
    if (originalApiKey === undefined) delete process.env.SENTIMENT_API_KEY;
    else process.env.SENTIMENT_API_KEY = originalApiKey;
  }

  assert.equal(called, false);
  assert.equal(response.statusCode, 503);
});
