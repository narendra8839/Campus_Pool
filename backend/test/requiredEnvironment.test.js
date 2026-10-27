const test = require('node:test');
const assert = require('node:assert/strict');
const { assertRequiredEnvironment } = require('../src/utils/requiredEnvironment');

test('requires a database URL and Firebase project before server startup', () => {
  assert.throws(
    () => assertRequiredEnvironment({ FIREBASE_PROJECT_ID: 'test-project' }),
    /DATABASE_URL must be configured/,
  );
  assert.throws(
    () => assertRequiredEnvironment({ DATABASE_URL: 'postgresql://test' }),
    /FIREBASE_PROJECT_ID must be configured/,
  );
  assert.doesNotThrow(() => assertRequiredEnvironment({
    DATABASE_URL: 'postgresql://test',
    FIREBASE_PROJECT_ID: 'test-project',
  }));
});
