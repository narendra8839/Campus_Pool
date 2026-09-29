import 'package:flutter/foundation.dart';

import '../models/geocoding_result.dart';
import '../models/route_result.dart';

class RoutePreviewStore extends ChangeNotifier {
  RoutePreviewStore._();

  static final RoutePreviewStore instance = RoutePreviewStore._();

  RouteResult? _route;
  GeocodingResult? _origin;
  GeocodingResult? _destination;

  RouteResult? get route => _route;
  GeocodingResult? get origin => _origin;
  GeocodingResult? get destination => _destination;

  void setPreview({
    required RouteResult route,
    required GeocodingResult origin,
    required GeocodingResult destination,
  }) {
    _route = route;
    _origin = origin;
    _destination = destination;
    notifyListeners();
  }

  void clear() {
    if (_route == null && _origin == null && _destination == null) return;
    _route = null;
    _origin = null;
    _destination = null;
    notifyListeners();
  }
}
