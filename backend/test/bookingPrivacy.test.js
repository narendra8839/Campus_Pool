const test = require('node:test');
const assert = require('node:assert/strict');
const { withoutVerificationOtp } = require('../src/utils/bookingPrivacy');

test('removes the passenger verification OTP from shared booking data', () => {
  const booking = {
    id: 'booking-1',
    status: 'ACCEPTED',
    verificationOtp: '4821',
  };

  const safeBooking = withoutVerificationOtp(booking);

  assert.deepEqual(safeBooking, {
    id: 'booking-1',
    status: 'ACCEPTED',
  });
  assert.equal(Object.hasOwn(safeBooking, 'verificationOtp'), false);
  assert.equal(booking.verificationOtp, '4821');
});
