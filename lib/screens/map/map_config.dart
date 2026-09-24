// lib/screens/map/map_config.dart

import 'package:maplibre_gl/maplibre_gl.dart';

class MapConfig {
  // OpenFreeMap's public Liberty style does not require an API key.
  static const String styleUrl = 'https://tiles.openfreemap.org/styles/liberty';

  // Initial camera position – campus coordinates provided by user
  static const CameraPosition initialCameraPosition = CameraPosition(
    target: LatLng(18.46439, 73.86749),
    zoom: 14,
  );
}
