function assertRequiredEnvironment(environment = process.env) {
  for (const variable of ['DATABASE_URL', 'FIREBASE_PROJECT_ID']) {
    if (!environment[variable]) {
      throw new Error(`${variable} must be configured before starting the server.`);
    }
  }
}

module.exports = { assertRequiredEnvironment };
