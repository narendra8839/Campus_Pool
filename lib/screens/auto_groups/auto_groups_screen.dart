import 'package:flutter/material.dart';

import '../../models/corridor_model.dart';
import '../../services/api_service.dart';
import '../../services/route_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// V1 coordination screen. It deliberately contains no payment or fare logic.
class AutoGroupsScreen extends StatefulWidget {
  const AutoGroupsScreen({super.key});

  @override
  State<AutoGroupsScreen> createState() => _AutoGroupsScreenState();
}

class _AutoGroupsScreenState extends State<AutoGroupsScreen> {
  List<dynamic> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/auto-groups/my-groups', requiresAuth: true);
      if (!mounted) return;
      setState(() => _groups = response['data'] as List<dynamic>? ?? []);
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createRequest(
    CorridorModel corridor,
    HubModel pickup,
    HubModel destination,
    DateTime time,
  ) async {
    try {
      final response = await ApiService.post(
        '/auto-groups/requests',
        requiresAuth: true,
        body: {
          'corridorId': corridor.id,
          'pickupHubId': pickup.id,
          'destinationHubId': destination.id,
          'desiredDepartureTime': time.toUtc().toIso8601String(),
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      _showMessage(response['message']?.toString() ?? 'Auto-group request created.');
      await _loadGroups();
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _updateMembership(String groupId, String action) async {
    try {
      final response = await ApiService.patch('/auto-groups/$groupId/$action', requiresAuth: true);
      if (!mounted) return;
      _showMessage(response['message']?.toString() ?? 'Group updated.');
      await _loadGroups();
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.secondary,
        behavior: SnackBarBehavior.fixed,
      ));
  }

  void _showCreateRequestSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateAutoRequestSheet(onSubmit: _createRequest),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auto Groups')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRequestSheet,
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Find group'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroups,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _groups.isEmpty
                ? ListView(children: const [SizedBox(height: 170), Center(child: Text('No active auto-group requests yet.'))])
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.marginMobile),
                    itemCount: _groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) => _AutoGroupCard(
                      group: _groups[index] as Map<String, dynamic>,
                      onConfirm: () => _updateMembership(_groups[index]['id'].toString(), 'confirm'),
                      onLeave: () => _updateMembership(_groups[index]['id'].toString(), 'leave'),
                    ),
                  ),
      ),
    );
  }
}

class _AutoGroupCard extends StatelessWidget {
  const _AutoGroupCard({required this.group, required this.onConfirm, required this.onLeave});
  final Map<String, dynamic> group;
  final VoidCallback onConfirm;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final members = group['members'] as List<dynamic>? ?? [];
    final status = group['status']?.toString() ?? 'FORMING';
    final time = DateTime.tryParse(group['departureTime']?.toString() ?? '')?.toLocal();
    final isReady = status == 'READY' || status == 'CONFIRMED';
    final corridor = group['corridor'] as Map<String, dynamic>?;
    final memberTrips = members.map((member) {
      final request = (member as Map<String, dynamic>)['request']
          as Map<String, dynamic>?;
      if (request == null) return null;
      return '${request['pickupName']} → ${request['destinationName']}';
    }).whereType<String>().join(' • ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.local_taxi_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(corridor?['name']?.toString() ?? 'Auto route group', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700))),
            Chip(label: Text(status)),
          ]),
          const SizedBox(height: 8),
          Text('${members.length}/${group['maxMembers']} students • ${time == null ? 'Time not available' : MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(time))}'),
          const SizedBox(height: 8),
          if (memberTrips.isNotEmpty)
            Text('Trips: $memberTrips', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(members.map((member) => member['user']?['name']?.toString() ?? 'Student').join(', '), style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          const Divider(height: 24),
          Text('Fare is decided directly with the auto driver.', style: AppTypography.caption.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(children: [
            if (isReady) OutlinedButton(onPressed: onConfirm, child: const Text('Confirm')),
            if (isReady) const SizedBox(width: 8),
            TextButton(onPressed: onLeave, child: const Text('Leave group')),
          ]),
        ]),
      ),
    );
  }
}

