import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../models/geocoding_result.dart';
import '../../models/route_result.dart';
import '../../utils/runtime_environment.dart';
import 'map_config.dart';

class RideRoutePreviewMap extends StatefulWidget {
  const RideRoutePreviewMap({
    super.key,
    required this.routes,
    required this.selectedRouteIndex,
    required this.onRouteSelected,
    required this.origin,
    required this.destination,
    this.viaPoint,
    this.pickupPoint,
    this.dropPoint,
    this.selectable = true,
  });

  final List<RouteResult> routes;
  final int selectedRouteIndex;
  final ValueChanged<int> onRouteSelected;
  final GeocodingResult origin;
  final GeocodingResult destination;
  final GeocodingResult? viaPoint;
  final GeocodingResult? pickupPoint;
  final GeocodingResult? dropPoint;
  final bool selectable;

  @override
  State<RideRoutePreviewMap> createState() => _RideRoutePreviewMapState();
}

class _RideRoutePreviewMapState extends State<RideRoutePreviewMap> {
  static const _selectedColor = '#1565C0';
  static const _alternativeColor = '#7B8794';

  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  String? _error;
  final List<Line> _routeLines = [];
  final List<Circle> _endpointMarkers = [];
  final Map<String, int> _routeIndexByLineId = {};
  Future<void> _renderQueue = Future<void>.value();

  @override
  void didUpdateWidget(covariant RideRoutePreviewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routes != widget.routes ||
        oldWidget.selectedRouteIndex != widget.selectedRouteIndex ||
        oldWidget.viaPoint != widget.viaPoint ||
        oldWidget.pickupPoint != widget.pickupPoint ||
        oldWidget.dropPoint != widget.dropPoint) {
      _scheduleRender();
    }
  }

  void _onLineTapped(Line line) {
    final routeIndex = _routeIndexByLineId[line.id];
    if (widget.selectable &&
        routeIndex != null &&
        routeIndex != widget.selectedRouteIndex) {
      widget.onRouteSelected(routeIndex);
    }
  }

  void _scheduleRender() {
    _renderQueue = _renderQueue.then((_) => _drawRoutes());
  }

  Future<void> _drawRoutes() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded || !mounted) return;

    try {
      if (_routeLines.isNotEmpty) {
        await controller.removeLines(List<Line>.of(_routeLines));
        _routeLines.clear();
        _routeIndexByLineId.clear();
      }
      if (_endpointMarkers.isNotEmpty) {
        await controller.removeCircles(List<Circle>.of(_endpointMarkers));
        _endpointMarkers.clear();
      }
      if (!mounted || controller != _controller) return;

      final routeOrder =
          List<int>.generate(widget.routes.length, (index) => index)
            ..remove(widget.selectedRouteIndex)
            ..add(widget.selectedRouteIndex);
      for (final index in routeOrder) {
        final route = widget.routes[index];
        final line = await controller.addLine(
          LineOptions(
            geometry: route.coordinates
                .map((point) => LatLng(point[1], point[0]))
                .toList(),
            lineColor: index == widget.selectedRouteIndex
                ? _selectedColor
                : _alternativeColor,
            lineWidth: index == widget.selectedRouteIndex ? 8 : 5,
            lineOpacity: index == widget.selectedRouteIndex ? 1 : 0.72,
            lineJoin: 'round',
          ),
        );
        _routeLines.add(line);
        _routeIndexByLineId[line.id] = index;
      }

      final markerOptions = <CircleOptions>[
        CircleOptions(
          geometry: LatLng(widget.origin.latitude, widget.origin.longitude),
          circleColor: '#2E7D32',
          circleRadius: 9,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ),
        CircleOptions(
          geometry: LatLng(
            widget.destination.latitude,
            widget.destination.longitude,
          ),
          circleColor: '#C62828',
          circleRadius: 9,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ),
      ];
      final viaPoint = widget.viaPoint;
      if (viaPoint != null) {
        markerOptions.add(
          CircleOptions(
            geometry: LatLng(viaPoint.latitude, viaPoint.longitude),
            circleColor: '#EF6C00',
            circleRadius: 8,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2,
          ),
        );
      }
      if (widget.pickupPoint != null) {
        markerOptions.add(
          CircleOptions(
            geometry: LatLng(
              widget.pickupPoint!.latitude,
              widget.pickupPoint!.longitude,
            ),
            circleColor: '#EF6C00',
            circleRadius: 10,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 3,
          ),
        );
      }
      if (widget.dropPoint != null) {
        markerOptions.add(
          CircleOptions(
            geometry: LatLng(
              widget.dropPoint!.latitude,
              widget.dropPoint!.longitude,
            ),
            circleColor: '#8E24AA',
            circleRadius: 10,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 3,
          ),
        );
      }
      _endpointMarkers.addAll(await controller.addCircles(markerOptions));

      final points = widget.routes
          .expand((route) => route.coordinates)
          .toList();
      final latitudes = points.map((point) => point[1]);
      final longitudes = points.map((point) => point[0]);
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              latitudes.reduce((a, b) => a < b ? a : b),
              longitudes.reduce((a, b) => a < b ? a : b),
            ),
            northeast: LatLng(
              latitudes.reduce((a, b) => a > b ? a : b),
              longitudes.reduce((a, b) => a > b ? a : b),
            ),
          ),
          left: 24,
          top: 24,
          right: 24,
          bottom: 24,
        ),
      );
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not display routes: $error');
    }
  }

  @override
  void dispose() {
    _controller?.onLineTapped.remove(_onLineTapped);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supportsMap =
        !isFlutterTest &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!supportsMap) {
      return const Center(
        child: Text('Route map preview is available on mobile and web.'),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          MapLibreMap(
            styleString: MapConfig.styleUrl,
            initialCameraPosition: CameraPosition(
              target: LatLng(
                (widget.origin.latitude + widget.destination.latitude) / 2,
                (widget.origin.longitude + widget.destination.longitude) / 2,
              ),
              zoom: 12,
            ),
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
            },
            onMapCreated: (controller) {
              _controller?.onLineTapped.remove(_onLineTapped);
              _controller = controller;
              controller.onLineTapped.add(_onLineTapped);
              if (_styleLoaded) _scheduleRender();
            },
            onStyleLoadedCallback: () {
              _styleLoaded = true;
              _scheduleRender();
            },
          ),
          Positioned(
            left: 8,
            right: 8,
            top: 8,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    widget.selectable
                        ? 'Tap a route line to select it'
                        : 'Biker’s planned route',
                  ),
                ),
              ),
            ),
          ),
          if (_error != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_error!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
