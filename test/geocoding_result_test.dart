import 'package:flutter_test/flutter_test.dart';
import 'package:campus_pool/models/geocoding_result.dart';

void main() {
  test('GeocodingResult parses numeric coordinates', () {
    final result = GeocodingResult.fromJson({
      'placeId': '123',
      'displayName': 'Kothrud, Pune, India',
      'latitude': '18.5',
      'longitude': '73.8',
      'type': 'suburb',
    });

    expect(result.latitude, 18.5);
    expect(result.longitude, 73.8);
    expect(result.displayName, 'Kothrud, Pune, India');
  });

  test('GeocodingResult rejects out-of-range coordinates', () {
    expect(
      () => GeocodingResult.fromJson({
        'latitude': 91,
        'longitude': 73.8,
        'displayName': 'Invalid place',
      }),
      throwsFormatException,
    );
  });
}
