import 'package:flutter/material.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../models/manager_models.dart';

class PersonalHeaderCard extends StatelessWidget {
  const PersonalHeaderCard({
    super.key,
    required this.user,
    required this.profile,
    required this.onEdit,
  });

  final ManagerUser user;
  final ManagerHealthProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF2EAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: VitaMateTheme.border),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          _HeaderAvatar(user: user),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.email.isEmpty ? user.username : user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniBadge(
                      icon: Icons.monitor_weight_outlined,
                      label: '${profile.weight.toStringAsFixed(0)} kg',
                    ),
                    _MiniBadge(
                      icon: Icons.straighten_rounded,
                      label: '${profile.height.toStringAsFixed(0)} cm',
                    ),
                    _MiniBadge(
                      icon: Icons.flag_outlined,
                      label: _goalLabel(profile.goal),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
            style: IconButton.styleFrom(
              backgroundColor: VitaMateTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  static String _goalLabel(String goal) {
    switch (goal) {
      case 'lose':
        return 'Lose';
      case 'gain':
        return 'Gain';
      case 'muscle':
        return 'Muscle';
      default:
        return 'Maintain';
    }
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({required this.user});

  final ManagerUser user;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _resolveAvatarUrl(user.avatarUrl);
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF8D68FF), Color(0xFF5D2DE1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: resolvedUrl == null
          ? _HeaderInitials(initials: user.initials)
          : Image.network(
              resolvedUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _HeaderInitials(initials: user.initials),
            ),
    );
  }

  static String? _resolveAvatarUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '${ApiEndpoints.baseUrl}$trimmed';
    }
    return trimmed;
  }
}

class _HeaderInitials extends StatelessWidget {
  const _HeaderInitials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 23,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: VitaMateTheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
