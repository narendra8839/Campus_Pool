import 'dart:math' show Point;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../models/corridor_model.dart';
import '../../models/geocoding_result.dart';
import '../../models/route_result.dart';
import '../../services/geocoding_service.dart';
import '../../services/route_service.dart';
import '../../services/routing_service.dart';
import 'map_config.dart';
import '../../utils/runtime_environment.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _styleLoaded = false;
  bool _styleTimedOut = false;
  String? _hubsError;
  int _hubCount = 0;
  int _corridorCount = 0;
  MapLibreMapController? _mapController;
  bool _hubsLoading = false;
  int _mapInstance = 0;
  final TextEditingController _searchController = TextEditingController();
  List<GeocodingResult> _searchResults = const [];
  GeocodingResult? _selectedPlace;
  Circle? _searchCircle;
  final List<Circle> _routeMarkers = [];
  Line? _routeLine;
  GeocodingResult? _routeOrigin;
  GeocodingResult? _routeDestination;
  RouteResult? _routeResult;
  String? _searchError;
  String? _routingError;
  bool _searchLoading = false;
  bool _reverseLoading = false;
  bool _routing = false;
  int _searchRequestId = 0;
  int _reverseRequestId = 0;
  int _mapSelectionRequestId = 0;
  int _routingRequestId = 0;

  @override
  void initState() {
    super.initState();
    if (!isFlutterTest) _startLoadTimeout();
  }

  void _startLoadTimeout() {
    Future<void>.delayed(const Duration(seconds: 12), () {
      if (mounted && !_styleLoaded) {
        _updateAfterFrame(() => _styleTimedOut = true);
      }
    });
  }

  void _updateAfterFrame(VoidCallback update) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(update);
    });
  }

  void _retryMap() {
    setState(() {
      _styleLoaded = false;
      _styleTimedOut = false;
      _hubsError = null;
      _hubCount = 0;
      _corridorCount = 0;
      _mapController = null;
      _hubsLoading = false;
      _searchCircle = null;
      _routeLine = null;
      _routeMarkers.clear();
      _mapSelectionRequestId++;
      _mapController = null;
      _mapInstance++;
    });
    _startLoadTimeout();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    ++_searchRequestId;
    ++_reverseRequestId;
    ++_mapSelectionRequestId;
    setState(() {
      _searchError = null;
      _searchResults = const [];
      _searchLoading = false;
      _reverseLoading = false;
      _selectedPlace = null;
      _routingError = null;
    });
    if (_searchCircle != null) {
      _removeSearchCircleSafely();
    }
  }

  Future<void> _searchPlaces() async {
    final query = _searchController.text.trim();
    if (query.length < 3) {
      setState(() => _searchError = 'Enter at least 3 characters to search.');
      return;
    }
    final requestId = ++_searchRequestId;
    FocusScope.of(context).unfocus();
    setState(() {
      _searchError = null;
      _searchResults = const [];
      _searchLoading = true;
    });

    try {
      final results = await GeocodingService.search(query);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchResults = results;
        _searchLoading = false;
        if (results.isEmpty) _searchError = 'No places found.';
      });
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchError = 'Place search failed: $error';
        _searchLoading = false;
      });
    }
  }

  Future<void> _selectPlace(GeocodingResult place) async {
    _reverseRequestId++;
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedPlace = place;
      _searchController.text = place.displayName;
      _searchResults = const [];
      _searchError = null;
      _searchLoading = false;
      _reverseLoading = false;
    });
    await _showPlaceOnMap(place);
  }

  Future<void> _onMapTap(Point<double> _, LatLng coordinates) async {
    final requestId = ++_reverseRequestId;
    ++_searchRequestId;
    ++_mapSelectionRequestId;
    setState(() {
      _searchController.clear();
      _searchResults = const [];
      _searchError = null;
      _searchLoading = false;
      _selectedPlace = null;
      _routingError = null;
      _reverseLoading = true;
    });
    try {
      await _removeSearchCircle();
      final place = await GeocodingService.reverse(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );
      if (!mounted || requestId != _reverseRequestId) return;
      setState(() {
        _selectedPlace = place;
        _searchController.text = place.displayName;
        _reverseLoading = false;
      });
      await _showPlaceOnMap(place);
    } catch (error) {
      if (!mounted || requestId != _reverseRequestId) return;
      setState(() {
        _searchError = 'Address lookup failed: $error';
        _reverseLoading = false;
      });
    }
  }

  Future<void> _showPlaceOnMap(GeocodingResult place) async {
    final controller = _mapController;
    if (controller == null || !_styleLoaded) return;
    final requestId = ++_mapSelectionRequestId;

    try {
      await _removeSearchCircle();
      if (!mounted ||
          requestId != _mapSelectionRequestId ||
          controller != _mapController) {
        return;
      }
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(place.latitude, place.longitude), 16),
      );
      if (!mounted ||
          requestId != _mapSelectionRequestId ||
          controller != _mapController) {
        return;
      }
      _searchCircle = await controller.addCircle(
        CircleOptions(
          geometry: LatLng(place.latitude, place.longitude),
          circleColor: '#D32F2F',
          circleRadius: 10,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
          circleOpacity: 1,
        ),
      );
    } catch (error) {
      if (mounted && requestId == _mapSelectionRequestId) {
        setState(() => _searchError = 'Could not show place on map: $error');
      }
    }
  }

  Future<void> _removeSearchCircle() async {
    final circle = _searchCircle;
    final controller = _mapController;
    if (circle == null || controller == null) return;
    _searchCircle = null;
    await controller.removeCircle(circle);
  }

  Future<void> _removeSearchCircleSafely() async {
    try {
      await _removeSearchCircle();
    } catch (error) {
      if (mounted) {
        setState(() => _searchError = 'Could not clear map selection: $error');
      }
    }
  }

  Future<void> _setRouteEndpoint({required bool origin}) async {
    final place = _selectedPlace;
    if (place == null) return;

    ++_routingRequestId;
    try {
      await _clearRouteAnnotations();
      if (!mounted) return;
      setState(() {
        if (origin) {
          _routeOrigin = place;
        } else {
          _routeDestination = place;
        }
        _routeResult = null;
        _routingError = null;
        _routing = false;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _routingError = 'Could not update route locations: $error',
        );
      }
    }
  }

  Future<void> _calculateRoute() async {
    final origin = _routeOrigin;
    final destination = _routeDestination;
    if (origin == null || destination == null) return;
    if (origin.latitude == destination.latitude &&
        origin.longitude == destination.longitude) {
      setState(
        () => _routingError = 'Choose two different places for the route.',
      );
      return;
    }

    final requestId = ++_routingRequestId;
    setState(() {
      _routing = true;
      _routingError = null;
      _routeResult = null;
    });

    try {
      await _clearRouteAnnotations();
      final result = await RoutingService.getDrivingRoute(
        originLatitude: origin.latitude,
        originLongitude: origin.longitude,
        destinationLatitude: destination.latitude,
        destinationLongitude: destination.longitude,
      );
      if (!mounted || requestId != _routingRequestId) return;
      setState(() {
        _routeResult = result;
      });
      await _drawRoute(result, origin, destination);
      if (!mounted || requestId != _routingRequestId) return;
      setState(() => _routing = false);
    } catch (error) {
      if (!mounted || requestId != _routingRequestId) return;
      setState(() {
        _routingError = 'Route could not be calculated: $error';
        _routing = false;
      });
    }
  }

  Future<void> _clearRouteAnnotations() async {
    final controller = _mapController;
    final line = _routeLine;
    final markers = List<Circle>.of(_routeMarkers);
    _routeLine = null;
    _routeMarkers.clear();
    if (controller == null) return;
    if (line != null) await controller.removeLine(line);
    if (markers.isNotEmpty) await controller.removeCircles(markers);
  }

  Future<void> _drawRoute(
    RouteResult route,
    GeocodingResult origin,
    GeocodingResult destination,
  ) async {
    final controller = _mapController;
    if (controller == null || !_styleLoaded) return;

    try {
      final points = route.coordinates
          .map((point) => LatLng(point[1], point[0]))
          .toList();
      _routeLine = await controller.addLine(
        LineOptions(
          geometry: points,
          lineColor: '#1565C0',
          lineWidth: 6,
          lineOpacity: 0.9,
          lineJoin: 'round',
        ),
      );
      _routeMarkers.addAll(
        await controller.addCircles([
          CircleOptions(
            geometry: LatLng(origin.latitude, origin.longitude),
            circleColor: '#2E7D32',
            circleRadius: 9,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2,
          ),
          CircleOptions(
            geometry: LatLng(destination.latitude, destination.longitude),
            circleColor: '#C62828',
            circleRadius: 9,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2,
          ),
        ]),
      );
      final center = LatLng(
        (origin.latitude + destination.latitude) / 2,
        (origin.longitude + destination.longitude) / 2,
      );
      final zoom = route.distanceMeters > 20000
          ? 11.5
          : route.distanceMeters > 10000
          ? 12.5
          : 13.5;
      await controller.animateCamera(CameraUpdate.newLatLngZoom(center, zoom));
    } catch (error) {
      if (mounted) {
        setState(
          () => _routingError = 'Route found but could not be drawn: $error',
        );
      }
    }
  }

  Widget _buildRoutePanel() {
    final selectedPlace = _selectedPlace;
    final origin = _routeOrigin;
    final destination = _routeDestination;
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: SafeArea(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedPlace != null) ...[
                  Text(
                    selectedPlace.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _routing
                            ? null
                            : () => _setRouteEndpoint(origin: true),
                        icon: const Icon(Icons.trip_origin),
                        label: const Text('Set start'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _routing
                            ? null
                            : () => _setRouteEndpoint(origin: false),
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('Set destination'),
                      ),
                    ],
                  ),
                ],
                if (origin != null || destination != null) ...[
                  if (selectedPlace != null) const Divider(),
                  Text('Start: ${origin?.displayName ?? 'Choose a place'}'),
                  const SizedBox(height: 4),
                  Text(
                    'Destination: ${destination?.displayName ?? 'Choose a place'}',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              origin != null && destination != null && !_routing
                              ? _calculateRoute
                              : null,
                          icon: _routing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.directions_car),
                          label: Text(
                            _routing ? 'Routing…' : 'Get driving route',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Clear route',
                        onPressed: _routing
                            ? null
                            : () async {
                                ++_routingRequestId;
                                try {
                                  await _clearRouteAnnotations();
                                  if (!mounted) return;
                                  setState(() {
                                    _routeOrigin = null;
                                    _routeDestination = null;
                                    _routeResult = null;
                                    _routingError = null;
                                  });
                                } catch (error) {
                                  if (mounted) {
                                    setState(() {
                                      _routingError =
                                          'Could not clear route: $error';
                                    });
                                  }
                                }
                              },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
                if (_routeResult != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${_routeResult!.formattedDistance} · ${_routeResult!.formattedDuration} estimated by car',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
                if (_routingError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _routingError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '© OpenStreetMap contributors · Routing by OSRM',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadHubs() async {
    final controller = _mapController;
    if (controller == null || _hubsLoading) return;
    _hubsLoading = true;

    try {
      final corridors = await RouteService.listCorridors();
      final hubsById = <String, HubModel>{};
      for (final corridor in corridors) {
        for (final hub in corridor.hubs) {
          if (hub.id.isNotEmpty &&
              hub.latitude >= -90 &&
              hub.latitude <= 90 &&
              hub.longitude >= -180 &&
              hub.longitude <= 180) {
            hubsById[hub.id] = hub;
          }
        }
      }

      final circles = hubsById.values
          .map(
            (hub) => CircleOptions(
              geometry: LatLng(hub.latitude, hub.longitude),
              circleColor: '#1565C0',
              circleRadius: 7,
              circleStrokeColor: '#FFFFFF',
              circleStrokeWidth: 2,
              circleOpacity: 1,
            ),
          )
          .toList();
      final lines = corridors
          .where((corridor) => corridor.geometryCoordinates.length >= 2)
          .map(
            (corridor) => LineOptions(
              geometry: corridor.geometryCoordinates
                  .map((point) => LatLng(point[1], point[0]))
                  .toList(),
              lineColor: corridor.id == 'katraj-vit' ? '#2E7D32' : '#C62828',
              lineWidth: 4,
              lineOpacity: 0.85,
              lineJoin: 'round',
            ),
          )
          .toList();
      if (lines.isNotEmpty) {
        await controller.addLines(lines);
      }
      if (circles.isNotEmpty) {
        await controller.addCircles(circles);
      }
      if (mounted) {
        _updateAfterFrame(() {
          _hubsError = null;
          _hubCount = circles.length;
          _corridorCount = lines.length;
        });
      }
    } catch (error) {
      if (mounted) {
        _updateAfterFrame(
          () => _hubsError = 'Hubs could not be loaded: $error',
        );
      }
    } finally {
      _hubsLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final supportsMap =
        !isFlutterTest &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Map')),
      body: Stack(
        children: [
          if (supportsMap)
            MapLibreMap(
              key: ValueKey(_mapInstance),
              styleString: MapConfig.styleUrl,
              initialCameraPosition: MapConfig.initialCameraPosition,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_styleLoaded) {
                  _loadHubs();
                  final place = _selectedPlace;
                  if (place != null) _showPlaceOnMap(place);
                  final route = _routeResult;
                  final origin = _routeOrigin;
                  final destination = _routeDestination;
                  if (route != null && origin != null && destination != null) {
                    _drawRoute(route, origin, destination);
                  }
                }
              },
              onMapClick: _onMapTap,
              onStyleLoadedCallback: () {
                _updateAfterFrame(() => _styleLoaded = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _loadHubs();
                  final place = _selectedPlace;
                  if (place != null) _showPlaceOnMap(place);
                  final route = _routeResult;
                  final origin = _routeOrigin;
                  final destination = _routeDestination;
                  if (route != null && origin != null && destination != null) {
                    _drawRoute(route, origin, destination);
                  }
                });
              },
            )
          else
            const Center(
              child: Text('Map preview is available on mobile and web.'),
            ),
          if (supportsMap)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onSubmitted: (_) => _searchPlaces(),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search places or addresses',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_searchController.text.isNotEmpty)
                                      IconButton(
                                        tooltip: 'Clear search',
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          ++_searchRequestId;
                                          ++_reverseRequestId;
                                          ++_mapSelectionRequestId;
                                          _searchController.clear();
                                          setState(() {
                                            _searchResults = const [];
                                            _searchError = null;
                                            _selectedPlace = null;
                                            _reverseLoading = false;
                                          });
                                          _removeSearchCircleSafely();
                                        },
                                      ),
                                    IconButton(
                                      tooltip: 'Search places',
                                      icon: const Icon(Icons.search),
                                      onPressed: _searchPlaces,
                                    ),
                                  ],
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    if (_searchError != null ||
                        _searchResults.isNotEmpty ||
                        _reverseLoading)
                      Card(
                        margin: const EdgeInsets.only(top: 8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: _reverseLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Finding address…'),
                                    ],
                                  ),
                                )
                              : _searchError != null
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(_searchError!),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _searchResults.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final place = _searchResults[index];
                                    return ListTile(
                                      leading: const Icon(Icons.place_outlined),
                                      title: Text(
                                        place.displayName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: place.type.isEmpty
                                          ? null
                                          : Text(place.type),
                                      onTap: () => _selectPlace(place),
                                    );
                                  },
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (_styleLoaded &&
              (_selectedPlace != null ||
                  _routeOrigin != null ||
                  _routeDestination != null))
            _buildRoutePanel()
          else if (_hubsError != null && _styleLoaded)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_hubsError!),
                ),
              ),
            )
          else if (_styleLoaded && _hubCount > 0)
            Positioned(
              left: 16,
              bottom: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    '$_hubCount hubs and $_corridorCount corridors loaded',
                  ),
                ),
              ),
            ),
          if (_styleLoaded &&
              _selectedPlace == null &&
              _routeOrigin == null &&
              _routeDestination == null)
            const Positioned(
              right: 8,
              bottom: 12,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    '© OpenStreetMap contributors · OSRM',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
          if (!_styleLoaded)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _styleTimedOut
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_off, size: 42),
                                SizedBox(height: 12),
                                Text(
                                  'Map could not be loaded.',
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Check your internet connection and try again.',
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _retryMap,
                                  child: Text('Retry'),
                                ),
                              ],
                            )
                          : const CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
