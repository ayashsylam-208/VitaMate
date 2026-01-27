import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/routing/routes.dart';
import '../../core/network/http_client.dart';
import '../../core/config/api_endpoints.dart';
import '../../core/storage/secure_storage.dart';
import '../../shared/utils/validators.dart';
import '../../shared/widgets/avatar_slot.dart';
import '../../shared/widgets/labled_row.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/vitamate_app_bar.dart';
import '../../core/notifications/notifications_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _usernameValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Username is required';
    if (value.length < 3) return 'Username must be at least 3 characters';
    final ok = RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value);
    if (!ok) return 'Only letters, numbers, and underscore are allowed';
    return null;
  }

  String? _nameValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Full name is required';
    if (value.length < 2) return 'Name is too short';
    return null;
  }

  String? _confirmPasswordValidator(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Confirm password is required';
    if (value != _passwordCtrl.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final username = _usernameCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;

      final fullName = _nameCtrl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      final parts = fullName.split(' ');
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      await HttpClient.dio.post(
        ApiEndpoints.register,
        data: {
          'username': username,
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
        },
      );

      final loginRes = await HttpClient.dio.post(
        ApiEndpoints.login,
        data: {'username': username, 'password': password},
      );

      final data = loginRes.data;
      if (data is! Map) throw Exception('Invalid login response');

      final access = data['access']?.toString() ?? '';
      final refresh = data['refresh']?.toString() ?? '';
      if (access.isEmpty || refresh.isEmpty) {
        throw Exception('Missing access/refresh');
      }

      await SecureStorage.saveTokens(access: access, refresh: refresh);

      if (!mounted) return;
      await NotificationsService.showWelcomeNewUser();
      Navigator.pushReplacementNamed(context, Routes.onboarding);
    } on DioException catch (e) {
      String message = 'Registration failed. Please try again.';

      final data = e.response?.data;
      if (data is Map) {
        final firstValue = data.values.isNotEmpty ? data.values.first : null;
        if (firstValue is List && firstValue.isNotEmpty) {
          message = firstValue.first.toString();
        } else if (firstValue != null) {
          message = firstValue.toString();
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const VitaMateAppBar(),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 6),
                const Text(
                  'Your journey toward a healthier lifestyle starts here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                const AvatarSlot(size: 120),
                const SizedBox(height: 22),

                LabeledRow(
                  label: 'Username',
                  child: TextFormField(
                    controller: _usernameCtrl,
                    textInputAction: TextInputAction.next,
                    validator: _usernameValidator,
                  ),
                ),
                const SizedBox(height: 14),

                LabeledRow(
                  label: 'Full name',
                  child: TextFormField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    validator: _nameValidator,
                  ),
                ),
                const SizedBox(height: 14),

                LabeledRow(
                  label: 'Email address',
                  child: TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: Validators.email,
                  ),
                ),
                const SizedBox(height: 14),

                LabeledRow(
                  label: 'Password',
                  child: TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure1,
                    textInputAction: TextInputAction.next,
                    validator: Validators.password,
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure1 = !_obscure1),
                        icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                LabeledRow(
                  label: 'Confirm',
                  child: TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscure2,
                    textInputAction: TextInputAction.done,
                    validator: _confirmPasswordValidator,
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure2 = !_obscure2),
                        icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                PrimaryButton(
                  text: _loading ? 'Creating...' : 'Create account',
                  onPressed: _loading ? null : _submit,
                ),

                const SizedBox(height: 14),

                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Already have an account? Login',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
