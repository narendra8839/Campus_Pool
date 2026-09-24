import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../models/corridor_model.dart';
import '../../services/route_service.dart';
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
      _mapInstance++;
    });
    _startLoadTimeout();
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
    final supportsMap = !isFlutterTest &&
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
              if (_styleLoaded) _loadHubs();
            },
            onStyleLoadedCallback: () {
              _updateAfterFrame(() => _styleLoaded = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _loadHubs();
              });
            },
            )
          else
            const Center(
              child: Text('Map preview is available on mobile and web.'),
            ),
          if (_hubsError != null && _styleLoaded)
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
            ),
          if (_hubsError == null && _styleLoaded && _hubCount > 0)
            Positioned(
              left: 16,
              bottom: 16,
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
