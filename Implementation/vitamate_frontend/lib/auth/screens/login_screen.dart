import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/routing/routes.dart';
import '../../core/testing/app_test_keys.dart';
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authController = AuthController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _navigatingAway = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _authController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || _navigatingAway) {
      if (kDebugMode) {
        debugPrint('LoginScreen: submit ignored while busy');
      }
      return;
    }
    if (kDebugMode) {
      debugPrint('LoginScreen: submit tapped');
    }
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      if (kDebugMode) {
        debugPrint('LoginScreen: validation failed');
      }
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final success = await _authController.login(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _authController.error ?? 'Login failed. Please try again.',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      _navigatingAway = true;
      if (kDebugMode) {
        debugPrint('LoginScreen: navigating home');
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.home,
        (route) => false,
      );
      return;
    } finally {
      if (mounted && !_navigatingAway) {
        setState(() => _loading = false);
      }
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
    final disableAndroidAutofill =
        defaultTargetPlatform == TargetPlatform.android;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(gradient: _pageBackground),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 740;
              final isVeryCompact = constraints.maxHeight < 660;
              return ListView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: isVeryCompact
                              ? 8
                              : isCompact
                              ? 18
                              : 30,
                          bottom: isVeryCompact ? 8 : 18,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                              SizedBox(height: isVeryCompact ? 18 : 26),
                              Text(
                                'Welcome back',
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
                                'Sign in to access your smart health assistant.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _midPurple,
                                  fontSize: isVeryCompact ? 14 : 16,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                              SizedBox(height: isVeryCompact ? 20 : 30),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: _shellBackground,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x1A57369A),
                                      blurRadius: 18,
                                      offset: Offset(0, 8),
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
                                        key: const ValueKey(
                                          AppTestKeys.loginUsernameField,
                                        ),
                                        controller: _usernameCtrl,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: disableAndroidAutofill
                                            ? null
                                            : const [AutofillHints.username],
                                        enableSuggestions:
                                            !disableAndroidAutofill,
                                        autocorrect: false,
                                        validator: (value) {
                                          final trimmed = (value ?? '').trim();
                                          if (trimmed.isEmpty) {
                                            return 'Username is required';
                                          }
                                          return null;
                                        },
                                        decoration: _fieldDecoration(
                                          hintText: 'Enter your username',
                                          icon: Icons.person_outline_rounded,
                                        ),
                                      ),
                                      SizedBox(height: isVeryCompact ? 14 : 18),
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
                                        key: const ValueKey(
                                          AppTestKeys.loginPasswordField,
                                        ),
                                        controller: _passwordCtrl,
                                        obscureText: _obscure,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: disableAndroidAutofill
                                            ? null
                                            : const [AutofillHints.password],
                                        enableSuggestions: false,
                                        autocorrect: false,
                                        enableInteractiveSelection:
                                            !disableAndroidAutofill,
                                        validator: Validators.password,
                                        onFieldSubmitted: (_) {
                                          if (!_loading) _submit();
                                        },
                                        decoration: _fieldDecoration(
                                          hintText: 'Enter your password',
                                          icon: Icons.lock_outline_rounded,
                                          suffixIcon: IconButton(
                                            onPressed: () {
                                              setState(
                                                () => _obscure = !_obscure,
                                              );
                                            },
                                            icon: Icon(
                                              _obscure
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                        .visibility_off_outlined,
                                              color: _hintPurple,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: isVeryCompact ? 8 : 12),
                                      const Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          'Forgot password?',
                                          style: TextStyle(
                                            color: _midPurple,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
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
                                                blurRadius: 12,
                                                offset: Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton(
                                            key: const ValueKey(
                                              AppTestKeys.loginSubmitButton,
                                            ),
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
                                                  ? 'Signing In...'
                                                  : 'Sign In',
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
                                    "Don't have an account? ",
                                    style: TextStyle(
                                      color: _midPurple,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        Routes.signup,
                                      );
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.only(top: 1),
                                      child: Text(
                                        'Sign up',
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
                              SizedBox(height: isVeryCompact ? 16 : 34),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
