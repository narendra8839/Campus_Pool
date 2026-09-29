import 'package:campus_pool/models/route_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'RouteResult parses road geometry and formats distance and duration',
    () {
      final route = RouteResult.fromJson({
        'distanceMeters': 2400.5,
        'durationSeconds': 3660,
        'coordinates': [
          [73.8, 18.5],
          [73.81, 18.51],
        ],
      });

      expect(route.coordinates, [
        [73.8, 18.5],
        [73.81, 18.51],
      ]);
      expect(route.formattedDistance, '2.4 km');
      expect(route.formattedDuration, '1h 1m');
    },
  );

  test('RouteResult rejects malformed geometry', () {
    expect(
      () => RouteResult.fromJson({
        'distanceMeters': 100,
        'durationSeconds': 30,
        'coordinates': [
          [200, 18.5],
          [73.81, 18.51],
        ],
      }),
      throwsFormatException,
    );
  });
}
