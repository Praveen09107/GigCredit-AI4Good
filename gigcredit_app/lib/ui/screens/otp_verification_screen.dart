import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../app_router.dart';
import '../../app/theme.dart';
import 'login_screen.dart' show AuthMode;

class OtpRouteArgs {
  const OtpRouteArgs({
    required this.phoneNumber,
    required this.verificationId,
    required this.authMode,
    this.forceResendingToken,
  });

  final String phoneNumber;
  final String verificationId;
  final AuthMode authMode;
  final int? forceResendingToken;
}

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, required this.args});

  final OtpRouteArgs args;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _otpControllers = List<TextEditingController>.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List<FocusNode>.generate(6, (_) => FocusNode());
  final _authService = AuthService();

  String? _activeVerificationId;
  int? _forceResendingToken;
  bool _isVerifying = false;
  bool _isResending = false;
  int _resendSeconds = 30;
  Timer? _timer;
  late final AnimationController _animController;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _activeVerificationId = widget.args.verificationId;
    _forceResendingToken = widget.args.forceResendingToken;
    _startResendTimer();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _otpControllers) { c.dispose(); }
    for (final f in _otpFocusNodes) { f.dispose(); }
    _animController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  String get _fullOtp => _otpControllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    final smsCode = _fullOtp;
    if (smsCode.length != 6) {
      _showMessage('Please enter the complete 6-digit OTP.');
      return;
    }
    if (_activeVerificationId == null) {
      _showMessage('OTP session expired. Please resend OTP.');
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final result = await _authService.verifyOtp(
        verificationId: _activeVerificationId!,
        smsCode: smsCode,
        createProfileIfMissing: true,
      );

      // Keep local registry in sync after every successful OTP verification.
      await _authService.markPhoneRegistered(widget.args.phoneNumber);

      if (widget.args.authMode == AuthMode.login && result.isNewUser) {
        _showMessage('New account created from login flow. Continuing...');
      } else if (widget.args.authMode == AuthMode.signUp && !result.isNewUser) {
        _showMessage('Existing account detected. Continuing login...');
      }

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.home, (route) => false);
    } on FirebaseAuthException catch (e) {
      _showMessage(_authService.mapFirebaseErrorForUi(e));
    } catch (e) {
      _showMessage(_authService.mapAnyErrorForUi(e));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0 || _isResending) return;
    setState(() => _isResending = true);
    await _authService.sendOtp(
      phoneNumber: widget.args.phoneNumber,
      forceResendingToken: _forceResendingToken,
      onAutoVerified: () {
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.home, (route) => false);
      },
      onCodeAutoRetrievalTimeout: (_) {},
      onCodeSent: (verificationId, token) {
        if (!mounted) return;
        setState(() {
          _activeVerificationId = verificationId;
          _forceResendingToken = token;
        });
        _startResendTimer();
        _showMessage('OTP resent successfully.');
      },
      onError: _showMessage,
    );
    if (mounted) setState(() => _isResending = false);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onOtpFieldChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final modeLabel = widget.args.authMode == AuthMode.signUp ? 'Sign Up' : 'Login';
    final canResend = _resendSeconds == 0 && !_isResending;

    return Scaffold(
      backgroundColor: GigTheme.bgDeep,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: GigTheme.heroGrad)),
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GigTheme.blue.withAlpha(20),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                children: [
                  // AppBar row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: GigTheme.txtPrimary, size: 20),
                        ),
                        const Text(
                          'OTP Verification',
                          style: TextStyle(
                            color: GigTheme.txtPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: GigTheme.blue.withAlpha(25),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.sms_rounded, color: GigTheme.blue, size: 28),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Enter the OTP\nwe sent to',
                            style: TextStyle(
                              color: GigTheme.txtPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '+91 ${widget.args.phoneNumber}',
                            style: const TextStyle(
                              color: GigTheme.blue,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 32),
                          // OTP boxes — Expanded for responsive width
                          Row(
                            children: List.generate(6, (index) {
                              final focused = _otpFocusNodes[index].hasFocus;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(right: index < 5 ? 8 : 0),
                                  child: SizedBox(
                                    height: 54,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: GigTheme.surface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: focused ? GigTheme.blue : GigTheme.divider,
                                          width: 2,
                                        ),
                                        boxShadow: focused
                                            ? [BoxShadow(
                                                color: GigTheme.blue.withAlpha(40),
                                                blurRadius: 10,
                                              )]
                                            : [],
                                      ),
                                      child: TextField(
                                        controller: _otpControllers[index],
                                        focusNode: _otpFocusNodes[index],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        maxLength: 1,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                          color: GigTheme.txtPrimary,
                                        ),
                                        decoration: const InputDecoration(
                                          counterText: '',
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                          filled: false,
                                        ),
                                        onChanged: (v) => _onOtpFieldChanged(v, index),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 28),
                          // Verify button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: DecoratedBox(
                              decoration: _isVerifying || _fullOtp.length != 6
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
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _isVerifying ? null : _verifyOtp,
                                child: _isVerifying
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        'Verify and $modeLabel',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  _resendSeconds > 0
                                      ? 'Resend available in $_resendSeconds sec'
                                      : 'Didn\'t receive the OTP?',
                                  style: const TextStyle(
                                    color: GigTheme.txtSecond,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: canResend ? _resendOtp : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: canResend
                                          ? GigTheme.blue.withAlpha(20)
                                          : GigTheme.divider.withAlpha(40),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: canResend
                                            ? GigTheme.blue.withAlpha(80)
                                            : GigTheme.divider,
                                      ),
                                    ),
                                    child: _isResending
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: GigTheme.blue,
                                            ),
                                          )
                                        : Text(
                                            'Resend OTP',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: canResend ? GigTheme.blue : GigTheme.txtHint,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
