import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/routing/routes.dart';
import '../../core/network/http_client.dart';
import '../../core/config/api_endpoints.dart';
import '../../core/storage/secure_storage.dart';
import '../../shared/widgets/avatar_slot.dart';
import '../../shared/widgets/labled_row.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/vitamate_app_bar.dart';
import '../../shared/utils/validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);

    try {
      final res = await HttpClient.dio.post(
        ApiEndpoints.login,
        data: {
          'username': _usernameCtrl.text.trim(),
          'password': _passwordCtrl.text,
        },
      );

      final data = res.data;
      if (data is! Map) throw Exception('Invalid login response');

      final access = data['access']?.toString() ?? '';
      final refresh = data['refresh']?.toString() ?? '';

      if (access.isEmpty || refresh.isEmpty) {
        throw Exception('Missing access/refresh token');
      }

      await SecureStorage.saveTokens(access: access, refresh: refresh);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, Routes.home);
    } on DioException catch (e) {
      String message = 'Login failed. Please check your credentials.';

      if (e.response?.statusCode == 401) {
        message = 'Invalid username or password.';
      } else if (e.response?.data is Map) {
        final m = e.response!.data as Map;
        final firstValue = m.values.isNotEmpty ? m.values.first : null;
        if (firstValue is List && firstValue.isNotEmpty) {
          message = firstValue.first.toString();
        } else if (firstValue != null) {
          message = firstValue.toString();
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const VitaMateAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Text(
                  'Begin your journey to better health\nwith your smart health assistant.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),
                const AvatarSlot(size: 110),
                const SizedBox(height: 26),

                LabeledRow(
                  label: 'Username',
                  child: TextFormField(
                    controller: _usernameCtrl,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Username is required';
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 14),

                LabeledRow(
                  label: 'Password',
                  child: TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    validator: Validators.password,
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                PrimaryButton(
                  text: _loading ? 'Logging in...' : 'Login',
                  onPressed: _loading ? null : _submit,
                ),

                const SizedBox(height: 14),

                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, Routes.signup),
                  child: const Text(
                    "Don't have an account? Sign up",
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