class _CreateAutoRequestSheet extends StatefulWidget {
  const _CreateAutoRequestSheet({required this.onSubmit});

  final Future<void> Function(
    CorridorModel corridor,
    HubModel pickup,
    HubModel destination,
    DateTime time,
  ) onSubmit;

  @override
  State<_CreateAutoRequestSheet> createState() => _CreateAutoRequestSheetState();
}

class _CreateAutoRequestSheetState extends State<_CreateAutoRequestSheet> {
  List<CorridorModel> _corridors = [];
  CorridorModel? _selectedCorridor;
  HubModel? _selectedPickup;
  HubModel? _selectedDestination;
  DateTime _selectedTime = DateTime.now().add(const Duration(minutes: 30));
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadCorridors();
  }

  Future<void> _loadCorridors() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final corridors = (await RouteService.listCorridors())
          .where((corridor) => corridor.hubs.length >= 2)
          .toList();
      if (!mounted) return;
      setState(() {
        _corridors = corridors;
        _selectedCorridor = corridors.isEmpty ? null : corridors.first;
        _selectedPickup = _selectedCorridor?.hubs.first;
        _selectedDestination = _selectedCorridor?.hubs.length == 1
            ? null
            : _selectedCorridor?.hubs[1];
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _chooseDepartureTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate: _selectedTime,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTime),
    );
    if (time != null) {
      setState(() {
        _selectedTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Future<void> _submit() async {
    final corridor = _selectedCorridor;
    final pickup = _selectedPickup;
    final destination = _selectedDestination;
    if (corridor == null || pickup == null || destination == null) return;

    setState(() => _isSubmitting = true);
    await widget.onSubmit(corridor, pickup, destination, _selectedTime);
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final corridor = _selectedCorridor;
    final pickup = _selectedPickup;
    final destination = _selectedDestination;
    final availableDestinations = corridor?.hubs
        .where((hub) => hub.id != pickup?.id)
        .toList() ?? const <HubModel>[];

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find an auto group',
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a corridor and two stops. Students can get off at different stops, as long as everyone shares part of the same route.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_loadError != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_loadError!, style: TextStyle(color: AppColors.error)),
                  TextButton(
                    onPressed: _loadCorridors,
                    child: const Text('Try again'),
                  ),
                ],
              )
            else if (_corridors.isEmpty)
              const Text('No routes with stops are available yet.')
            else ...[
              DropdownButtonFormField<String>(
                value: corridor?.id,
                decoration: const InputDecoration(labelText: 'Route'),
                items: _corridors
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  final selected = _corridors.firstWhere(
                    (item) => item.id == id,
                  );
                  setState(() {
                    _selectedCorridor = selected;
                    _selectedPickup = selected.hubs.first;
                    _selectedDestination = selected.hubs[1];
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: pickup?.id,
                decoration: const InputDecoration(labelText: 'Pickup stop'),
                items: corridor!.hubs
                    .map(
                      (hub) => DropdownMenuItem(
                        value: hub.id,
                        child: Text(hub.name),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  final selected = corridor.hubs.firstWhere(
                    (hub) => hub.id == id,
                  );
                  setState(() {
                    _selectedPickup = selected;
                    if (_selectedDestination?.id == selected.id) {
                      _selectedDestination = corridor.hubs.firstWhere(
                        (hub) => hub.id != selected.id,
                      );
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: destination?.id,
                decoration: const InputDecoration(labelText: 'Drop-off stop'),
                items: availableDestinations
                    .map(
                      (hub) => DropdownMenuItem(
                        value: hub.id,
                        child: Text(hub.name),
                      ),
                    )
                    .toList(),
                onChanged: (id) => setState(
                  () => _selectedDestination = corridor.hubs.firstWhere(
                    (hub) => hub.id == id,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.schedule_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Desired departure'),
                subtitle: Text(
                  '${MaterialLocalizations.of(context).formatFullDate(_selectedTime)}  '
                  '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_selectedTime))}',
                ),
                onTap: _chooseDepartureTime,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: const Icon(Icons.group_add_rounded),
                  label: Text(
                    _isSubmitting ? 'Creating request...' : 'Create request',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
