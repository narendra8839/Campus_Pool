import 'package:flutter_test/flutter_test.dart';
import 'package:campus_pool/utils/ride_fare.dart';

void main() {
  test('calculates and formats the per-seat fare at five rupees per km', () {
    expect(estimateRideFare(1000), 5);
    expect(formatRideFare(12340), '₹61.70');
  });
}
