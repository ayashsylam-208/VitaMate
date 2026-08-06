import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../core/notification_hub/notification_hub.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../models/manager_models.dart';
import '../state/manager_overview_controller.dart';
import '../../motivation/state/motivation_experience_controller.dart';
import '../widgets/manager_section_tile.dart';
import '../widgets/motivation_summary_card.dart';
import '../widgets/my_day_card.dart';
import '../widgets/personal_header_card.dart';
import '../widgets/quick_management_grid.dart';

class MyVitaMateScreen extends StatefulWidget {
  const MyVitaMateScreen({super.key});

  @override
  State<MyVitaMateScreen> createState() => _MyVitaMateScreenState();
}

class _MyVitaMateScreenState extends State<MyVitaMateScreen> {
  late final ManagerOverviewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ManagerOverviewController()..load();
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
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: 4),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (_controller.isLoading && _controller.overview == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final overview = _controller.overview;
            if (overview == null) {
              return _ErrorState(
                message: _controller.error ?? 'My VitaMate is unavailable.',
                onRetry: _controller.load,
              );
            }
            return RefreshIndicator(
              onRefresh: _controller.load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    sliver: SliverList.list(
                      children: [
                        _TopBar(
                          unreadCount:
                              overview.myDay.totalGoals -
                              overview.myDay.completedGoals,
                          onNotifications: () => Navigator.pushNamed(
                            context,
                            Routes.managerNotifications,
                          ),
                        ),
                        const SizedBox(height: 18),
                        PersonalHeaderCard(
                          user: overview.user,
                          profile: overview.profile,
                          onEdit: () async {
                            final changed = await Navigator.pushNamed(
                              context,
                              Routes.managerEditProfile,
                            );
                            if (changed == true) {
                              await _controller.load();
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        MyDayCard(
                          day: overview.myDay,
                          onFocusTap: () =>
                              _openRoute(context, overview.myDay.focus.route),
                        ),
                        const SizedBox(height: 14),
                        MotivationSummaryCard(motivation: overview.motivation),
                        const SizedBox(height: 24),
                        const _SectionTitle('Quick management'),
                        const SizedBox(height: 12),
                        QuickManagementGrid(actions: overview.quickActions),
                        const SizedBox(height: 24),
                        _ManagementRows(overview: overview),
                        const SizedBox(height: 14),
                        ManagerSectionTile(
                          icon: Icons.logout_rounded,
                          title: 'Log out',
                          subtitle: 'Clear this device session.',
                          isDanger: true,
                          onTap: _logout,
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: VitaMateTheme.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openRoute(BuildContext context, String route) {
    if (route.trim().isEmpty) return;
    Navigator.pushNamed(context, route);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('This clears your local session on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    MotivationExperienceController.instance.resetPresentation();
    await AuthRepository(AuthApi()).logout();
    await NotificationHubController.instance.clearLocalState();
    appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      Routes.login,
      (_) => false,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.unreadCount, required this.onNotifications});

  final int unreadCount;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final count = unreadCount.clamp(0, 9);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My VitaMate',
                style: TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Manage your health, goals & account in one place.',
                style: TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton.filledTonal(
              onPressed: onNotifications,
              icon: const Icon(Icons.notifications_none_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: VitaMateTheme.primaryDeep,
                fixedSize: const Size(48, 48),
              ),
            ),
            if (count > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: VitaMateTheme.danger,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ManagementRows extends StatelessWidget {
  const _ManagementRows({required this.overview});

  final ManagerOverview overview;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ManagerSectionTile(
          icon: Icons.lock_outline_rounded,
          title: 'Account & Security',
          subtitle:
              '${overview.notifications.activeDevices} primary device, email ${overview.user.emailVerified ? 'verified' : 'not verified'}',
          onTap: () => Navigator.pushNamed(context, Routes.managerSecurity),
        ),
        const SizedBox(height: 12),
        ManagerSectionTile(
          icon: Icons.medical_information_outlined,
          title: 'Medical Data',
          subtitle:
              '${overview.medical.activeMedications} medications, ${overview.medical.activeConditions} conditions',
          onTap: () => Navigator.pushNamed(context, Routes.managerMedicalData),
        ),
        const SizedBox(height: 12),
        ManagerSectionTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Data & Privacy',
          subtitle: overview.privacy.accountDeletion == null
              ? 'Permissions, export and deletion controls.'
              : 'Account deletion request is active.',
          onTap: () => Navigator.pushNamed(context, Routes.managerPrivacy),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: VitaMateTheme.primaryDeep,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: VitaMateTheme.danger,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
