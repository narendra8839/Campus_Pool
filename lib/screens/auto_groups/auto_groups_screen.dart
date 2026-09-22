import 'package:flutter/material.dart';

import '../../services/api_service.dart';
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

  Future<void> _createRequest(String pickup, String destination, DateTime time) async {
    try {
      final response = await ApiService.post(
        '/auto-groups/requests',
        requiresAuth: true,
        body: {
          'pickupName': pickup,
          'destinationName': destination,
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
    final formKey = GlobalKey<FormState>();
    final pickup = TextEditingController();
    final destination = TextEditingController();
    DateTime selectedTime = DateTime.now().add(const Duration(minutes: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Find an auto group', style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('We only coordinate students with similar routes. Fare is decided with the auto driver.', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 16),
              TextFormField(
                controller: pickup,
                decoration: const InputDecoration(labelText: 'Pickup area', hintText: 'e.g. Viman Nagar'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter your pickup area' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: destination,
                decoration: const InputDecoration(labelText: 'Destination', hintText: 'e.g. College Main Gate'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter your destination' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded, color: AppColors.primary),
                title: const Text('Desired departure'),
                subtitle: Text('${MaterialLocalizations.of(context).formatFullDate(selectedTime)}  ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(selectedTime))}'),
                onTap: () async {
                  final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)), initialDate: selectedTime);
                  if (date == null || !context.mounted) return;
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedTime));
                  if (time != null) setSheetState(() => selectedTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () { if (formKey.currentState!.validate()) _createRequest(pickup.text.trim(), destination.text.trim(), selectedTime); },
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Text('Create request'),
                ),
              ),
            ]),
          ),
        ),
      ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.local_taxi_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('${group['pickupName']} → ${group['destinationName']}', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700))),
            Chip(label: Text(status)),
          ]),
          const SizedBox(height: 8),
          Text('${members.length}/${group['maxMembers']} students • ${time == null ? 'Time not available' : MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(time))}'),
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
