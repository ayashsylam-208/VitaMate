import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../core/notification_hub/notification_hub.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../../motivation/state/motivation_experience_controller.dart';
import '../models/manager_models.dart';
import '../state/account_security_controller.dart';
import '../widgets/manager_section_tile.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  late final AccountSecurityController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AccountSecurityController()..load();
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
            final security = _controller.security;
            if (_controller.isLoading && security == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (security == null) {
              return _FailureState(
                message: _controller.error ?? 'Security settings unavailable.',
                onRetry: _controller.load,
              );
            }
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  sliver: SliverList.list(
                    children: [
                      const _TopBar(),
                      const SizedBox(height: 18),
                      ManagerSectionTile(
                        icon: Icons.password_rounded,
                        title: 'Change password',
                        subtitle: 'Use your current password to set a new one.',
                        onTap: _changePassword,
                      ),
                      const SizedBox(height: 12),
                      ManagerSectionTile(
                        icon: security.emailVerified
                            ? Icons.verified_rounded
                            : Icons.mark_email_unread_outlined,
                        title: 'Email',
                        subtitle: security.emailVerified
                            ? '${security.email} is verified.'
                            : security.pendingEmail.isEmpty
                            ? '${security.email} is not verified.'
                            : '${security.pendingEmail} is pending verification.',
                        trailing: _StatusBadge(
                          label: security.emailVerified
                              ? 'Verified'
                              : 'Pending',
                          good: security.emailVerified,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DevicesCard(devices: security.devices),
                      const SizedBox(height: 22),
                      const Text(
                        'Actions',
                        style: TextStyle(
                          color: VitaMateTheme.primaryDeep,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ManagerSectionTile(
                        icon: Icons.logout_rounded,
                        title: 'Log out from this device',
                        subtitle:
                            'Clears local tokens on this phone. Server token blacklist is not enabled.',
                        isDanger: true,
                        onTap: _logoutAll,
                      ),
                      const SizedBox(height: 12),
                      ManagerSectionTile(
                        icon: Icons.delete_outline_rounded,
                        title: 'Delete account',
                        subtitle:
                            'Request account deletion from privacy controls.',
                        isDanger: true,
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.managerPrivacy),
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

  Future<void> _logoutAll() async {
    final ok = await _controller.logoutAll();
    if (!mounted) return;
    if (!ok) {
      appScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(_controller.error ?? 'Logout failed.')),
      );
      return;
    }
    MotivationExperienceController.instance.resetPresentation();
    await AuthRepository(AuthApi()).logout();
    await NotificationHubController.instance.clearLocalState();
    appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      Routes.login,
      (_) => false,
    );
  }

  Future<void> _changePassword() async {
    final changed = await _showPasswordDialog();
    if (changed != true || !mounted) return;
    appScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    MotivationExperienceController.instance.resetPresentation();
    await AuthRepository(AuthApi()).logout();
    await NotificationHubController.instance.clearLocalState();
    appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      Routes.login,
      (_) => false,
    );
  }

  Future<bool?> _showPasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    var showCurrent = false;
    var showNext = false;
    var showConfirm = false;
    var submitting = false;
    String? dialogError;
    try {
      return await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change password'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PasswordField(
                        controller: current,
                        label: 'Current password',
                        visible: showCurrent,
                        onToggle: () =>
                            setDialogState(() => showCurrent = !showCurrent),
                        validator: (value) => (value?.isEmpty ?? true)
                            ? 'Current password is required.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _PasswordField(
                        controller: next,
                        label: 'New password',
                        visible: showNext,
                        onToggle: () =>
                            setDialogState(() => showNext = !showNext),
                        validator: (value) {
                          final text = value ?? '';
                          if (text.length < 8) {
                            return 'Use at least 8 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _PasswordField(
                        controller: confirm,
                        label: 'Confirm new password',
                        visible: showConfirm,
                        onToggle: () =>
                            setDialogState(() => showConfirm = !showConfirm),
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'Confirm the new password.';
                          }
                          if (value != next.text) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 12),
                        _DialogError(message: dialogError!),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (formKey.currentState?.validate() != true) return;
                          setDialogState(() {
                            submitting = true;
                            dialogError = null;
                          });
                          final ok = await _controller.changePassword(
                            currentPassword: current.text,
                            newPassword: next.text,
                            newPasswordConfirm: confirm.text,
                          );
                          if (!context.mounted) return;
                          if (ok) {
                            Navigator.pop(context, true);
                            return;
                          }
                          setDialogState(() {
                            submitting = false;
                            dialogError =
                                _controller.error ?? 'Password change failed.';
                          });
                        },
                  child: Text(submitting ? 'Checking...' : 'Change'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      current.dispose();
      next.dispose();
      confirm.dispose();
    }
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
            'Account & Security',
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

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({required this.devices});

  final List<ManagerDevice> devices;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Devices',
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (devices.isEmpty)
            const Text(
              'No registered notification devices yet.',
              style: TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            for (final device in devices) ...[
              Row(
                children: [
                  Icon(
                    device.platform == 'android'
                        ? Icons.android_rounded
                        : Icons.devices_rounded,
                    color: VitaMateTheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${device.platform} ${device.appVersion}'.trim(),
                      style: const TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (device.isPrimary)
                    const _StatusBadge(label: 'Primary', good: true),
                ],
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.good});

  final String label;
  final bool good;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (good ? VitaMateTheme.success : VitaMateTheme.warning)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: good ? VitaMateTheme.success : VitaMateTheme.warning,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.visible,
    required this.onToggle,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool visible;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      enableSuggestions: false,
      autocorrect: false,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
        ),
      ),
    );
  }
}

class _DialogError extends StatelessWidget {
  const _DialogError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VitaMateTheme.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VitaMateTheme.danger.withValues(alpha: 0.22)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: VitaMateTheme.danger,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
