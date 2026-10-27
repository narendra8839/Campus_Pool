const CAMPUS_EMAIL_DOMAIN = 'vit.edu';

function validateFirebaseIdentity(identity) {
  if (
    !identity ||
    typeof identity.uid !== 'string' ||
    !identity.uid.trim() ||
    typeof identity.email !== 'string' ||
    identity.email_verified !== true
  ) {
    return { valid: false, message: 'A verified Firebase account is required.' };
  }

  const email = identity.email.trim().toLowerCase();
  const emailParts = email.split('@');
  if (
    emailParts.length !== 2 ||
    !emailParts[0] ||
    emailParts[1] !== CAMPUS_EMAIL_DOMAIN
  ) {
    return {
      valid: false,
      message: `Use a verified @${CAMPUS_EMAIL_DOMAIN} email address.`,
    };
  }

  return { valid: true, email };
}

module.exports = { CAMPUS_EMAIL_DOMAIN, validateFirebaseIdentity };
