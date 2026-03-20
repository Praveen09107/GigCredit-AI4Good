import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../app_router.dart';
import '../../services/auth_service.dart';
import 'otp_verification_screen.dart';

enum AuthMode { login, signUp }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _authService = AuthService();

  AuthMode _authMode = AuthMode.login;
  bool _isSendingOtp = false;
  late final AnimationController _anim;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      _toast('Enter a valid 10-digit Indian mobile number.');
      return;
    }

    try {
      final isRegistered = await _authService.isPhoneRegisteredLocally(phone);
      if (_authMode == AuthMode.signUp && isRegistered) {
        _toast('This number already has an account. Please login.');
        return;
      }
    } catch (_) {
      // If local lookup fails, continue with OTP flow.
    }

    setState(() => _isSendingOtp = true);
    await _authService.sendOtp(
      phoneNumber: phone,
      onAutoVerified: () {
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.home, (r) => false);
      },
      onCodeSent: (verificationId, forceResendingToken) {
        if (!mounted) return;
        Navigator.of(context).pushNamed(
          AppRouter.otp,
          arguments: OtpRouteArgs(
            phoneNumber: phone,
            verificationId: verificationId,
            authMode: _authMode,
            forceResendingToken: forceResendingToken,
          ),
        );
      },
      onCodeAutoRetrievalTimeout: (_) {
        if (!mounted) return;
        _toast('OTP auto-retrieval timed out. Enter OTP manually.');
      },
      onError: _toast,
    );
    if (mounted) setState(() => _isSendingOtp = false);
  }

  void _toast(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GigTheme.bgDeep,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Full-screen background gradient
          Container(decoration: const BoxDecoration(gradient: GigTheme.heroGrad)),
          // Glow bubbles
          Positioned(
            top: -100,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GigTheme.blue.withAlpha(25),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GigTheme.magenta.withAlpha(18),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: GigTheme.accentGrad,
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color: GigTheme.magenta.withAlpha(60),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.asset(
                              'assets/home/gigcredit_logo.jpeg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.verified_user_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'GigCredit',
                          style: TextStyle(
                            color: GigTheme.txtPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Your financial\nidentity starts here.',
                      style: TextStyle(
                        color: GigTheme.txtPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'OTP-based secure login. No passwords needed.',
                      style: TextStyle(color: GigTheme.txtSecond, fontSize: 14),
                    ),
                    const SizedBox(height: 32),

                    // ── Card ────────────────────────────────────────────
                    Container(
                      decoration: GigTheme.surfaceCard(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mode toggle
                          Container(
                            decoration: BoxDecoration(
                              color: GigTheme.bgDeep,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                _ModeTab(
                                  label: 'Login',
                                  icon: Icons.login_rounded,
                                  selected: _authMode == AuthMode.login,
                                  onTap: () => setState(() => _authMode = AuthMode.login),
                                ),
                                _ModeTab(
                                  label: 'Sign Up',
                                  icon: Icons.person_add_rounded,
                                  selected: _authMode == AuthMode.signUp,
                                  onTap: () => setState(() => _authMode = AuthMode.signUp),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Mobile Number',
                            style: TextStyle(
                              color: GigTheme.txtSecond,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Phone field
                          Container(
                            decoration: BoxDecoration(
                              color: GigTheme.bgDeep,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: GigTheme.divider),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                  decoration: const BoxDecoration(
                                    border: Border(right: BorderSide(color: GigTheme.divider)),
                                  ),
                                  child: const Text(
                                    '🇮🇳 +91',
                                    style: TextStyle(
                                      color: GigTheme.txtPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: const TextStyle(
                                      color: GigTheme.txtPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Enter 10-digit number',
                                      hintStyle: TextStyle(color: GigTheme.txtHint),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                      counterText: '',
                                      fillColor: Colors.transparent,
                                      filled: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Send OTP button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: DecoratedBox(
                              decoration: _isSendingOtp
                                  ? BoxDecoration(
                                      color: GigTheme.divider,
                                      borderRadius: BorderRadius.circular(14),
                                    )
                                  : GigTheme.accentButton(),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: _isSendingOtp ? null : _sendOtp,
                                child: _isSendingOtp
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        _authMode == AuthMode.signUp ? 'Sign Up with OTP' : 'Login with OTP',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _authMode == AuthMode.signUp
                                ? 'New users are created automatically after OTP verification.'
                                : 'Your session stays logged in securely after verification.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: GigTheme.txtHint,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Footer
                    Center(
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 13, color: GigTheme.txtHint),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Firebase Phone Auth  •  End-to-end encrypted',
                              style: TextStyle(color: GigTheme.txtHint, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mode Tab Widget ───────────────────────────────────────
class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? GigTheme.surfaceUp : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: selected
                ? Border.all(color: GigTheme.blue.withAlpha(100))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? GigTheme.blue : GigTheme.txtHint),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? GigTheme.txtPrimary : GigTheme.txtHint,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
