import 'dart:async';
import 'package:flutter/material.dart';
import '../components/components.dart';
import '../models/ride_model.dart';
import '../models/corridor_model.dart';
import '../services/ride_service.dart';
import '../services/route_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'auto_groups/auto_groups_screen.dart';
import 'ride_details_screen.dart';

enum SortOption { earliest, lowestPrice, topRated }

class FindRidesScreen extends StatefulWidget {
  const FindRidesScreen({
    super.key,
    this.initialOrigin,
    this.initialDestination,
  });

  final String? initialOrigin;
  final String? initialDestination;

  @override
  State<FindRidesScreen> createState() => _FindRidesScreenState();
}

class _FindRidesScreenState extends State<FindRidesScreen> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();

  DateTime? _selectedDate;
  String _dateFilterMode = 'any'; // 'any', 'today', 'tomorrow', 'custom'
  int _selectedSeats = 1;
  String _selectedVehicleType = 'all'; // 'all', 'bike', 'scooty'
  SortOption _currentSort = SortOption.earliest;

  bool _isLoading = false;
  String? _errorMessage;
  List<RideModel> _rides = [];
  List<CorridorModel> _corridors = const [];
  CorridorModel? _selectedCorridor;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialOrigin != null) {
      _originController.text = widget.initialOrigin!;
    }
    if (widget.initialDestination != null) {
      _destinationController.text = widget.initialDestination!;
    }
    _loadCorridors();
    _searchRides();
  }

  Future<void> _loadCorridors() async {
    try {
      final corridors = await RouteService.listCorridors();
      if (mounted) setState(() => _corridors = corridors);
    } catch (_) {
      // Text search remains available when the route catalogue is offline.
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _onSearchInputChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _searchRides();
    });
  }

  void _swapLocations() {
    final temp = _originController.text;
    _originController.text = _destinationController.text;
    _destinationController.text = temp;
    _searchRides();
  }

  void _setDateFilter(String mode) async {
    final now = DateTime.now();
    setState(() {
      _dateFilterMode = mode;
      if (mode == 'any') {
        _selectedDate = null;
      } else if (mode == 'today') {
        _selectedDate = DateTime(now.year, now.month, now.day);
      } else if (mode == 'tomorrow') {
        final tom = now.add(const Duration(days: 1));
        _selectedDate = DateTime(tom.year, tom.month, tom.day);
      }
    });

    if (mode == 'custom') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate ?? now,
        firstDate: now,
        lastDate: now.add(const Duration(days: 90)),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                onSurface: AppColors.onSurface,
              ),
            ),
            child: child!,
          );
        },
      );

      if (picked != null) {
        setState(() {
          _selectedDate = picked;
          _dateFilterMode = 'custom';
        });
      } else {
        if (_selectedDate == null) {
          setState(() => _dateFilterMode = 'any');
        }
      }
    }

    _searchRides();
  }

  Future<void> _searchRides() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final Map<String, String> queryParams = {};

    final fromText = _originController.text.trim();
    if (fromText.isNotEmpty) {
      queryParams['from'] = fromText;
    }

    final toText = _destinationController.text.trim();
    if (toText.isNotEmpty) {
      queryParams['to'] = toText;
    }

    if (_selectedDate != null) {
      final y = _selectedDate!.year.toString().padLeft(4, '0');
      final m = _selectedDate!.month.toString().padLeft(2, '0');
      final d = _selectedDate!.day.toString().padLeft(2, '0');
      queryParams['date'] = '$y-$m-$d';
    }

    if (_selectedSeats > 1) {
      queryParams['seats'] = _selectedSeats.toString();
    }

    if (_selectedVehicleType != 'all') {
      queryParams['vehicleType'] = _selectedVehicleType;
    }
    if (_selectedCorridor != null) {
      queryParams['corridorId'] = _selectedCorridor!.id;
    }

    try {
      final results = await RideService.searchRides(queryParams);
      if (mounted) {
        setState(() {
          _rides = _applySorting(results);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<RideModel> _applySorting(List<RideModel> rides) {
    final list = List<RideModel>.from(rides);
    switch (_currentSort) {
      case SortOption.earliest:
        list.sort((a, b) => a.departureTime.compareTo(b.departureTime));
        break;
      case SortOption.lowestPrice:
        list.sort((a, b) => a.contribution.compareTo(b.contribution));
        break;
      case SortOption.topRated:
        list.sort((a, b) {
          final rA = a.driver?.ratingAvg ?? 5.0;
          final rB = b.driver?.ratingAvg ?? 5.0;
          return rB.compareTo(rA);
        });
        break;
    }
    return list;
  }

  void _clearAllFilters() {
    setState(() {
      _originController.clear();
      _destinationController.clear();
      _dateFilterMode = 'any';
      _selectedDate = null;
      _selectedSeats = 1;
      _selectedVehicleType = 'all';
      _currentSort = SortOption.earliest;
      _selectedCorridor = null;
    });
    _searchRides();
  }

  void _showSortFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.marginMobile,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sort & Filter Options',
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.md),
              Text(
                'SORT BY',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              RadioListTile<SortOption>(
                title: const Text('Earliest Departure Time'),
                value: SortOption.earliest,
                groupValue: _currentSort,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setModalState(() => _currentSort = val!);
                  setState(() => _rides = _applySorting(_rides));
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('Lowest Contribution / Price'),
                value: SortOption.lowestPrice,
                groupValue: _currentSort,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setModalState(() => _currentSort = val!);
                  setState(() => _rides = _applySorting(_rides));
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('Top Rated Driver'),
                value: SortOption.topRated,
                groupValue: _currentSort,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setModalState(() => _currentSort = val!);
                  setState(() => _rides = _applySorting(_rides));
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppPrimaryButton(
                text: 'Apply',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build Main UI ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Find a Ride',
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Sort & Options',
            onPressed: _showSortFilterModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _searchRides,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search & Filter Panel ───────────────────────────────────────
          _buildSearchPanel(),

          // ── Results Status Header ───────────────────────────────────────
          _buildResultsCountHeader(),

          // ── Results List ────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? _buildErrorView()
                : _rides.isEmpty
                ? _buildEmptyState()
                : _buildRidesList(),
          ),
        ],
      ),
    );
  }

  // ── Search Panel ──────────────────────────────────────────────────────────
  Widget _buildSearchPanel() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.marginMobile,
        AppSpacing.xs,
        AppSpacing.marginMobile,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_corridors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: DropdownButtonFormField<CorridorModel>(
                value: _selectedCorridor,
                decoration: const InputDecoration(
                  labelText: 'VIT commute corridor',
                  prefixIcon: Icon(Icons.alt_route),
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<CorridorModel>(
                    value: null,
                    child: Text('All VIT corridors'),
                  ),
                  ..._corridors.map(
                    (corridor) => DropdownMenuItem(
                      value: corridor,
                      child: Text(corridor.name),
                    ),
                  ),
                ],
                onChanged: (corridor) {
                  setState(() {
                    _selectedCorridor = corridor;
                    if (corridor != null) {
                      _originController.text = corridor.hubs.first.name;
                      _destinationController.text = corridor.destinationName;
                    }
                  });
                  _searchRides();
                },
              ),
            ),
          // Origin & Destination Inputs with Swap Button
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppSpacing.radiusLg,
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Column(
                    children: [
                      // Origin Input
                      TextField(
                        controller: _originController,
                        onChanged: (_) => _onSearchInputChanged(),
                        decoration: const InputDecoration(
                          hintText: 'Pickup / Origin (e.g. Library)',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: AppColors.outline,
                          ),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.radio_button_checked,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          prefixIconConstraints: BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        style: AppTypography.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      // Destination Input
                      TextField(
                        controller: _destinationController,
                        onChanged: (_) => _onSearchInputChanged(),
                        decoration: const InputDecoration(
                          hintText: 'Destination (e.g. Metro Station)',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: AppColors.outline,
                          ),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.location_on,
                            color: AppColors.secondary,
                            size: 20,
                          ),
                          prefixIconConstraints: BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        style: AppTypography.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Swap Button
                Positioned(
                  right: AppSpacing.md,
                  top: 28,
                  child: Material(
                    color: AppColors.surface,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _swapLocations,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.swap_vert_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Popular Campus Locations Quick Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _corridors
                  .expand((corridor) => corridor.hubs.map((hub) => hub.name))
                  .toSet()
                  .take(8)
                  .map((loc) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ActionChip(
                        label: Text(loc),
                        avatar: const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        labelStyle: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        backgroundColor: AppColors.surfaceContainerLow,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onPressed: () {
                          if (_originController.text.isEmpty) {
                            _originController.text = loc;
                          } else {
                            _destinationController.text = loc;
                          }
                          _searchRides();
                        },
                      ),
                    );
                  })
                  .toList(),
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          // Filter Segment: Date, Vehicle, Seats
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Date Filter Chips
                _buildDateChip('Any Date', 'any'),
                const SizedBox(width: 6),
                _buildDateChip('Today', 'today'),
                const SizedBox(width: 6),
                _buildDateChip('Tomorrow', 'tomorrow'),
                const SizedBox(width: 6),
                _buildDateChip(
                  _dateFilterMode == 'custom' && _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}'
                      : 'Pick Date 📅',
                  'custom',
                ),

                const SizedBox(width: 12),
                Container(width: 1, height: 24, color: AppColors.border),
                const SizedBox(width: 12),

                // Vehicle Type Filter Chips
                _buildVehicleChip(
                  'All Vehicles',
                  'all',
                  Icons.all_inclusive_rounded,
                ),
                const SizedBox(width: 6),
                _buildVehicleChip('Bike', 'bike', Icons.two_wheeler_rounded),
                const SizedBox(width: 6),
                _buildVehicleChip('Scooty', 'scooty', Icons.moped_rounded),
                const SizedBox(width: 6),
                const SizedBox(width: 12),
                Container(width: 1, height: 24, color: AppColors.border),
                const SizedBox(width: 12),

                // Seats Filter
                _buildSeatsChip(1, '1+ Seats'),
                const SizedBox(width: 6),
                _buildSeatsChip(2, '2+ Seats'),
                const SizedBox(width: 6),
                _buildSeatsChip(3, '3+ Seats'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label, String mode) {
    final isSelected = _dateFilterMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryContainer,
      labelStyle: AppTypography.caption.copyWith(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
      ),
      backgroundColor: AppColors.surfaceContainerLow,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      onSelected: (_) => _setDateFilter(mode),
    );
  }

  Widget _buildVehicleChip(String label, String vehicleType, IconData icon) {
    final isSelected = _selectedVehicleType == vehicleType;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryContainer,
      labelStyle: AppTypography.caption.copyWith(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
      ),
      backgroundColor: AppColors.surfaceContainerLow,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedVehicleType = vehicleType);
          _searchRides();
        }
      },
    );
  }

  Widget _buildSeatsChip(int seats, String label) {
    final isSelected = _selectedSeats == seats;
    return ChoiceChip(
      avatar: Icon(
        Icons.event_seat_rounded,
        size: 14,
        color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryContainer,
      labelStyle: AppTypography.caption.copyWith(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
      ),
      backgroundColor: AppColors.surfaceContainerLow,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedSeats = seats);
          _searchRides();
        }
      },
    );
  }

  // ── Results Count Header ──────────────────────────────────────────────────
  Widget _buildResultsCountHeader() {
    final hasActiveFilters =
        _originController.text.isNotEmpty ||
        _destinationController.text.isNotEmpty ||
        _dateFilterMode != 'any' ||
        _selectedVehicleType != 'all' ||
        _selectedSeats > 1;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginMobile,
        vertical: AppSpacing.xs + 2,
      ),
      color: AppColors.surfaceContainerLow.withValues(alpha: 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _isLoading
                ? 'Searching available pools...'
                : '${_rides.length} available pool${_rides.length == 1 ? '' : 's'} found',
            style: AppTypography.labelSm.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          if (hasActiveFilters)
            InkWell(
              onTap: _clearAllFilters,
              child: Row(
                children: [
                  const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Clear filters',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Rides List ────────────────────────────────────────────────────────────
  Widget _buildRidesList() {
    return RefreshIndicator(
      onRefresh: _searchRides,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        itemCount: _rides.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final ride = _rides[index];
          final driver = ride.driver;

          return AppRideCard(
            driverName: driver?.name.isNotEmpty ?? false
                ? driver!.name
                : 'Student Driver',
            origin: ride.originName,
            destination: ride.destName,
            departureTime: _formatDateTime(ride.departureTime),
            availableSeats: ride.availableSeats,
            price: ride.contribution,
            driverRating: driver?.ratingAvg ?? 5.0,
            vehicleType: ride.vehicleType,
            vehicleModel: driver?.vehicleModel.isNotEmpty ?? false
                ? driver!.vehicleModel
                : ride.vehicleType,
            status: RideStatusType.available,
            bookButtonText: 'Book Seat',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RideDetailsScreen(ride: ride),
                ),
              );
            },
            onBookTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RideDetailsScreen(ride: ride),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No Matching Rides Found',
            style: AppTypography.headlineSm.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No drivers have offered a pool matching your current route and filters.',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Clear Filters Button
          OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset All Filters'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusMd),
            ),
            onPressed: _clearAllFilters,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Shared Auto Group Recommendation Card
          AppCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AutoGroupsScreen()),
              );
            },
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.secondaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: AppColors.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Can’t find a ride? Try Auto Pooling',
                        style: AppTypography.labelMd.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Match with 3-4 peers going your way and share an auto rickshaw.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.outlineVariant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Failed to search rides',
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _errorMessage!,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _searchRides,
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final localDt = dt.toLocal();
    final now = DateTime.now();
    final isToday =
        localDt.year == now.year &&
        localDt.month == now.month &&
        localDt.day == now.day;
    final isTomorrow =
        localDt.year == now.year &&
        localDt.month == now.month &&
        localDt.day == now.day + 1;

    final hour = localDt.hour > 12
        ? localDt.hour - 12
        : (localDt.hour == 0 ? 12 : localDt.hour);
    final period = localDt.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = localDt.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minuteStr $period';

    if (isToday) return 'Today, $timeStr';
    if (isTomorrow) return 'Tomorrow, $timeStr';
    return '${localDt.day}/${localDt.month}, $timeStr';
  }
}
