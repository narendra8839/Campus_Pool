// ignore_for_file: unused_element

import 'dart:async';
import 'dart:math' show Point;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../components/components.dart';
import '../../models/corridor_model.dart';
import '../../models/ride_model.dart';
import '../../services/geocoding_service.dart';
import '../../services/routing_service.dart';
import '../../services/route_service.dart';
import '../../services/route_preview_store.dart';
import '../../models/geocoding_result.dart';
import '../../models/route_result.dart';
import '../../services/auth_service.dart';
import '../../services/ride_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../auth/login_screen.dart';
import '../find_rides_screen.dart';
import '../alerts/alerts_screen.dart';
import '../offer_ride_screen.dart';
import '../navigation/main_navigation_shell.dart';
import '../profile/profile_screen.dart';
import '../ride_details_screen.dart';
import '../rides/driver_request_queue_screen.dart';
import '../rides/my_rides_screen.dart';
import '../map/map_screen.dart';
import '../map/map_config.dart';
import '../../utils/runtime_environment.dart';
import '../../utils/ride_fare.dart';
import '../auto_groups/auto_groups_screen.dart';

/// Campus Pool Home Dashboard Screen
/// Based on Stitch design: projects/4131098890607133930/screens/f3c45ada102f44db80a425cc7c5598b1
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({
    super.key,
    this.userName,
    this.embeddedInShell = false,
  });

  final String? userName;
  final bool embeddedInShell;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int _currentNavIndex = 0;
  List<RideModel> _nearbyRides = const [];
  bool _isLoadingDashboard = true;
  String? _dashboardError;
  String _displayName = 'there';
  MapLibreMapController? _mapController;
  Line? _homeRouteLine;
  final List<Circle> _homeRouteMarkers = [];
  final List<Circle> _homeHubCircles = [];
  final List<Line> _homeCorridorLines = [];
  Circle? _destinationMarkerCircle;
  int _homeRouteRequestId = 0;
  bool _homeMapStyleLoaded = false;
  bool _homeMapLoadTimedOut = false;
  int _homeMapInstance = 0;
  String? _homeRouteError;
  bool _homeHubsLoading = false;

  // ── Search & Place Selection State ─────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;
  List<GeocodingResult> _searchSuggestions = [];
  GeocodingResult? _selectedDestination;
  RouteResult? _activeRoute;

  // Pre-configured popular campus hubs and landmarks for 0ms instant matching
  static final List<GeocodingResult> _popularCampusPlaces = [
    const GeocodingResult(
      placeId: 'vit-campus',
      displayName: 'VIT College Campus, Bibwewadi',
      latitude: 18.46439,
      longitude: 73.86749,
      type: 'campus',
    ),
    const GeocodingResult(
      placeId: 'katraj-hub',
      displayName: 'Katraj Hub & Bus Stand, Pune',
      latitude: 18.4529,
      longitude: 73.8553,
      type: 'hub',
    ),
    const GeocodingResult(
      placeId: 'swargate-hub',
      displayName: 'Swargate Bus Station & Metro, Pune',
      latitude: 18.5018,
      longitude: 73.8586,
      type: 'hub',
    ),
    const GeocodingResult(
      placeId: 'bibwewadi-corner',
      displayName: 'Bibwewadi Corner, Pune',
      latitude: 18.4721,
      longitude: 73.8634,
      type: 'landmark',
    ),
    const GeocodingResult(
      placeId: 'upper-indira-nagar',
      displayName: 'Upper Indira Nagar Hub, Bibwewadi',
      latitude: 18.4624,
      longitude: 73.8601,
      type: 'hub',
    ),
    const GeocodingResult(
      placeId: 'market-yard',
      displayName: 'Market Yard, Gultekdi, Pune',
      latitude: 18.4876,
      longitude: 73.8711,
      type: 'landmark',
    ),
    const GeocodingResult(
      placeId: 'pune-station',
      displayName: 'Pune Railway Station, Pune',
      latitude: 18.5284,
      longitude: 73.8744,
      type: 'transit',
    ),
    const GeocodingResult(
      placeId: 'shivajinagar',
      displayName: 'Shivajinagar Station & Bus Stand, Pune',
      latitude: 18.5314,
      longitude: 73.8446,
      type: 'transit',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _displayName = widget.userName?.trim().isNotEmpty == true
        ? widget.userName!.trim()
        : (AuthService.cachedUser?.name.trim().isNotEmpty == true
              ? AuthService.cachedUser!.name.trim()
              : 'there');
    _loadDashboardData();
    RoutePreviewStore.instance.addListener(_onRoutePreviewChanged);
    if (!isFlutterTest) _startHomeMapLoadTimeout();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    RoutePreviewStore.instance.removeListener(_onRoutePreviewChanged);
    super.dispose();
  }

  void _onRoutePreviewChanged() {
    final route = RoutePreviewStore.instance.route;
    final origin = RoutePreviewStore.instance.origin;
    final destination = RoutePreviewStore.instance.destination;
    if (route == null || origin == null || destination == null) {
      _clearHomeRoute();
      return;
    }
    setState(() {
      _activeRoute = route;
      if (_selectedDestination == null && destination.displayName.isNotEmpty) {
        _searchController.text = destination.displayName.split(',').first.trim();
        _selectedDestination = destination;
      }
    });
    _displayHomeRoute(route, origin, destination);
  }

  void _onSearchQueryChanged(String query) {
    _searchDebounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchSuggestions = [];
      });
      return;
    }

    // Instantly filter known popular campus locations
    final localMatches = _popularCampusPlaces
        .where((place) =>
            place.displayName.toLowerCase().contains(trimmed.toLowerCase()))
        .toList();

    setState(() {
      _searchSuggestions = localMatches;
    });

    if (trimmed.length < 2) return;

    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final apiResults = await GeocodingService.search(trimmed);
        if (!mounted || _searchController.text.trim() != trimmed) return;

        final combined = List<GeocodingResult>.of(localMatches);
        for (final item in apiResults) {
          final isDuplicate = combined.any((p) =>
              (p.latitude - item.latitude).abs() < 0.001 &&
              (p.longitude - item.longitude).abs() < 0.001);
          if (!isDuplicate) combined.add(item);
        }

        setState(() {
          _searchSuggestions = combined;
        });
      } catch (_) {}
    });
  }

  Future<void> _onSelectDestination(GeocodingResult place) async {
    _searchFocusNode.unfocus();
    final shortName = place.displayName.split(',').first.trim();
    _searchController.text = shortName;
    setState(() {
      _selectedDestination = place;
      _searchSuggestions = [];
      _homeRouteError = null;
    });

    await _showDestinationOnMap(place);

    try {
      const campusLat = 18.46439;
      const campusLon = 73.86749;
      final route = await RoutingService.getDrivingRoute(
        originLatitude: campusLat,
        originLongitude: campusLon,
        destinationLatitude: place.latitude,
        destinationLongitude: place.longitude,
      );
      if (!mounted) return;

      const campusOrigin = GeocodingResult(
        placeId: 'vit-campus',
        displayName: 'VIT College Campus',
        latitude: campusLat,
        longitude: campusLon,
        type: 'campus',
      );

      RoutePreviewStore.instance.setPreview(
        route: route,
        origin: campusOrigin,
        destination: place,
      );

      setState(() {
        _activeRoute = route;
      });

      await _displayHomeRoute(route, campusOrigin, place);
      _filterRidesForDestination(shortName);
    } catch (e) {
      if (mounted) {
        setState(() {
          _homeRouteError = 'Could not calculate route to $shortName: $e';
        });
      }
    }
  }

  void _clearSearchAndRoute() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _selectedDestination = null;
      _searchSuggestions = [];
      _activeRoute = null;
      _homeRouteError = null;
    });
    RoutePreviewStore.instance.clear();
    _clearHomeRoute();
    if (_destinationMarkerCircle != null && _mapController != null) {
      try {
        _mapController!.removeCircle(_destinationMarkerCircle!);
      } catch (_) {}
      _destinationMarkerCircle = null;
    }
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(MapConfig.initialCameraPosition),
    );
    _loadDashboardData();
  }

  Future<void> _showDestinationOnMap(GeocodingResult place) async {
    final controller = _mapController;
    if (controller == null || !_homeMapStyleLoaded) return;

    try {
      if (_destinationMarkerCircle != null) {
        await controller.removeCircle(_destinationMarkerCircle!);
        _destinationMarkerCircle = null;
      }

      final circle = await controller.addCircle(
        CircleOptions(
          geometry: LatLng(place.latitude, place.longitude),
          circleColor: '#D32F2F',
          circleRadius: 10,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
          circleOpacity: 1.0,
        ),
      );
      _destinationMarkerCircle = circle;

      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(place.latitude, place.longitude),
          14.5,
        ),
      );
    } catch (e) {
      debugPrint('Error placing destination pin: $e');
    }
  }

  Future<void> _onHomeMapTap(Point<double> _, LatLng coordinates) async {
    // 1. Check if user tapped close to any of our known popular campus places (within ~400m)
    GeocodingResult? matchedPlace;
    for (final place in _popularCampusPlaces) {
      final latDiff = (place.latitude - coordinates.latitude).abs();
      final lonDiff = (place.longitude - coordinates.longitude).abs();
      if (latDiff < 0.005 && lonDiff < 0.005) {
        matchedPlace = place;
        break;
      }
    }

    if (matchedPlace != null) {
      await _onSelectDestination(matchedPlace);
      return;
    }

    // 2. Otherwise reverse geocode the tapped coordinate
    try {
      final reverseResult = await GeocodingService.reverse(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );
      if (!mounted) return;
      await _onSelectDestination(reverseResult);
    } catch (_) {
      final fallbackPlace = GeocodingResult(
        placeId: 'pinned-${coordinates.latitude.toStringAsFixed(4)}-${coordinates.longitude.toStringAsFixed(4)}',
        displayName: 'Pinned Location (${coordinates.latitude.toStringAsFixed(3)}, ${coordinates.longitude.toStringAsFixed(3)})',
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        type: 'pinned',
      );
      if (!mounted) return;
      await _onSelectDestination(fallbackPlace);
    }
  }

  Future<void> _loadHomeHubs() async {
    final controller = _mapController;
    if (controller == null || _homeHubsLoading) return;
    _homeHubsLoading = true;

    try {
      final corridors = await RouteService.listCorridors();
      if (!mounted || controller != _mapController) return;

      if (_homeCorridorLines.isNotEmpty) {
        for (final line in _homeCorridorLines) {
          try {
            await controller.removeLine(line);
          } catch (_) {}
        }
        _homeCorridorLines.clear();
      }
      if (_homeHubCircles.isNotEmpty) {
        await controller.removeCircles(List.of(_homeHubCircles));
        _homeHubCircles.clear();
      }

      final lineOptions = corridors
          .where((c) => c.geometryCoordinates.length >= 2)
          .map((c) => LineOptions(
                geometry: c.geometryCoordinates
                    .map((pt) => LatLng(pt[1], pt[0]))
                    .toList(),
                lineColor: c.id == 'katraj-vit' ? '#2E7D32' : '#1565C0',
                lineWidth: 4,
                lineOpacity: 0.75,
                lineJoin: 'round',
              ))
          .toList();
      if (lineOptions.isNotEmpty) {
        final addedLines = await controller.addLines(lineOptions);
        _homeCorridorLines.addAll(addedLines);
      }

      final hubsById = <String, HubModel>{};
      for (final c in corridors) {
        for (final h in c.hubs) {
          if (h.id.isNotEmpty && h.latitude != 0 && h.longitude != 0) {
            hubsById[h.id] = h;
          }
        }
      }

      final circleOptions = hubsById.values
          .map((h) => CircleOptions(
                geometry: LatLng(h.latitude, h.longitude),
                circleColor: '#1565C0',
                circleRadius: 6,
                circleStrokeColor: '#FFFFFF',
                circleStrokeWidth: 2,
                circleOpacity: 0.95,
              ))
          .toList();

      // Add prominent VIT Campus marker
      circleOptions.add(
        const CircleOptions(
          geometry: LatLng(18.46439, 73.86749),
          circleColor: '#E65100',
          circleRadius: 10,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
          circleOpacity: 1.0,
        ),
      );

      final addedCircles = await controller.addCircles(circleOptions);
      _homeHubCircles.addAll(addedCircles);
    } catch (e) {
      debugPrint('Could not load campus hubs on home map: $e');
    } finally {
      _homeHubsLoading = false;
    }
  }

  Future<void> _filterRidesForDestination(String destinationQuery) async {
    setState(() => _isLoadingDashboard = true);
    try {
      final rides = await RideService.searchRides({
        'to': destinationQuery,
        'limit': '10',
      });
      if (!mounted) return;
      setState(() {
        _nearbyRides = rides;
        _isLoadingDashboard = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingDashboard = false);
    }
  }

  Future<void> _clearHomeRoute() async {
    ++_homeRouteRequestId;
    final controller = _mapController;
    final routeLine = _homeRouteLine;
    final markers = List<Circle>.of(_homeRouteMarkers);
    _homeRouteLine = null;
    _homeRouteMarkers.clear();
    if (controller == null) return;
    try {
      if (routeLine != null) await controller.removeLine(routeLine);
      if (markers.isNotEmpty) await controller.removeCircles(markers);
      if (mounted) setState(() => _homeRouteError = null);
    } catch (error) {
      if (mounted) {
        setState(
          () => _homeRouteError = 'Could not clear route from map: $error',
        );
      }
    }
  }

  Future<void> _displayHomeRoute(
    RouteResult route,
    GeocodingResult origin,
    GeocodingResult destination,
  ) async {
    final controller = _mapController;
    if (controller == null || !_homeMapStyleLoaded) return;
    final requestId = ++_homeRouteRequestId;
    try {
      final oldLine = _homeRouteLine;
      final oldMarkers = List<Circle>.of(_homeRouteMarkers);
      _homeRouteLine = null;
      _homeRouteMarkers.clear();
      if (oldLine != null) await controller.removeLine(oldLine);
      if (oldMarkers.isNotEmpty) await controller.removeCircles(oldMarkers);
      if (!mounted || requestId != _homeRouteRequestId) return;

      final points = route.coordinates
          .map((point) => LatLng(point[1], point[0]))
          .toList();
      final routeLine = await controller.addLine(
        LineOptions(
          geometry: points,
          lineColor: '#1565C0',
          lineWidth: 6,
          lineOpacity: 0.9,
          lineJoin: 'round',
        ),
      );
      if (!mounted || requestId != _homeRouteRequestId) {
        await controller.removeLine(routeLine);
        return;
      }
      _homeRouteLine = routeLine;
      final routeMarkers = await controller.addCircles([
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
      ]);
      if (!mounted || requestId != _homeRouteRequestId) {
        await controller.removeCircles(routeMarkers);
        return;
      }
      _homeRouteMarkers.addAll(routeMarkers);
      if (!mounted || requestId != _homeRouteRequestId) return;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(
            (origin.latitude + destination.latitude) / 2,
            (origin.longitude + destination.longitude) / 2,
          ),
          route.distanceMeters > 20000
              ? 11.5
              : route.distanceMeters > 10000
              ? 12.5
              : 13.5,
        ),
      );
      if (mounted && requestId == _homeRouteRequestId) {
        setState(() => _homeRouteError = null);
      }
    } catch (error) {
      if (mounted && requestId == _homeRouteRequestId) {
        setState(
          () => _homeRouteError = 'Could not display route on map: $error',
        );
      }
    }
  }

  Future<void> _openHomeRoute(Widget screen) async {
    if (!mounted) return;
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _openFindRides() {
    final dest = _searchController.text.trim();
    _openHomeRoute(FindRidesScreen(
      initialDestination: dest.isNotEmpty ? dest : null,
    ));
  }

  void _startHomeMapLoadTimeout() {
    Future<void>.delayed(const Duration(seconds: 12), () {
      if (mounted && !_homeMapStyleLoaded) {
        setState(() => _homeMapLoadTimedOut = true);
      }
    });
  }

  void _retryHomeMap() {
    setState(() {
      _homeMapStyleLoaded = false;
      _homeMapLoadTimedOut = false;
      _mapController = null;
      _homeMapInstance++;
    });
    _startHomeMapLoadTimeout();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoadingDashboard = true;
      _dashboardError = null;
    });
    final profileRequest = AuthService.loadSession();
    try {
      final nearbyRides = await RideService.searchRides({'limit': '5'});
      if (!mounted) return;
      setState(() {
        _nearbyRides = nearbyRides;
        _isLoadingDashboard = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _nearbyRides = const [];
        _isLoadingDashboard = false;
        _dashboardError = error.toString();
      });
    }

    try {
      final user = await profileRequest;
      if (mounted && user?.name.trim().isNotEmpty == true) {
        setState(() => _displayName = user!.name.trim());
      }
    } catch (error) {
      debugPrint('Could not refresh the home profile: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildMapFirstHome(),

      // ── Bottom Navigation Bar ───────────────────────────────────────────
      bottomNavigationBar: widget.embeddedInShell
          ? null
          : AppBottomNavBar(
              currentIndex: _currentNavIndex,
              onTap: (index) {
                if (index == 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyRidesScreen()),
                  );
                } else if (index == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OfferRideScreen()),
                  );
                } else if (index == 3) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapScreen()),
                  );
                } else if (index == 4) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                } else {
                  setState(() => _currentNavIndex = index);
                }
              },
              items: const [
                AppNavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Home',
                ),
                AppNavItem(
                  icon: Icons.two_wheeler_outlined,
                  selectedIcon: Icons.two_wheeler_rounded,
                  label: 'Rides',
                ),
                AppNavItem(
                  icon: Icons.add_circle_outline_rounded,
                  selectedIcon: Icons.add_circle_rounded,
                  label: 'Offer',
                ),
                AppNavItem(
                  icon: Icons.map_outlined,
                  selectedIcon: Icons.map_rounded,
                  label: 'Map',
                ),
                AppNavItem(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: 'Profile',
                ),
              ],
            ),
    );
  }

  Widget _buildMapFirstHome() {
    final supportsMap =
        !isFlutterTest &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final hasActiveRoute =
        _activeRoute != null || RoutePreviewStore.instance.route != null;
    final displayRoute =
        _activeRoute ?? RoutePreviewStore.instance.route;
    final scrollBehavior = ScrollConfiguration.of(context);

    return Stack(
      children: [
        // ── Native Map or Desktop Fallback ──
        if (supportsMap)
          Positioned.fill(
            child: MapLibreMap(
              key: ValueKey(_homeMapInstance),
              styleString: MapConfig.styleUrl,
              initialCameraPosition: MapConfig.initialCameraPosition,
              rotateGesturesEnabled: true,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              tiltGesturesEnabled: true,
              doubleClickZoomEnabled: true,
              dragEnabled: true,
              trackCameraPosition: true,
              onMapClick: _onHomeMapTap,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_homeMapStyleLoaded) {
                  _loadHomeHubs();
                  _onRoutePreviewChanged();
                }
              },
              onStyleLoadedCallback: () {
                _homeMapStyleLoaded = true;
                _homeMapLoadTimedOut = false;
                _loadHomeHubs();
                _onRoutePreviewChanged();
                if (mounted) setState(() {});
              },
            ),
          )
        else
          Positioned.fill(
            child: _buildDesktopMapFallback(),
          ),

        // ── Map Loading / Slow Warning Badge (Non-blocking) ──
        if (supportsMap && !_homeMapStyleLoaded)
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            left: AppSpacing.marginMobile,
            child: PointerInterceptor(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_homeMapLoadTimedOut) ...[
                      const Icon(Icons.refresh_rounded, size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      const Text(
                        'Map loading slowly',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _retryHomeMap,
                        child: const Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Loading map tiles...',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

        // ── Bottom Draggable Pools Sheet ──
        ScrollConfiguration(
          behavior: scrollBehavior.copyWith(
            dragDevices: {
              ...scrollBehavior.dragDevices,
              PointerDeviceKind.mouse,
            },
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.30,
            minChildSize: 0.18,
            maxChildSize: 0.78,
            snap: true,
            snapSizes: const [0.30, 0.78],
            builder: (context, scrollController) => PointerInterceptor(
              child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.marginMobile,
                  AppSpacing.sm,
                  AppSpacing.marginMobile,
                  AppSpacing.xl,
                ),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: AppSpacing.radiusFull,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedDestination != null
                              ? 'Rides to ${_selectedDestination!.displayName.split(',').first}'
                              : 'Available pools near you',
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedDestination != null)
                        TextButton(
                          onPressed: _clearSearchAndRoute,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          child: const Text('Show all'),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_isLoadingDashboard)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_dashboardError != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Could not load available pools: $_dashboardError',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _loadDashboardData,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    )
                  else if (_nearbyRides.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedDestination != null
                                ? 'No direct rides found to ${_selectedDestination!.displayName.split(',').first} right now.'
                                : 'No rides found near VIT College yet.',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FindRidesScreen(
                                  initialOrigin: 'VIT Pune',
                                  initialDestination: _selectedDestination?.displayName,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.search_rounded, size: 18),
                            label: const Text('Search Custom Time & Date'),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._nearbyRides.map(
                      (ride) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _buildRideCard(ride),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        ),

        // ── Top Bar with Search, Hub Chips & Active Route Banner ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: PointerInterceptor(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.marginMobile,
                  AppSpacing.sm,
                  AppSpacing.marginMobile,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMapSearchPanel(),
                    if (_searchSuggestions.isNotEmpty) _buildSearchSuggestionsDropdown(),
                    const SizedBox(height: 8),
                    _buildQuickCampusHubChips(),
                    if (hasActiveRoute && displayRoute != null) ...[
                      const SizedBox(height: 8),
                      _buildActiveRouteBanner(displayRoute),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Floating Action Buttons & Map Controls (Right Side) ──
        Positioned(
          right: AppSpacing.marginMobile,
          top: MediaQuery.of(context).padding.top + 120,
          child: PointerInterceptor(
            child: SizedBox(
              width: 160,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AutoGroupsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.groups_rounded, size: 18),
                    label: const Text('Auto Groups'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.secondary,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppSpacing.radiusFull,
                      ),
                    ),
                  ),
                  if (supportsMap) ...[
                    const SizedBox(height: 12),
                    FloatingActionButton.small(
                      heroTag: 'home-zoom-in',
                      tooltip: 'Zoom in',
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.primary,
                      onPressed: () => _mapController?.animateCamera(
                        CameraUpdate.zoomIn(),
                      ),
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'home-zoom-out',
                      tooltip: 'Zoom out',
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.primary,
                      onPressed: () => _mapController?.animateCamera(
                        CameraUpdate.zoomOut(),
                      ),
                      child: const Icon(Icons.remove),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'home-location',
                      tooltip: 'Reset map view',
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.primary,
                      onPressed: () => _mapController?.animateCamera(
                        CameraUpdate.newCameraPosition(
                          MapConfig.initialCameraPosition,
                        ),
                      ),
                      child: const Icon(Icons.my_location_rounded),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopMapFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F0FE), Color(0xFFF1F3F4), Color(0xFFE3F2FD)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: 60,
            child: Icon(
              Icons.explore_outlined,
              size: 240,
              color: Colors.blue.withValues(alpha: 0.08),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VIT Pune Campus Hub',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                'Bibwewadi, Pune · 18.464° N, 73.867° E',
                                style: TextStyle(color: Colors.black54, fontSize: 11),
                              ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Campus Corridors & Safe Hubs',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _popularCampusPlaces.skip(1).take(5).map((hub) {
                      final isSelected = _selectedDestination?.placeId == hub.placeId;
                      return ActionChip(
                        avatar: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.location_on_rounded,
                          size: 14,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                        backgroundColor: isSelected ? AppColors.primary : Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        label: Text(hub.displayName.split(',').first),
                        onPressed: () => _onSelectDestination(hub),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCampusHubChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _popularCampusPlaces.skip(1).map((hub) {
          final isSelected = _selectedDestination?.placeId == hub.placeId;
          final shortName = hub.displayName.split(',').first.trim();
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: Icon(
                isSelected ? Icons.check_circle_rounded : Icons.location_on_rounded,
                size: 14,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
              backgroundColor: isSelected ? AppColors.primary : AppColors.surface,
              elevation: 2,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
              label: Text(shortName),
              onPressed: () => _onSelectDestination(hub),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveRouteBanner(RouteResult displayRoute) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.route_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedDestination != null
                        ? 'To ${_selectedDestination!.displayName.split(',').first}'
                        : 'Route Preview',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _homeRouteError ??
                        '${displayRoute.formattedDistance} · '
                            'Fare: ${formatRideFare(displayRoute.distanceMeters)}/seat',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FindRidesScreen(
                    initialOrigin: 'VIT Pune',
                    initialDestination: _selectedDestination?.displayName ??
                        _searchController.text.trim(),
                  ),
                ),
              ),
              child: const Text(
                'Find Rides',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSuggestionsDropdown() {
    if (_searchSuggestions.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(top: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _searchSuggestions.length.clamp(0, 4),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final place = _searchSuggestions[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.location_on_outlined, size: 20, color: AppColors.primary),
            title: Text(
              place.displayName.split(',').first,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              place.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
            onTap: () => _onSelectDestination(place),
          );
        },
      ),
    );
  }

  void _openSearchDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => PointerInterceptor(
        child: StatefulBuilder(
          builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Search Places & Safe Hubs',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(modalContext),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search destination or campus hub...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setModalState(() {});
                            _onSearchQueryChanged('');
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  setModalState(() {});
                  _onSearchQueryChanged(val);
                },
              ),
              if (_searchSuggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._searchSuggestions.take(4).map(
                  (place) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on, color: AppColors.primary),
                    title: Text(place.displayName.split(',').first),
                    subtitle: Text(place.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      Navigator.pop(modalContext);
                      _onSelectDestination(place);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildMapSearchPanel() {
    return Material(
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      color: AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openFindRides,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: _openSearchDialog,
                child: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _selectedDestination != null
                      ? _selectedDestination!.displayName.split(',').first
                      : 'Where do you want to go?',
                  style: AppTypography.bodyMd.copyWith(
                    color: _selectedDestination != null
                        ? AppColors.onSurface
                        : AppColors.onSurfaceVariant,
                    fontWeight: _selectedDestination != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (_selectedDestination != null)
                GestureDetector(
                  onTap: _clearSearchAndRoute,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  ),
                ),
              GestureDetector(
                onTap: _openSearchDialog,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.marginMobile,
        AppSpacing.lg,
        AppSpacing.marginMobile,
        AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, $_displayName! 👋',
                style: AppTypography.headlineLgMobile.copyWith(
                  color: AppColors.onBackground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ready to move?',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _NotificationButton(
                onTap: () {
                  if (widget.embeddedInShell) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AlertsScreen()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AlertsScreen()),
                    );
                  }
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              PopupMenuButton<String>(
                icon: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _displayName.isNotEmpty
                          ? _displayName[0].toUpperCase()
                          : 'U',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppSpacing.radiusMd,
                ),
                onSelected: (value) async {
                  if (value == 'profile') {
                    if (widget.embeddedInShell) {
                      MainNavigationShell.switchTab(context, 4);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    }
                  } else if (value == 'logout') {
                    await AuthService.logout();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          'Student Account',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'My Profile',
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Log Out',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Location Card ────────────────────────────────────────────────────────
  Widget _buildLocationCard() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT LOCATION',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Campus Library',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.outlineVariant,
            size: 22,
          ),
        ],
      ),
    );
  }

  // ── Bento Grid Action Cards ──────────────────────────────────────────────
  Widget _buildActionCards() {
    return Row(
      children: [
        // Find a Ride (Light Card)
        Expanded(
          child: _ActionCard(
            height: 180,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FindRidesScreen()),
            ),
            child: Stack(
              children: [
                // Background gradient
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.surfaceContainerLow,
                          AppColors.surfaceContainer.withValues(alpha: 0.5),
                        ],
                      ),
                      borderRadius: AppSpacing.radiusLg,
                    ),
                  ),
                ),
                // Icon in top-right
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryFixed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                ),
                // Text at bottom
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.xl + AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Find a Ride',
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Going the same way? Coordinate a shared auto with fellow students.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.md),

        // Offer a Ride (Primary Blue Card)
        Expanded(
          child: _ActionCard(
            height: 180,
            backgroundColor: AppColors.primary,
            hasBorder: false,
            onTap: () {
              if (widget.embeddedInShell) {
                MainNavigationShell.switchTab(context, 2);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OfferRideScreen()),
                );
              }
            },
            child: Stack(
              children: [
                // Decorative blobs
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  left: -20,
                  bottom: -20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer.withValues(
                        alpha: 0.15,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Motorcycle icon in top-right
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.two_wheeler_rounded,
                      color: AppColors.onPrimary,
                      size: 26,
                    ),
                  ),
                ),
                // Text at bottom
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.xl + AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Offer a Ride',
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Heading out? Pick up a fellow student on your way.',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.80),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Nearby Rides Section ─────────────────────────────────────────────────
  Widget _buildNearbyRidesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.marginMobile,
            0,
            AppSpacing.marginMobile,
            AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nearby Rides',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FindRidesScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                ),
                child: Text(
                  'See all',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isLoadingDashboard)
          const SizedBox(
            height: 258,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_nearbyRides.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
            ),
            child: Text(
              _dashboardError == null
                  ? 'No nearby rides available.'
                  : 'Unable to load nearby rides.',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          )
        else
          SizedBox(
            height: 258,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
              ),
              itemCount: _nearbyRides.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) => SizedBox(
                width: 320,
                child: _buildRideCard(_nearbyRides[index]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRideCard(
    RideModel ride, {
    RideStatusType status = RideStatusType.available,
    String bookButtonText = 'Book Seat',
  }) {
    final driver = ride.driver;
    return AppRideCard(
      driverName: driver?.name.isNotEmpty == true
          ? driver!.name
          : 'Campus Driver',
      origin: ride.originName,
      destination: ride.destName,
      departureTime: status == RideStatusType.active
          ? 'NOW'
          : MaterialLocalizations.of(context).formatTimeOfDay(
              TimeOfDay.fromDateTime(ride.departureTime.toLocal()),
            ),
      availableSeats: ride.availableSeats,
      price: ride.contribution,
      vehicleType: ride.vehicleType,
      vehicleModel: driver?.vehicleModel.isNotEmpty == true
          ? driver!.vehicleModel
          : null,
      driverRating: driver?.ratingAvg ?? 0.0,
      matchPercentage: ride.matchAcceptanceProbability == null
          ? null
          : (ride.matchAcceptanceProbability! * 100).round(),
      status: status,
      bookButtonText: bookButtonText,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RideDetailsScreen(ride: ride)),
      ),
      onBookTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RideDetailsScreen(ride: ride)),
      ),
    );
  }
}

// ── Reusable Internal Widgets ────────────────────────────────────────────────

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap:
                  onTap ??
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DriverRequestQueueScreen(),
                      ),
                    );
                  },
              child: const Icon(
                Icons.notifications_outlined,
                color: AppColors.onSurface,
                size: 22,
              ),
            ),
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.child,
    required this.onTap,
    this.height = 180,
    this.backgroundColor = AppColors.surface,
    this.hasBorder = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final double height;
  final Color backgroundColor;
  final bool hasBorder;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: AppSpacing.radiusLg,
            border: widget.hasBorder
                ? Border.all(color: AppColors.border, width: 1)
                : null,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: widget.child,
        ),
      ),
    );
  }
}
