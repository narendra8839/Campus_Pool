import 'package:flutter/material.dart';
import '../../components/cards/app_card.dart';
import '../../models/alert_model.dart';
import '../../services/alert_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../navigation/main_navigation_shell.dart';

/// In-app activity feed for booking and ride updates.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late Future<List<AlertModel>> _activity;
  final Set<String> _readIds = <String>{};

  @override
  void initState() {
    super.initState();
    _activity = AlertService.loadActivity();
  }

  Future<void> _refresh() async {
    setState(() => _activity = AlertService.loadActivity());
    await _activity;
  }

  void _markAllRead(List<AlertModel> alerts) {
    setState(() => _readIds.addAll(alerts.map((alert) => alert.id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Activity', style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.w700)),
        actions: [
          FutureBuilder<List<AlertModel>>(
            future: _activity,
            builder: (context, snapshot) {
              final alerts = snapshot.data ?? const <AlertModel>[];
              final hasUnread = alerts.any((alert) => !_readIds.contains(alert.id));
              return TextButton(
                onPressed: hasUnread ? () => _markAllRead(alerts) : null,
                child: const Text('Mark all read'),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<AlertModel>>(
        future: _activity,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _errorState();
          final alerts = snapshot.data ?? const <AlertModel>[];
          if (alerts.isEmpty) return _emptyState();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.sm, AppSpacing.marginMobile, AppSpacing.xl),
              itemCount: alerts.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final unread = alerts.where((alert) => !_readIds.contains(alert.id)).length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(unread == 0 ? 'You’re all caught up' : '$unread unread update${unread == 1 ? '' : 's'}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                  );
                }
                final alert = alerts[index - 1];
                return _alertCard(alert, _readIds.contains(alert.id));
              },
            ),
          );
        },
      ),
    );
  }

  Widget _alertCard(AlertModel alert, bool isRead) {
    final (icon, color) = switch (alert.priority) {
      AlertPriority.success => (Icons.check_circle_rounded, AppColors.secondary),
      AlertPriority.warning => (Icons.info_rounded, AppColors.tertiary),
      AlertPriority.urgent => (Icons.priority_high_rounded, AppColors.error),
      AlertPriority.info => (Icons.notifications_rounded, AppColors.primary),
    };
    return AppCard(
      backgroundColor: isRead ? AppColors.surface : AppColors.primaryTint,
      onTap: () {
        setState(() => _readIds.add(alert.id));
        MainNavigationShell.switchTab(context, 1);
      },
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(alert.title, style: AppTypography.labelMd.copyWith(fontWeight: isRead ? FontWeight.w600 : FontWeight.w800))), if (!isRead) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle))]),
          const SizedBox(height: 3),
          Text(alert.message, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(_relativeTime(alert.createdAt), style: AppTypography.caption.copyWith(color: AppColors.onSurfaceVariant)),
        ])),
      ]),
    );
  }

  Widget _emptyState() => Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.notifications_none_rounded, size: 56, color: AppColors.onSurfaceVariant), const SizedBox(height: AppSpacing.md), Text('No activity yet', style: AppTypography.headlineSm), const SizedBox(height: AppSpacing.xs), Text('Booking requests and ride updates will appear here.', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant), textAlign: TextAlign.center)])));

  Widget _errorState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.error), const SizedBox(height: AppSpacing.sm), Text('Could not load activity', style: AppTypography.headlineSm), TextButton(onPressed: _refresh, child: const Text('Try again'))]));

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
