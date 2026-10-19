import 'dart:math' as math;
import 'dart:math' show Point;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../models/geocoding_result.dart';
import '../../services/geocoding_service.dart';
import '../../utils/runtime_environment.dart';
import 'map_config.dart';

class RideRoutePointPickerScreen extends StatefulWidget {
  const RideRoutePointPickerScreen({
    super.key,
    required this.routeCoordinates,
    required this.pointLabel,
    this.initialPlace,
  });

  final List<List<double>> routeCoordinates;
  final String pointLabel;
  final GeocodingResult? initialPlace;

  @override
  State<RideRoutePointPickerScreen> createState() =>
      _RideRoutePointPickerScreenState();
}

class _RideRoutePointPickerScreenState
    extends State<RideRoutePointPickerScreen> {
  static const _maximumSnapDistanceMeters = 50.0;

  MapLibreMapController? _controller;
  final List<Circle> _routeMarkers = [];
  Circle? _selectedMarker;
  bool _styleLoaded = false;
  bool _resolvingPlace = false;
  int _selectionRequestId = 0;
  GeocodingResult? _selectedPlace;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedPlace = widget.initialPlace;
  }

  @override
  void dispose() {
    ++_selectionRequestId;
    super.dispose();
  }

  Future<void> _renderRoute() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded || !mounted) return;
    try {
      await controller.addLine(
        LineOptions(
          geometry: widget.routeCoordinates
              .map((point) => LatLng(point[1], point[0]))
              .toList(),
          lineColor: '#1565C0',
          lineWidth: 7,
          lineOpacity: 0.9,
          lineJoin: 'round',
        ),
      );
      final start = widget.routeCoordinates.first;
      final end = widget.routeCoordinates.last;
      _routeMarkers.addAll(
        await controller.addCircles([
          CircleOptions(
            geometry: LatLng(start[1], start[0]),
            circleColor: '#2E7D32',
            circleRadius: 8,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2,
          ),
          CircleOptions(
            geometry: LatLng(end[1], end[0]),
            circleColor: '#C62828',
            circleRadius: 8,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2,
          ),
        ]),
      );
      final latitudes = widget.routeCoordinates.map((point) => point[1]);
      final longitudes = widget.routeCoordinates.map((point) => point[0]);
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
          left: 36,
          top: 88,
          right: 36,
          bottom: 104,
        ),
      );
      final place = _selectedPlace;
      if (place != null) await _showMarker(place, moveCamera: false);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not display the route: $error');
      }
    }
  }

  Future<void> _onMapTap(Point<double> _, LatLng tappedPoint) async {
    final snappedPoint = _snapToRoute(tappedPoint);
    if (snappedPoint == null) {
      setState(
        () =>
            _error = 'Tap within 50 m of the biker’s route to choose a point.',
      );
      return;
    }

    final requestId = ++_selectionRequestId;
    setState(() {
      _resolvingPlace = true;
      _error = null;
    });
    try {
      final place = await GeocodingService.reverse(
        latitude: snappedPoint.latitude,
        longitude: snappedPoint.longitude,
      );
      if (!mounted || requestId != _selectionRequestId) return;
      final selected = GeocodingResult(
        placeId: place.placeId,
        displayName: place.displayName,
        latitude: snappedPoint.latitude,
        longitude: snappedPoint.longitude,
        type: place.type,
      );
      setState(() {
        _selectedPlace = selected;
        _resolvingPlace = false;
      });
      await _showMarker(selected);
    } catch (error) {
      if (!mounted || requestId != _selectionRequestId) return;
      setState(() {
        _resolvingPlace = false;
        _error = 'Could not identify this route point: $error';
      });
    }
  }

  LatLng? _snapToRoute(LatLng tappedPoint) {
    if (widget.routeCoordinates.length < 2) return null;
    final latitudeScale = 111320.0;
    final longitudeScale =
        111320.0 * math.cos(tappedPoint.latitude * math.pi / 180);
    var closestDistance = double.infinity;
    LatLng? closestPoint;

    for (var index = 0; index < widget.routeCoordinates.length - 1; index++) {
      final start = widget.routeCoordinates[index];
      final end = widget.routeCoordinates[index + 1];
      final startX = (start[0] - tappedPoint.longitude) * longitudeScale;
      final startY = (start[1] - tappedPoint.latitude) * latitudeScale;
      final endX = (end[0] - tappedPoint.longitude) * longitudeScale;
      final endY = (end[1] - tappedPoint.latitude) * latitudeScale;
      final segmentX = endX - startX;
      final segmentY = endY - startY;
      final lengthSquared = segmentX * segmentX + segmentY * segmentY;
      final fraction = lengthSquared == 0
          ? 0.0
          : (-startX * segmentX - startY * segmentY) / lengthSquared;
      final clampedFraction = fraction.clamp(0.0, 1.0);
      final projectedX = startX + clampedFraction * segmentX;
      final projectedY = startY + clampedFraction * segmentY;
      final distance = math.sqrt(
        projectedX * projectedX + projectedY * projectedY,
      );
      if (distance < closestDistance) {
        closestDistance = distance;
        closestPoint = LatLng(
          start[1] + clampedFraction * (end[1] - start[1]),
          start[0] + clampedFraction * (end[0] - start[0]),
        );
      }
    }
    return closestDistance <= _maximumSnapDistanceMeters ? closestPoint : null;
  }

  Future<void> _showMarker(
    GeocodingResult place, {
    bool moveCamera = true,
  }) async {
    final controller = _controller;
    if (controller == null || !_styleLoaded || !mounted) return;
    try {
      final marker = _selectedMarker;
      _selectedMarker = null;
      if (marker != null) await controller.removeCircle(marker);
      _selectedMarker = await controller.addCircle(
        CircleOptions(
          geometry: LatLng(place.latitude, place.longitude),
          circleColor: '#EF6C00',
          circleRadius: 10,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
      );
      if (moveCamera) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(place.latitude, place.longitude),
            16,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not show the selected point: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final supportsMap =
        !isFlutterTest &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final firstPoint = widget.routeCoordinates.first;
    final lastPoint = widget.routeCoordinates.last;

    return Scaffold(
      appBar: AppBar(title: Text('Choose ${widget.pointLabel} point')),
      body: Stack(
        children: [
          if (supportsMap)
            MapLibreMap(
              styleString: MapConfig.styleUrl,
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  (firstPoint[1] + lastPoint[1]) / 2,
                  (firstPoint[0] + lastPoint[0]) / 2,
                ),
                zoom: 12,
              ),
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
              },
              onMapCreated: (controller) => _controller = controller,
              onStyleLoadedCallback: () {
                _styleLoaded = true;
                _renderRoute();
              },
              onMapClick: _onMapTap,
            )
          else
            const Center(
              child: Text(
                'Map location selection is available on mobile and web.',
              ),
            ),
          if (supportsMap)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Tap within 50 m of the blue route to place your ${widget.pointLabel}. The point will snap onto the route.',
                  ),
                ),
              ),
            ),
          if (_error != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 90,
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: FilledButton.icon(
                onPressed: _selectedPlace == null || _resolvingPlace
                    ? null
                    : () => Navigator.pop(context, _selectedPlace),
                icon: _resolvingPlace
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _resolvingPlace
                      ? 'Finding place name…'
                      : _selectedPlace == null
                      ? 'Tap the route to choose'
                      : 'Use ${widget.pointLabel}',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
