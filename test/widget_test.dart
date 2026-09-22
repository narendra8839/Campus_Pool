import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_pool/main.dart';
import 'package:campus_pool/models/ride_model.dart';

void main() {
  testWidgets('CampusPoolApp loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusPoolApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('RideModel converts ISO UTC times to the device local timezone', () {
    final ride = RideModel.fromJson({
      'id': 'ride_1',
      'driverId': 'driver_1',
      'originName': 'Campus',
      'destName': 'Library',
      'departureTime': '2025-06-01T16:00:00Z',
      'createdAt': '2025-06-01T00:00:00Z',
      'updatedAt': '2025-06-01T00:00:00Z',
    });

    expect(ride.departureTime, DateTime.utc(2025, 6, 1, 16, 0, 0).toLocal());
  });
}
