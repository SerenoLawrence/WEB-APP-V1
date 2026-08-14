import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/validators.dart';
import '../../screens/auth/forgot_password_flow.dart';
import '../../services/auth_service.dart';
import '../../widgets/buttons/primary_button.dart';

class LoginScreen extends StatefulWidget {
  final bool fromVisitor;
  const LoginScreen({super.key, this.fromVisitor = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePin = true;

  // 6-digit PIN state
  String _pin = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── Login handler ─────────────────────────────────────────────────────────
  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pin.length != 6) {
      _showSnack('Please enter your 6-digit PIN', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final phone = '+63${_phoneController.text.replaceAll(' ', '')}';
    final result = await AuthService.instance.loginWithPin(
      phone: phone,
      pin: _pin,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success && result.user != null) {
      // Real login succeeded — update AppState then go to Home
      AppState().exitGuest();
      await AppState().onLoginSuccess(result.user!);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.home, (route) => false);
    } else {
      // Show the error from the API (or the TODO message while PIN login
      // endpoint is being built — in that case hint user to use OTP)
      final msg = result.error ?? 'Login failed. Please try again.';
      _showSnack(msg, isError: true);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.loginBg,
      body: Stack(
        children: [
          // ── Background decorations ────────────────────────────────────
          Positioned(
            top: -90,
            right: -90,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.loginBgDark.withValues(alpha: 0.35),
              ),
            ),
          ),
          Positioned(
            top: -30,
            left: -70,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 130,
            left: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.loginBgDark.withValues(alpha: 0.15),
              ),
            ),
          ),

          // ── City skyline bottom decoration ────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _CitySkyline(),
          ),

          // ── Main content ──────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),

