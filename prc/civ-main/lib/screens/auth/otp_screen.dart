import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/state/app_state.dart';
import '../../services/auth_service.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/inputs/otp_box.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isNewUser;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.isNewUser = true,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  String _otp = '';
  bool _isLoading = false;
  bool _isSending = false;
  bool _sendFailed = false;

  // In dev mode Laravel returns the OTP code in the response.
  // We show it on screen so you can copy-paste it without an SMS provider.
  String? _devOtp;

  int _resendSeconds = 60;
  Timer? _timer;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Animations
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();

    // Send OTP as soon as the screen opens
    _sendOtp();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  // ── Real API call ─────────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    setState(() {
      _isSending = true;
      _sendFailed = false;
      _devOtp = null;
    });

    final result = await AuthService.instance.sendOtp(widget.phoneNumber);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (result.success) {
      // Laravel returns the OTP in dev mode — show it so you can test
      // without a real SMS provider. Remove this before going live.
      if (result.otp != null) {
        setState(() => _devOtp = result.otp);
      }
      _startTimer();
    } else {
      setState(() => _sendFailed = true);
      _showSnack(
        result.error ?? 'Failed to send OTP. Is Laravel running?',
        isError: true,
      );
    }
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _resend() async {
    await _sendOtp();
    if (!mounted) return;
    _showSnack('OTP resent to ${widget.phoneNumber}', isError: false);
  }

  Future<void> _verify() async {
    if (_otp.length != 6) {
      _showSnack('Please enter the 6-digit OTP', isError: true);
      return;
    }
    setState(() => _isLoading = true);

    final result = await AuthService.instance.verifyOtp(
      widget.phoneNumber,
      _otp,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) {
      _showSnack(result.error ?? 'Invalid OTP. Please try again.', isError: true);
      return;
    }

    if (result.isNewUser) {
      // New user — go to Register screen to complete profile
      Navigator.pushNamed(
        context,
        AppRoutes.register,
        arguments: {'phone': widget.phoneNumber},
      );
    } else {
      // Returning user — token already saved, load data then go Home
      if (result.token != null) {
        final user = AuthService.instance.currentUser;
        if (user != null) {
          await AppState().onLoginSuccess(user);
        }
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String get _timerText {
    final mm = (_resendSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_resendSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // ── OTP illustration ─────────────────────────────────────
                const _OtpIllustration(),
                const SizedBox(height: 32),

                // ── Title ─────────────────────────────────────────────────
                Text(
                  'Verify your number',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter the 6-digit code we sent to verify\nyour phone for registration.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.phoneNumber,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Sending indicator ─────────────────────────────────────
                if (_isSending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sending OTP via SMS…',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Send failed banner ────────────────────────────────────
                if (_sendFailed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Failed to send OTP. Check your connection and tap Resend.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Dev OTP banner (remove before going live) ────────────
                if (_devOtp != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.developer_mode_rounded,
                                color: Color(0xFF16A34A), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'DEV MODE — Your OTP code:',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _devOtp!,
                          style: GoogleFonts.robotoMono(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF15803D),
                            letterSpacing: 8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Remove this banner before publishing.',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),
                OtpInputRow(
                  length: 6,
                  onCompleted: (otp) => setState(() => _otp = otp),
                  onChanged: (otp) => setState(() => _otp = otp),
                ),
                const SizedBox(height: 32),

                // ── Resend ────────────────────────────────────────────────
                Text(
                  "Didn't receive the code?",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                if (_resendSeconds > 0)
                  RichText(
                    text: TextSpan(
                      text: 'Resend in ',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: _timerText,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  TextButton(
                    onPressed: _isSending ? null : _resend,
                    child: Text(
                      'Resend OTP',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                const SizedBox(height: 40),

                // ── Verify button ─────────────────────────────────────────
                PrimaryButton(
                  label: 'Verify',
                  icon: Icons.verified_user_rounded,
                  isLoading: _isLoading,
                  onPressed: _verify,
                ),
                const SizedBox(height: 14),

                // ── Security note ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded,
                          color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'For your security, never share your OTP with anyone.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Back text button ──────────────────────────────────────
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    size: 16,
                    color: AppColors.navy,
                  ),
                  label: Text(
                    'Back',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── OTP Illustration ──────────────────────────────────────────────────────────
class _OtpIllustration extends StatelessWidget {
  const _OtpIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Phone outline
          Container(
            width: 80,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.inputBorder, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 50,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 40,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),

          // OTP badge
          Positioned(
            top: 0,
            right: 60,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                '123456',
                style: GoogleFonts.robotoMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          // Verified badge
          Positioned(
            bottom: 4,
            right: 55,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.statusResolved,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.white,
                size: 16,
              ),
            ),
          ),

          // Sparkle decorations
          Positioned(
            top: 8,
            left: 20,
            child: Icon(
              Icons.star_rounded,
              size: 12,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 15,
            child: Icon(
              Icons.star_rounded,
              size: 8,
              color: AppColors.statusPending.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
