import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/models/user.dart';
import '../../../core/config/api_endpoints.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../state/edit_profile_controller.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final EditProfileController _controller;
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _imagePicker = ImagePicker();
  String _language = 'English';
  String _region = 'Romania';
  bool _filled = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _controller = EditProfileController()..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
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
            final user = _controller.user;
            if (_controller.isLoading && user == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (user == null) {
              return _FailureState(
                message: _controller.error ?? 'Profile is unavailable.',
                onRetry: _controller.load,
              );
            }
            _fillOnce(user);
            return Form(
              key: _formKey,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    sliver: SliverList.list(
                      children: [
                        _EditTopBar(onBack: _close, onSave: _save),
                        const SizedBox(height: 18),
                        _AvatarBlock(
                          initials: _initials(user),
                          avatarUrl: user.profile.avatarUrl,
                          isSaving: _controller.isAvatarSaving,
                          onPick: _pickAvatar,
                          onDelete: user.profile.avatarUrl.isEmpty
                              ? null
                              : _deleteAvatar,
                        ),
                        const SizedBox(height: 26),
                        _Label('First name'),
                        _Input(controller: _firstName),
                        const SizedBox(height: 16),
                        _Label('Last name'),
                        _Input(controller: _lastName),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const _Label('Email'),
                            const Spacer(),
                            _VerifiedBadge(
                              verified: user.profile.emailVerified,
                            ),
                          ],
                        ),
                        _Input(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty || !text.contains('@')) {
                              return 'Enter a valid email.';
                            }
                            return null;
                          },
                        ),
                        if (user.profile.pendingEmail.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Pending verification: ${user.profile.pendingEmail}',
                            style: const TextStyle(
                              color: VitaMateTheme.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const _Label('Username'),
                        TextFormField(
                          initialValue: user.username,
                          readOnly: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                            suffixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 20),
                        _DropdownField(
                          label: 'Language',
                          value: _language,
                          items: const ['English', 'Arabic', 'Romanian'],
                          onChanged: (value) =>
                              setState(() => _language = value),
                        ),
                        const SizedBox(height: 16),
                        _DropdownField(
                          label: 'Region',
                          value: _region,
                          items: const ['Romania', 'Syria', 'United States'],
                          onChanged: (value) => setState(() => _region = value),
                        ),
                        const SizedBox(height: 30),
                        FilledButton(
                          onPressed: _controller.isSaving ? null : _save,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(58),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            _controller.isSaving ? 'Saving...' : 'Save changes',
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

  void _fillOnce(AuthUser user) {
    if (_filled) return;
    _firstName.text = user.firstName;
    _lastName.text = user.lastName;
    _email.text = user.email;
    _language = user.profile.preferredLanguage;
    _region = user.profile.region;
    _filled = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await _controller.save(<String, dynamic>{
      'first_name': _firstName.text.trim(),
      'last_name': _lastName.text.trim(),
      'email': _email.text.trim(),
      'preferred_language': _language,
      'region': _region,
    });
    if (!mounted) return;
    final updated = _controller.user;
    final savedMessage = updated?.profile.pendingEmail.isNotEmpty == true
        ? 'Profile saved. Email is pending verification.'
        : 'Profile saved.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? savedMessage : _controller.error ?? 'Profile update failed.',
        ),
      ),
    );
    if (ok) {
      _changed = true;
      Navigator.pop(context, true);
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    final ok = await _controller.uploadAvatar(picked.path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Profile photo updated.' : _controller.error ?? 'Upload failed.',
        ),
      ),
    );
    if (ok) _changed = true;
  }

  Future<void> _deleteAvatar() async {
    final ok = await _controller.deleteAvatar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Profile photo removed.'
              : _controller.error ?? 'Photo removal failed.',
        ),
      ),
    );
    if (ok) _changed = true;
  }

  void _close() {
    Navigator.pop(context, _changed);
  }

  String _initials(AuthUser user) {
    final first = user.firstName.isNotEmpty ? user.firstName[0] : '';
    final last = user.lastName.isNotEmpty ? user.lastName[0] : '';
    final value = '$first$last'.trim();
    return value.isEmpty ? user.username.characters.first.toUpperCase() : value;
  }
}

class _EditTopBar extends StatelessWidget {
  const _EditTopBar({required this.onBack, required this.onSave});

  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        const Expanded(
          child: Text(
            'Edit profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(onPressed: onSave, child: const Text('Save')),
      ],
    );
  }
}

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({
    required this.initials,
    required this.avatarUrl,
    required this.isSaving,
    required this.onPick,
    required this.onDelete,
  });

  final String initials;
  final String avatarUrl;
  final bool isSaving;
  final VoidCallback onPick;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _AvatarCircle(initials: initials, avatarUrl: avatarUrl),
              Positioned(
                right: 0,
                bottom: 2,
                child: InkWell(
                  onTap: isSaving ? null : onPick,
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: VitaMateTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: isSaving
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                  ),
                ),
              ),
            ],
          ),
          if (onDelete != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: isSaving ? null : onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Remove photo'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.initials, required this.avatarUrl});

  final String initials;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _resolveAvatarUrl(avatarUrl);
    return Container(
      width: 112,
      height: 112,
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
          ? _Initials(initials: initials)
          : Image.network(
              resolvedUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _Initials(initials: initials),
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

class _Initials extends StatelessWidget {
  const _Initials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({required this.controller, this.validator, this.keyboardType});

  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: const InputDecoration(),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: VitaMateTheme.primaryDeep,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (verified ? VitaMateTheme.success : VitaMateTheme.warning)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        verified ? 'Verified' : 'Pending',
        style: TextStyle(
          color: verified ? VitaMateTheme.success : VitaMateTheme.warning,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value) ? value : items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        DropdownButtonFormField<String>(
          initialValue: safeValue,
          items: [
            for (final item in items)
              DropdownMenuItem(value: item, child: Text(item)),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          decoration: const InputDecoration(),
        ),
      ],
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
