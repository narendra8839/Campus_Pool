const { applicationDefault, cert, getApps, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

function getFirebaseAdminAuth() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw new Error('FIREBASE_PROJECT_ID must be configured.');
  }

  let app = getApps().find((existingApp) => existingApp.name === 'campus-pool-auth');
  if (!app) {
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    let credential = applicationDefault();
    if (serviceAccountJson) {
      let serviceAccount;
      try {
        serviceAccount = JSON.parse(serviceAccountJson);
      } catch (error) {
        throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON must contain valid JSON.', {
          cause: error,
        });
      }
      credential = cert(serviceAccount);
    }

    app = initializeApp(
      { credential, projectId },
      'campus-pool-auth',
    );
  }
  return getAuth(app);
}

module.exports = { getFirebaseAdminAuth };
