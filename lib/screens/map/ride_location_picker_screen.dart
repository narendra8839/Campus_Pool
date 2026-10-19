import 'dart:math' show Point;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../models/geocoding_result.dart';
import '../../services/geocoding_service.dart';
import 'map_config.dart';
import '../../utils/runtime_environment.dart';

class RideLocationPickerScreen extends StatefulWidget {
  const RideLocationPickerScreen({super.key, this.initialPlace});

  final GeocodingResult? initialPlace;

  @override
  State<RideLocationPickerScreen> createState() =>
      _RideLocationPickerScreenState();
}

class _RideLocationPickerScreenState extends State<RideLocationPickerScreen> {
  final _searchController = TextEditingController();
  MapLibreMapController? _mapController;
  GeocodingResult? _selectedPlace;
  List<GeocodingResult> _searchResults = const [];
  Circle? _selectedCircle;
  String? _error;
  bool _searching = false;
  bool _reversing = false;
  bool _styleLoaded = false;
  int _searchRequestId = 0;
  int _selectionRequestId = 0;

  @override
  void initState() {
    super.initState();
    _selectedPlace = widget.initialPlace;
    _searchController.text = widget.initialPlace?.displayName ?? '';
  }

  @override
  void dispose() {
    ++_searchRequestId;
    ++_selectionRequestId;
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces() async {
    final query = _searchController.text.trim();
    if (query.length < 3) {
      setState(() {
        _error = 'Enter at least 3 characters to search.';
        _searchResults = const [];
      });
      return;
    }

    final requestId = ++_searchRequestId;
    ++_selectionRequestId;
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _searching = true;
      _searchResults = const [];
    });
    try {
      final results = await GeocodingService.search(query);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchResults = results;
        _searching = false;
        if (results.isEmpty) _error = 'No places found.';
      });
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searching = false;
        _error = 'Place search failed: $error';
      });
    }
  }

  void _onSearchChanged() {
    ++_searchRequestId;
    ++_selectionRequestId;
    setState(() {
      _selectedPlace = null;
      _searchResults = const [];
      _searching = false;
      _error = null;
    });
    _clearSelectedMarker();
  }

  Future<void> _selectPlace(GeocodingResult place) async {
    ++_searchRequestId;
    ++_selectionRequestId;
    setState(() {
      _selectedPlace = place;
      _searchController.text = place.displayName;
      _searchResults = const [];
      _error = null;
      _searching = false;
    });
    await _showSelectedPlace(place);
  }

  Future<void> _onMapTap(Point<double> _, LatLng coordinates) async {
    final requestId = ++_selectionRequestId;
    ++_searchRequestId;
    await _clearSelectedMarker();
    if (!mounted || requestId != _selectionRequestId) return;
    setState(() {
      _selectedPlace = null;
      _searchResults = const [];
      _searching = false;
      _reversing = true;
      _error = null;
    });
    try {
      final placeName = await GeocodingService.reverse(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );
      if (!mounted || requestId != _selectionRequestId) return;
      final place = GeocodingResult(
        placeId: placeName.placeId,
        displayName: placeName.displayName,
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        type: placeName.type,
      );
      setState(() {
        _selectedPlace = place;
        _searchController.text = place.displayName;
        _reversing = false;
      });
      await _showSelectedPlace(place);
    } catch (error) {
      if (!mounted || requestId != _selectionRequestId) return;
      setState(() {
        _reversing = false;
        _error = 'Could not identify this map location: $error';
      });
    }
  }

  Future<void> _clearSelectedMarker() async {
    final controller = _mapController;
    final circle = _selectedCircle;
    _selectedCircle = null;
    if (controller == null || circle == null) return;
    try {
      await controller.removeCircle(circle);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not clear the map pin: $error');
      }
    }
  }

  Future<void> _showSelectedPlace(GeocodingResult place) async {
    final controller = _mapController;
    if (controller == null || !_styleLoaded) return;
    final requestId = ++_selectionRequestId;
    try {
      final circle = _selectedCircle;
      _selectedCircle = null;
      if (circle != null) await controller.removeCircle(circle);
      if (!mounted ||
          requestId != _selectionRequestId ||
          controller != _mapController) {
        return;
      }
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(place.latitude, place.longitude), 16),
      );
      _selectedCircle = await controller.addCircle(
        CircleOptions(
          geometry: LatLng(place.latitude, place.longitude),
          circleColor: '#1565C0',
          circleRadius: 10,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
      );
    } catch (error) {
      if (mounted && requestId == _selectionRequestId) {
        setState(() => _error = 'Could not show the selected location: $error');
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
    final initialPlace = widget.initialPlace;
    final initialCamera = initialPlace == null
        ? MapConfig.initialCameraPosition
        : CameraPosition(
            target: LatLng(initialPlace.latitude, initialPlace.longitude),
            zoom: 16,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Choose ride location')),
      body: Stack(
        children: [
          if (supportsMap)
            MapLibreMap(
              styleString: MapConfig.styleUrl,
              initialCameraPosition: initialCamera,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
              },
              onMapCreated: (controller) {
                _mapController = controller;
                if (_styleLoaded && _selectedPlace != null) {
                  _showSelectedPlace(_selectedPlace!);
                }
              },
              onStyleLoadedCallback: () {
                _styleLoaded = true;
                final selectedPlace = _selectedPlace;
                if (selectedPlace != null) _showSelectedPlace(selectedPlace);
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
              child: PointerInterceptor(
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onChanged: (_) => _onSearchChanged(),
                          onSubmitted: (_) => _searchPlaces(),
                          decoration: InputDecoration(
                            hintText: 'Search place or address',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searching
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
                                : IconButton(
                                    tooltip: 'Search places',
                                    onPressed: _searchPlaces,
                                    icon: const Icon(Icons.search),
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      if (_searchResults.isNotEmpty)
                        Card(
                          margin: const EdgeInsets.only(top: 8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 240),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final place = _searchResults[index];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.place_outlined),
                                  title: Text(
                                    place.displayName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
            ),
          if (supportsMap)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                child: PointerInterceptor(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _reversing
                                ? 'Finding address…'
                                : _selectedPlace?.displayName ??
                                      'Search for a place or tap the map to set a pin.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _selectedPlace == null || _reversing
                                ? null
                                : () => Navigator.pop(context, _selectedPlace),
                            child: const Text('Confirm location'),
                          ),
                        ],
                      ),
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
