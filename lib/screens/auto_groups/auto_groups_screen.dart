import 'package:flutter/material.dart';

import '../../models/corridor_model.dart';
import '../../services/api_service.dart';
import '../../services/route_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class AutoGroupsScreen extends StatefulWidget {
  const AutoGroupsScreen({super.key});

  @override
  State<AutoGroupsScreen> createState() => _AutoGroupsScreenState();
}

class _AutoGroupsScreenState extends State<AutoGroupsScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _browseGroups = [];
  List<dynamic> _myGroups = [];
  bool _isLoading = true;
  String? _loadError;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGroups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final responses = await Future.wait([
        ApiService.get('/auto-groups/browse', requiresAuth: true),
        ApiService.get('/auto-groups/my-groups', requiresAuth: true),
      ]);
      if (!mounted) return;
      setState(() {
        _browseGroups = _readList(responses[0]);
        _myGroups = _readList(responses[1]);
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _readList(dynamic response) {
    if (response is! Map<String, dynamic> || response['data'] is! List) {
      throw const FormatException('Unexpected auto-group response.');
    }
    return response['data'] as List<dynamic>;
  }

  Future<void> _createListing(
    CorridorModel corridor,
    HubModel pickup,
    HubModel destination,
    DateTime time,
    int maxMembers,
  ) async {
    try {
      final response = await ApiService.post(
        '/auto-groups/groups',
        requiresAuth: true,
        body: {
          'corridorId': corridor.id,
          'pickupHubId': pickup.id,
          'destinationHubId': destination.id,
          'desiredDepartureTime': time.toUtc().toIso8601String(),
          'maxMembers': maxMembers,
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      _showMessage(_responseMessage(response, 'Your group is now listed.'));
      await _loadGroups();
      if (mounted) _tabController.animateTo(1);
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _requestToJoin(
    String groupId,
    CorridorModel corridor,
    HubModel pickup,
    HubModel destination,
    DateTime time,
    int _,
  ) async {
    try {
      final response = await ApiService.post(
        '/auto-groups/$groupId/join-requests',
        requiresAuth: true,
        body: {
          'pickupHubId': pickup.id,
          'destinationHubId': destination.id,
          'desiredDepartureTime': time.toUtc().toIso8601String(),
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      _showMessage(
        _responseMessage(response, 'Join request sent to the organizer.'),
      );
      await _loadGroups();
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    }
  }

  String _responseMessage(dynamic response, String fallback) =>
      response is Map<String, dynamic>
      ? response['message']?.toString() ?? fallback
      : fallback;

  Future<void> _updateMembership(String groupId, String action) async {
    try {
      final response = await ApiService.patch(
        '/auto-groups/$groupId/$action',
        requiresAuth: true,
      );
      if (!mounted) return;
      _showMessage(_responseMessage(response, 'Group updated.'));
      await _loadGroups();
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _decideJoinRequest(
    String groupId,
    String requestId,
    String decision,
  ) async {
    try {
      final response = await ApiService.patch(
        '/auto-groups/$groupId/join-requests/$requestId',
        requiresAuth: true,
        body: {'decision': decision},
      );
      if (!mounted) return;
      _showMessage(_responseMessage(response, 'Join request updated.'));
      await _loadGroups();
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : AppColors.secondary,
          behavior: SnackBarBehavior.fixed,
        ),
      );
  }

  void _showCreateGroupSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AutoGroupRequestSheet(
        title: 'Create a group listing',
        submitLabel: 'Publish listing',
        onSubmit: _createListing,
      ),
    );
  }

  void _showJoinRequestSheet(Map<String, dynamic> group) {
    final members = group['members'] as List<dynamic>? ?? [];
    Map<String, dynamic>? organizerRequest;
    for (final item in members) {
      if (item is Map<String, dynamic> &&
          item['request'] is Map<String, dynamic>) {
        organizerRequest = item['request'] as Map<String, dynamic>;
        break;
      }
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AutoGroupRequestSheet(
        title: 'Request to join',
        submitLabel: 'Send join request',
        initialCorridorId: group['corridorId']?.toString(),
        initialPickupHubId: organizerRequest?['pickupHubId']?.toString(),
        initialDestinationHubId: organizerRequest?['destinationHubId']
            ?.toString(),
        initialDepartureTime: DateTime.tryParse(
          group['departureTime']?.toString() ?? '',
        )?.toLocal(),
        onSubmit: (corridor, pickup, destination, time, _) => _requestToJoin(
          group['id'].toString(),
          corridor,
          pickup,
          destination,
          time,
          0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Groups'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Browse groups'),
            Tab(text: 'My groups'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGroupSheet,
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Create group'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGroupList(
            _browseGroups,
            emptyMessage: 'No open auto groups yet. Create one to get started.',
            marketplace: true,
          ),
          _buildGroupList(
            _myGroups,
            emptyMessage: 'You have not joined or created an auto group yet.',
            marketplace: false,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList(
    List<dynamic> groups, {
    required String emptyMessage,
    required bool marketplace,
  }) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.marginMobile),
              child: Column(
                children: [
                  Text(_loadError!, textAlign: TextAlign.center),
                  TextButton.icon(
                    onPressed: _loadGroups,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _loadGroups,
      child: groups.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 170),
                Center(child: Text(emptyMessage, textAlign: TextAlign.center)),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.marginMobile),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final group = groups[index] as Map<String, dynamic>;
                final groupId = group['id'].toString();
                final organizer = group['organizer'] as Map<String, dynamic>?;
                final isOrganizer = group['isOrganizer'] is bool
                    ? group['isOrganizer'] as bool
                    : organizer?['id']?.toString() ==
                          group['organizerId']?.toString();
                return _AutoGroupCard(
                  group: group,
                  marketplace: marketplace,
                  isOrganizer: isOrganizer,
                  onJoin: () => _showJoinRequestSheet(group),
                  onConfirm: () => _updateMembership(groupId, 'confirm'),
                  onLeave: () => _updateMembership(groupId, 'leave'),
                  onDecide: (requestId, decision) =>
                      _decideJoinRequest(groupId, requestId, decision),
                );
              },
            ),
    );
  }
}

class _AutoGroupCard extends StatelessWidget {
  const _AutoGroupCard({
    required this.group,
    required this.marketplace,
    required this.isOrganizer,
    required this.onJoin,
    required this.onConfirm,
    required this.onLeave,
    required this.onDecide,
  });

  final Map<String, dynamic> group;
  final bool marketplace;
  final bool isOrganizer;
  final VoidCallback onJoin;
  final VoidCallback onConfirm;
  final VoidCallback onLeave;
  final void Function(String requestId, String decision) onDecide;

  @override
  Widget build(BuildContext context) {
    final members = group['members'] as List<dynamic>? ?? [];
    final joinRequests = group['joinRequests'] as List<dynamic>? ?? [];
    final status = group['status']?.toString() ?? 'FORMING';
    final time = DateTime.tryParse(
      group['departureTime']?.toString() ?? '',
    )?.toLocal();
    final isReady = status == 'READY' || status == 'CONFIRMED';
    final corridor = group['corridor'] as Map<String, dynamic>?;
    final groupJoinRequests = marketplace ? joinRequests : const <dynamic>[];
    final myJoinRequest = group['myJoinRequest'] as Map<String, dynamic>?;
    final myJoinStatus = marketplace && joinRequests.isNotEmpty
        ? (joinRequests.first as Map<String, dynamic>)['status']?.toString()
        : myJoinRequest?['status']?.toString();
    final isMember = group['isMember'] == true || isOrganizer;
    final memberTrips = members
        .map((item) {
          if (item is! Map<String, dynamic>) return null;
          final request = item['request'] as Map<String, dynamic>?;
          if (request == null) return null;
          return '${request['pickupName']} → ${request['destinationName']}';
        })
        .whereType<String>()
        .join(' • ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_taxi_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    corridor?['name']?.toString() ?? 'Auto route group',
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(label: Text(status)),
              ],
            ),
            const SizedBox(height: 8),
            Text('${group['pickupName']} → ${group['destinationName']}'),
            const SizedBox(height: 6),
            Text(
              '${members.length}/${group['maxMembers']} students • '
              '${time == null ? 'Time not available' : MaterialLocalizations.of(context).formatFullDate(time)}'
              '${time == null ? '' : ' at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(time))}'}',
            ),
            if (group['organizer'] is Map<String, dynamic>) ...[
              const SizedBox(height: 6),
              Text(
                'Organized by ${(group['organizer'] as Map<String, dynamic>)['name'] ?? 'Student'}',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
            if (memberTrips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Member trips: $memberTrips'),
            ],
            const SizedBox(height: 8),
            Text(
              members
                  .map((item) {
                    if (item is! Map<String, dynamic>) return 'Student';
                    final user = item['user'] as Map<String, dynamic>?;
                    return user?['name']?.toString() ?? 'Student';
                  })
                  .join(', '),
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            if (marketplace) ...[
              if (myJoinStatus == 'PENDING')
                const Text('Your join request is waiting for the organizer.')
              else if (myJoinStatus == 'ACCEPTED')
                const Text('You are a member of this group.')
              else ...[
                if (myJoinStatus == 'DECLINED')
                  const Text('The organizer declined your previous request.'),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onJoin,
                    icon: const Icon(Icons.group_add_rounded),
                    label: const Text('Request to join'),
                  ),
                ),
              ],
            ] else if (!isMember) ...[
              if (myJoinStatus == 'PENDING')
                const Text('Your join request is waiting for the organizer.')
              else ...[
                if (myJoinStatus == 'DECLINED')
                  const Text('The organizer declined your previous request.'),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onJoin,
                    icon: const Icon(Icons.group_add_rounded),
                    label: const Text('Request again'),
                  ),
                ),
              ],
            ] else ...[
              if (isOrganizer && groupJoinRequests.isNotEmpty) ...[
                Text(
                  'Join requests (${groupJoinRequests.length})',
                  style: AppTypography.labelMd,
                ),
                const SizedBox(height: 8),
                ...groupJoinRequests.map((item) {
                  final request = item as Map<String, dynamic>;
                  final user = request['user'] as Map<String, dynamic>? ?? {};
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${user['name']?.toString() ?? 'Student'}\n'
                          '${request['pickupName']} → ${request['destinationName']}',
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            onDecide(request['id'].toString(), 'DECLINE'),
                        child: const Text('Decline'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            onDecide(request['id'].toString(), 'ACCEPT'),
                        child: const Text('Accept'),
                      ),
                    ],
                  );
                }),
              ],
              if (isReady)
                OutlinedButton(
                  onPressed: onConfirm,
                  child: const Text('Confirm attendance'),
                ),
              TextButton(
                onPressed: onLeave,
                child: Text(isOrganizer ? 'Cancel group' : 'Leave group'),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Fare is decided directly with the auto driver.',
              style: AppTypography.caption.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoGroupRequestSheet extends StatefulWidget {
  const _AutoGroupRequestSheet({
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    this.initialCorridorId,
    this.initialPickupHubId,
    this.initialDestinationHubId,
    this.initialDepartureTime,
  });

  final String title;
  final String submitLabel;
  final String? initialCorridorId;
  final String? initialPickupHubId;
  final String? initialDestinationHubId;
  final DateTime? initialDepartureTime;
  final Future<void> Function(
    CorridorModel corridor,
    HubModel pickup,
    HubModel destination,
    DateTime time,
    int maxMembers,
  )
  onSubmit;

  @override
  State<_AutoGroupRequestSheet> createState() => _AutoGroupRequestSheetState();
}

class _AutoGroupRequestSheetState extends State<_AutoGroupRequestSheet> {
  List<CorridorModel> _corridors = [];
  CorridorModel? _selectedCorridor;
  HubModel? _selectedPickup;
  HubModel? _selectedDestination;
  late DateTime _selectedTime;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;
  int _maxMembers = 4;

  @override
  void initState() {
    super.initState();
    _selectedTime =
        widget.initialDepartureTime ??
        DateTime.now().add(const Duration(minutes: 30));
    _loadCorridors();
  }

  HubModel? _hubById(List<HubModel> hubs, String? id) {
    for (final hub in hubs) {
      if (hub.id == id) return hub;
    }
    return null;
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
      final selected = corridors.where(
        (item) => item.id == widget.initialCorridorId,
      );
      final corridor = selected.isNotEmpty
          ? selected.first
          : (corridors.isEmpty ? null : corridors.first);
      final pickup = corridor == null
          ? null
          : _hubById(corridor.hubs, widget.initialPickupHubId) ??
                corridor.hubs.first;
      final destination = corridor == null
          ? null
          : _hubById(corridor.hubs, widget.initialDestinationHubId) ??
                corridor.hubs
                    .where((hub) => hub.sequence > pickup!.sequence)
                    .first;
      setState(() {
        _corridors = corridors;
        _selectedCorridor = corridor;
        _selectedPickup = pickup;
        _selectedDestination = destination;
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
    await widget.onSubmit(
      corridor,
      pickup,
      destination,
      _selectedTime,
      _maxMembers,
    );
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final corridor = _selectedCorridor;
    final pickup = _selectedPickup;
    final availablePickups =
        corridor?.hubs
            .where((hub) => hub.sequence < corridor.hubs.last.sequence)
            .toList() ??
        const <HubModel>[];
    final availableDestinations =
        corridor?.hubs
            .where((hub) => hub.sequence > (pickup?.sequence ?? -1))
            .toList() ??
        const <HubModel>[];

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
              widget.title,
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a route, stops, and departure time. Students can see your listing; the organizer approves each join request.',
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
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Route'),
                items: _corridors
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: widget.initialCorridorId != null
                    ? null
                    : (id) {
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
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Pickup stop'),
                items: availablePickups
                    .map(
                      (hub) => DropdownMenuItem(
                        value: hub.id,
                        child: Text(
                          hub.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  final selected = corridor!.hubs.firstWhere(
                    (hub) => hub.id == id,
                  );
                  setState(() {
                    _selectedPickup = selected;
                    if ((_selectedDestination?.sequence ?? -1) <=
                        selected.sequence) {
                      _selectedDestination = corridor.hubs.firstWhere(
                        (hub) => hub.sequence > selected.sequence,
                      );
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedDestination?.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Drop-off stop'),
                items: availableDestinations
                    .map(
                      (hub) => DropdownMenuItem(
                        value: hub.id,
                        child: Text(
                          hub.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) => setState(() {
                  _selectedDestination = corridor!.hubs.firstWhere(
                    (hub) => hub.id == id,
                  );
                }),
              ),
              if (widget.initialCorridorId == null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _maxMembers,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Group size'),
                  items: const [3, 4]
                      .map(
                        (count) => DropdownMenuItem(
                          value: count,
                          child: Text('$count students'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _maxMembers = value ?? 4),
                ),
              ],
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
                    _isSubmitting ? 'Please wait...' : widget.submitLabel,
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
