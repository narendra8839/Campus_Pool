function withoutVerificationOtp(booking) {
  const { verificationOtp, ...safeBooking } = booking;
  return safeBooking;
}

module.exports = { withoutVerificationOtp };
