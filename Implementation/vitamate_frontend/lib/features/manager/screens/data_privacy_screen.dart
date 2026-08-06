import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../state/privacy_controller.dart';
import '../widgets/manager_section_tile.dart';
import '../widgets/permission_state_tile.dart';

class DataPrivacyScreen extends StatefulWidget {
  const DataPrivacyScreen({super.key});

  @override
  State<DataPrivacyScreen> createState() => _DataPrivacyScreenState();
}

class _DataPrivacyScreenState extends State<DataPrivacyScreen> {
  late final PrivacyController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PrivacyController()..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VitaMateTheme.shellBackground,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final privacy = _controller.privacy;
            if (_controller.isLoading && privacy == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  sliver: SliverList.list(
                    children: [
                      const _TopBar(),
                      const SizedBox(height: 18),
                      _PermissionsCard(
                        permissions: privacy?.permissions ?? const {},
                      ),
                      const SizedBox(height: 14),
                      ManagerSectionTile(
                        icon: Icons.file_download_outlined,
                        title: 'Export data',
                        subtitle: _exportSubtitle(privacy?.latestExport),
                        onTap: _requestExport,
                      ),
                      const SizedBox(height: 18),
                      _DeletionCard(
                        requested: privacy?.accountDeletion != null,
                        isSaving: _controller.isSaving,
                        onRequest: _requestDeletion,
                        onCancel: _cancelDeletion,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _exportSubtitle(Map<String, dynamic>? latestExport) {
    if (latestExport == null) {
      return 'Create a portable snapshot of your account data.';
    }
    return 'Latest export status: ${latestExport['status'] ?? 'ready'}.';
  }

  Future<void> _requestExport() async {
    final ok = await _controller.requestExport();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Export request is ready.'
              : _controller.error ?? 'Export failed.',
        ),
      ),
    );
  }

  Future<void> _requestDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request account deletion?'),
        content: const Text(
          'This creates a deletion request with a grace period. It does not immediately erase the account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Request'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _controller.requestDeletion();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Deletion request created.'
              : _controller.error ?? 'Deletion request failed.',
        ),
      ),
    );
  }

  Future<void> _cancelDeletion() async {
    final ok = await _controller.cancelDeletion();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Deletion request cancelled.'
              : _controller.error ?? 'Cancel failed.',
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        const Expanded(
          child: Text(
            'Data & Privacy',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({required this.permissions});

  final Map<String, dynamic> permissions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: VitaMateTheme.border),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Permissions',
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          PermissionStateTile(
            title: 'Notifications',
            subtitle: 'Used for reminders and health alerts.',
            enabled: permissions['notifications'] == true,
            icon: Icons.notifications_active_outlined,
          ),
          const SizedBox(height: 10),
          PermissionStateTile(
            title: 'Activity sensor',
            subtitle: 'Used for automatic steps.',
            enabled: permissions['activity_sensor'] == true,
            icon: Icons.directions_walk_rounded,
          ),
          const SizedBox(height: 10),
          PermissionStateTile(
            title: 'Local storage',
            subtitle: 'Used for secure session and local reminders.',
            enabled: permissions['local_storage'] == true,
            icon: Icons.storage_rounded,
          ),
        ],
      ),
    );
  }
}

class _DeletionCard extends StatelessWidget {
  const _DeletionCard({
    required this.requested,
    required this.isSaving,
    required this.onRequest,
    required this.onCancel,
  });

  final bool requested;
  final bool isSaving;
  final VoidCallback onRequest;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VitaMateTheme.danger.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: VitaMateTheme.danger.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Request account deletion',
            style: TextStyle(
              color: VitaMateTheme.danger,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            requested
                ? 'A deletion request is active. You can cancel it during the grace period.'
                : 'Start a controlled account deletion request.',
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isSaving ? null : (requested ? onCancel : onRequest),
              style: FilledButton.styleFrom(
                backgroundColor: requested
                    ? VitaMateTheme.primary
                    : VitaMateTheme.danger,
              ),
              child: Text(
                isSaving
                    ? 'Working...'
                    : requested
                    ? 'Cancel deletion request'
                    : 'Request account deletion',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
