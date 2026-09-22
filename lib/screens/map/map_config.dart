// lib/screens/map/map_config.dart

import 'package:maplibre_gl/maplibre_gl.dart';

class MapConfig {
  // OpenFreeMap compatible style URL (demotiles provided by MapLibre)
  static const String styleUrl = 'https://demotiles.maplibre.org/style.json';

  // Initial camera position – campus coordinates provided by user
  static const CameraPosition initialCameraPosition = CameraPosition(
    target: LatLng(18.46439, 73.86749),
    zoom: 14,
  );
}