                        // ── Back to visitor ────────────────────────────
                        if (widget.fromVisitor) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () {
                                AppState().enterAsGuest();
                                Navigator.pushReplacementNamed(
                                    context, AppRoutes.visitor);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.white
                                      .withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      Border.all(color: AppColors.divider),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        size: 13,
                                        color: AppColors.textSecondary),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Continue Browsing',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── Logo + title ───────────────────────────────
                        Center(
                          child: Column(
                            children: [
                              _LogoBadge(size: 88),
                              const SizedBox(height: 16),
                              Text(
                                'CIVILWATCH',
                                style: GoogleFonts.inter(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.navy,
                                  letterSpacing: 2.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Community Reporting for a\nBetter Digos City',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.55,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Form card ──────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.navy.withValues(alpha: 0.09),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Card header ────────────────────────
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.navy
                                          .withValues(alpha: 0.08),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.login_rounded,
                                        color: AppColors.navy, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Login',
                                          style: GoogleFonts.inter(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Welcome back! Please login to your account.',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // ── Phone number ───────────────────────
                              Text(
                                'Mobile Number',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                validator: AppValidators.phoneNumber,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                  _PhoneNumberFormatter(),
                                ],
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: '9XX XXX XXXX',
                                  hintStyle: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppColors.textHint),
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                  prefixIcon: _PhonePrefixWidget(),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 16),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: AppColors.inputBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: AppColors.inputBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: AppColors.navy, width: 2),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFDC2626)),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFDC2626),
                                        width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // ── Password (6-digit PIN) ─────────────
                              Text(
                                'Password',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _PinPasswordField(
                                onChanged: (v) =>
                                    setState(() => _pin = v),
                                obscure: _obscurePin,
                                onToggleObscure: () => setState(
                                    () => _obscurePin = !_obscurePin),
                              ),
                              const SizedBox(height: 10),

                              // ── Forgot password ────────────────────
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () =>
                                      showForgotPasswordFlow(context),
                                  child: Text(
                                    'Forgot Password?',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.navy,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // ── Login button ───────────────────────
                              PrimaryButton(
                                label: 'Login',
                                icon: Icons.login_rounded,
                                isLoading: _isLoading,
                                onPressed: _login,
                                backgroundColor: AppColors.primary,
                                borderRadius: 14,
                                height: 52,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ── Register link ──────────────────────────────
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(
                                    context, AppRoutes.register),
                                child: Text(
                                  'Register',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Trust badges ───────────────────────────────
                        _TrustBadgeRow(),

                        const SizedBox(height: 180),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6-digit PIN password field (single text input, obscurable)
// ─────────────────────────────────────────────────────────────────────────────

class _PinPasswordField extends StatefulWidget {
  final void Function(String) onChanged;
  final bool obscure;
  final VoidCallback onToggleObscure;

  const _PinPasswordField({
    required this.onChanged,
    required this.obscure,
    required this.onToggleObscure,
  });

  @override
  State<_PinPasswordField> createState() => _PinPasswordFieldState();
}

class _PinPasswordFieldState extends State<_PinPasswordField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      obscureText: widget.obscure,
      obscuringCharacter: '●',
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: widget.onChanged,
      style: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
        letterSpacing: 6,
      ),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        counterText: '',
        hintText: widget.obscure ? '● ● ● ● ● ●' : '0 0 0 0 0 0',
        hintStyle: GoogleFonts.inter(
          fontSize: 16,
          color: AppColors.textHint,
          letterSpacing: 4,
        ),
        filled: true,
        fillColor: AppColors.inputFill,
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: AppColors.textSecondary, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            widget.obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.textSecondary,
            size: 20,
          ),
          onPressed: widget.onToggleObscure,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.navy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFDC2626), width: 2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phone prefix (+63 flag)
// ─────────────────────────────────────────────────────────────────────────────

class _PhonePrefixWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.inputBorder)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🇵🇭', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(
            '+63',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phone formatter: 9XX XXX XXXX
// ─────────────────────────────────────────────────────────────────────────────

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 10; i++) {
      if (i == 3 || i == 6) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return newValue.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trust badges row
// ─────────────────────────────────────────────────────────────────────────────

class _TrustBadgeRow extends StatelessWidget {
  static const _badges = [
    (Icons.shield_rounded, 'Secure'),
    (Icons.visibility_off_rounded, 'Private'),
    (Icons.verified_rounded, 'Trusted'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _badges.map((b) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              Icon(b.$1, size: 20, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(
                b.$2,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo badge
// ─────────────────────────────────────────────────────────────────────────────

class _LogoBadge extends StatelessWidget {
  final double size;
  const _LogoBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.navy,
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.3),
            blurRadius: 22,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shield_rounded,
              color: AppColors.white.withValues(alpha: 0.10),
              size: size * 0.82),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_rounded,
                  color: AppColors.white, size: size * 0.28),
              Icon(Icons.eco_rounded,
                  color: AppColors.primary, size: size * 0.22),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// City skyline bottom decoration
// ─────────────────────────────────────────────────────────────────────────────

class _CitySkyline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(MediaQuery.of(context).size.width, 160),
      painter: _SkylinePainter(),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final buildingPaint = Paint()..color = const Color(0xFFCFDDE8);
    final treePaint = Paint()..color = const Color(0xFFB5D4C0);
    final groundPaint = Paint()..color = const Color(0xFFD8EAF0);

    canvas.drawRect(
        Rect.fromLTWH(
            0, size.height * 0.7, size.width, size.height * 0.3),
        groundPaint);

    final buildings = [
      [0.0, 0.4, 0.12, 0.3],
      [0.1, 0.25, 0.08, 0.45],
      [0.2, 0.3, 0.1, 0.4],
      [0.35, 0.15, 0.12, 0.55],
      [0.48, 0.35, 0.09, 0.35],
      [0.6, 0.2, 0.11, 0.5],
      [0.73, 0.38, 0.08, 0.32],
      [0.82, 0.28, 0.1, 0.42],
      [0.93, 0.4, 0.07, 0.3],
    ];
    for (final b in buildings) {
      canvas.drawRect(
        Rect.fromLTWH(size.width * b[0], size.height * b[1],
            size.width * b[2], size.height * b[3]),
        buildingPaint,
      );
    }
    final windowPaint = Paint()
      ..color = const Color(0xFFE8F4FD).withValues(alpha: 0.8);
    for (final b in buildings) {
      final bx = size.width * b[0];
      final by = size.height * b[1];
      final bw = size.width * b[2];
      final bh = size.height * b[3];
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 2; col++) {
          canvas.drawRect(
            Rect.fromLTWH(bx + bw * 0.2 + col * bw * 0.45,
                by + bh * 0.15 + row * bh * 0.25, bw * 0.2, bh * 0.12),
            windowPaint,
          );
        }
      }
    }
    final trunkPaint = Paint()..color = const Color(0xFFB5A08A);
    for (final tx in [0.05, 0.28, 0.52, 0.68, 0.88]) {
      final x = size.width * tx;
      final y = size.height * 0.58;
      canvas.drawRect(
          Rect.fromLTWH(x + 8, y + 22, 6, 16), trunkPaint);
      canvas.drawCircle(Offset(x + 11, y + 16), 16, treePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
