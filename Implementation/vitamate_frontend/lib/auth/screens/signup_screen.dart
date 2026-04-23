import 'package:flutter/material.dart';

import '../../core/notifications/notifications_service.dart';
import '../../core/routing/routes.dart';
import '../../shared/utils/validators.dart';
import '../state/auth_controller.dart';

const _pageBackground = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF5F0FF), Color(0xFFFFFDFF), Color(0xFFF2F0FF)],
);

const _shellBackground = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF4EEFF), Color(0xFFFFFDFF)],
);

const _buttonGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFF8D4BEE), Color(0xFFA217F4)],
);

const _deepPurple = Color(0xFF42118B);
const _midPurple = Color(0xFF8A33FF);
const _hintPurple = Color(0xFFB06AFF);
const _strokePurple = Color(0xFFE7D5FF);

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authController = AuthController();

  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _authController.dispose();
    super.dispose();
  }

  String? _usernameValidator(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Username is required';
    if (trimmed.length < 3) return 'Username must be at least 3 characters';
    final ok = RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed);
    if (!ok) return 'Only letters, numbers, and underscore are allowed';
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    final input = value ?? '';
    if (input.isEmpty) return 'Confirm password is required';
    if (input != _passwordCtrl.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final username = _usernameCtrl.text.trim();
      final password = _passwordCtrl.text;

      final registered = await _authController.register(
        username: username,
        password: password,
        email: _emailCtrl.text.trim(),
        firstName: username,
        lastName: '',
      );
      if (!mounted) return;
      if (!registered) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _authController.error ?? 'Registration failed. Please try again.',
            ),
          ),
        );
        return;
      }

      final loggedIn = await _authController.login(username, password);
      if (!mounted) return;
      if (!loggedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _authController.error ?? 'Account created, but login failed.',
            ),
          ),
        );
        return;
      }

      try {
        await NotificationsService.showWelcomeNewUser();
      } catch (error) {
        debugPrint('SignUpScreen: welcome notification failed: $error');
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, Routes.onboarding);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: _hintPurple,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(icon, color: _hintPurple, size: 22),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: _strokePurple),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: _midPurple, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE35D7A)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE35D7A), width: 1.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(gradient: _pageBackground),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 760;
              final isVeryCompact = constraints.maxHeight < 680;
              final bottomInset = MediaQuery.of(context).viewInsets.bottom;

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(10, 6, 10, 12 + bottomInset),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _shellBackground,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.88),
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A57369A),
                            blurRadius: 32,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          22,
                          isVeryCompact
                              ? 18
                              : isCompact
                              ? 28
                              : 40,
                          22,
                          isVeryCompact
                              ? 18
                              : isCompact
                              ? 26
                              : 36,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: isVeryCompact
                                    ? 4
                                    : isCompact
                                    ? 10
                                    : 22,
                              ),
                              Center(
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: isVeryCompact
                                      ? 56
                                      : isCompact
                                      ? 72
                                      : 84,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                        Icons.health_and_safety_rounded,
                                        color: _deepPurple,
                                        size: isVeryCompact
                                            ? 48
                                            : isCompact
                                            ? 60
                                            : 72,
                                      ),
                                ),
                              ),
                              SizedBox(height: isVeryCompact ? 18 : 28),
                              Text(
                                'Create Account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _deepPurple,
                                  fontSize: isVeryCompact ? 22 : 24,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                              SizedBox(height: isVeryCompact ? 8 : 10),
                              Text(
                                'Start your health journey with VitaMate.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _midPurple,
                                  fontSize: isVeryCompact ? 14 : 16,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                              SizedBox(height: isVeryCompact ? 18 : 28),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.84),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.65),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x1A57369A),
                                      blurRadius: 28,
                                      offset: Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    20,
                                    isVeryCompact ? 16 : 20,
                                    20,
                                    isVeryCompact ? 16 : 20,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Text(
                                        'Username',
                                        style: TextStyle(
                                          color: _deepPurple,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _usernameCtrl,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.newUsername,
                                        ],
                                        validator: _usernameValidator,
                                        decoration: _fieldDecoration(
                                          hintText: 'Enter username',
                                          icon: Icons.person_outline_rounded,
                                        ),
                                      ),
                                      SizedBox(height: isVeryCompact ? 12 : 18),
                                      const Text(
                                        'Email',
                                        style: TextStyle(
                                          color: _deepPurple,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _emailCtrl,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.email,
                                        ],
                                        validator: Validators.email,
                                        decoration: _fieldDecoration(
                                          hintText: 'Enter email address',
                                          icon: Icons.mail_outline_rounded,
                                        ),
                                      ),
                                      SizedBox(height: isVeryCompact ? 12 : 18),
                                      const Text(
                                        'Password',
                                        style: TextStyle(
                                          color: _deepPurple,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _passwordCtrl,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.newPassword,
                                        ],
                                        validator: Validators.password,
                                        decoration: _fieldDecoration(
                                          hintText: 'Create a password',
                                          icon: Icons.lock_outline_rounded,
                                          suffixIcon: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                        .visibility_off_outlined,
                                              color: _hintPurple,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: isVeryCompact ? 12 : 18),
                                      const Text(
                                        'Confirm Password',
                                        style: TextStyle(
                                          color: _deepPurple,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _confirmCtrl,
                                        obscureText: _obscureConfirm,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.newPassword,
                                        ],
                                        validator: _confirmPasswordValidator,
                                        onFieldSubmitted: (_) {
                                          if (!_loading) _submit();
                                        },
                                        decoration: _fieldDecoration(
                                          hintText: 'Confirm your password',
                                          icon: Icons.lock_outline_rounded,
                                          suffixIcon: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _obscureConfirm =
                                                    !_obscureConfirm;
                                              });
                                            },
                                            icon: Icon(
                                              _obscureConfirm
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                        .visibility_off_outlined,
                                              color: _hintPurple,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: isVeryCompact ? 18 : 24),
                                      SizedBox(
                                        height: isVeryCompact ? 46 : 50,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: _buttonGradient,
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x33962CF8),
                                                blurRadius: 18,
                                                offset: Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton(
                                            onPressed: _loading
                                                ? null
                                                : _submit,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              disabledBackgroundColor:
                                                  Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              foregroundColor: Colors.white,
                                              disabledForegroundColor:
                                                  Colors.white70,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                            ),
                                            child: Text(
                                              _loading
                                                  ? 'Creating Account...'
                                                  : 'Continue',
                                              style: TextStyle(
                                                fontSize: isVeryCompact
                                                    ? 15
                                                    : 16,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: isVeryCompact ? 20 : 28),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    'Already have an account? ',
                                    style: TextStyle(
                                      color: _midPurple,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushReplacementNamed(
                                        context,
                                        Routes.login,
                                      );
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.only(top: 1),
                                      child: Text(
                                        'Sign in',
                                        style: TextStyle(
                                          color: _midPurple,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isVeryCompact ? 14 : 34),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
