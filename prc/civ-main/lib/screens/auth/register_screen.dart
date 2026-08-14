import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/validators.dart';
import '../../services/auth_service.dart';
import '../../widgets/buttons/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────────────────────────────
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // ── PIN state ─────────────────────────────────────────────────────────────
  String _pin = '';
  String _confirmPin = '';
  bool _pinMismatch = false;

  // ── Other state ───────────────────────────────────────────────────────────
  String? _selectedBarangay;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();

    // Pre-fill phone if passed from OTP screen (stripped of +63 prefix)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['phone'] != null) {
        final raw = args['phone'].toString()
            .replaceAll('+63', '')
            .replaceAll(' ', '')
            .trim();
        _phoneCtrl.text = raw;
      }
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── Validation helpers ────────────────────────────────────────────────────
  bool get _pinReady => _pin.length == 6;
  bool get _confirmReady => _confirmPin.length == 6;

  void _onPinChanged(String pin) => setState(() {
        _pin = pin;
        _pinMismatch = false;
      });

  void _onConfirmChanged(String pin) => setState(() {
        _confirmPin = pin;
        _pinMismatch = false;
      });

  // ── Registration handler ──────────────────────────────────────────────────
  void _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBarangay == null) {
      _showSnack('Please select your home barangay', isError: true);
      return;
    }
    if (!_pinReady) {
      _showSnack('Please enter a 6-digit PIN', isError: true);
      return;
    }
    if (!_confirmReady) {
      _showSnack('Please confirm your 6-digit PIN', isError: true);
      return;
    }
    if (_pin != _confirmPin) {
      setState(() => _pinMismatch = true);
      _showSnack('PINs do not match. Please try again.', isError: true);
      return;
    }
    if (!_agreedToTerms) {
      _showSnack(
          'Please agree to the Privacy Policy and Terms of Service',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final phone = '+63${_phoneCtrl.text.replaceAll(' ', '')}';

    final result = await AuthService.instance.register(
      fullName: _nameCtrl.text.trim(),
      phone: phone,
      barangay: _selectedBarangay!,
      pin: _pin,
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success && result.user != null) {
      // Registration succeeded — update AppState and go to Home
      await AppState().onLoginSuccess(result.user!);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    } else {
      _showSnack(
        result.error ?? 'Registration failed. Please try again.',
        isError: true,
      );
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // ── Header bar ──────────────────────────────────────────
                  _RegisterHeader(),

                  // ── Scrollable body ─────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(24, 24, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Page title ──────────────────────────────────
                          Text(
                            'Create your account',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fill in your details to get started with CIVILWATCH.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Form card ────────────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                // ── Phone Number ─────────────────────────
                                _FieldLabel(
                                    icon: Icons.phone_android_rounded,
                                    label: 'Mobile Number'),
                                const SizedBox(height: 8),
                                _buildPhoneField(),
                                const SizedBox(height: 18),

                                // ── Full Name ─────────────────────────────
                                _FieldLabel(
                                    icon: Icons.person_outline_rounded,
                                    label: 'Full Name'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _nameCtrl,
                                  hint: 'e.g. Juan dela Cruz',
                                  validator: AppValidators.fullName,
                                  keyboardType: TextInputType.name,
                                  prefixIcon:
                                      Icons.person_outline_rounded,
                                ),
                                const SizedBox(height: 18),

                                // ── Email (optional) ──────────────────────
                                _FieldLabel(
                                  icon: Icons.email_outlined,
                                  label: 'Email Address',
                                  isOptional: true,
                                ),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _emailCtrl,
                                  hint: 'your@email.com',
                                  validator:
                                      AppValidators.emailOptional,
                                  keyboardType:
                                      TextInputType.emailAddress,
                                  prefixIcon: Icons.email_outlined,
                                ),
                                const SizedBox(height: 18),

                                // ── Home Barangay ─────────────────────────
                                _FieldLabel(
                                    icon: Icons.location_on_outlined,
                                    label: 'Home Barangay'),
                                const SizedBox(height: 8),
                                _BarangayDropdown(
                                  value: _selectedBarangay,
                                  onChanged: (v) => setState(
                                      () => _selectedBarangay = v),
                                ),
                                const SizedBox(height: 24),

                                // ── Divider ───────────────────────────────
                                const Divider(color: AppColors.divider),
                                const SizedBox(height: 20),

                                // ── Create PIN ────────────────────────────
                                _FieldLabel(
                                    icon: Icons.pin_outlined,
                                    label: 'Create 6-Digit PIN'),
                                const SizedBox(height: 6),
                                Text(
                                  'You will use this PIN to log in to CIVILWATCH.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _PinInputRow(
                                  key: const ValueKey('create-pin'),
                                  isError: _pinMismatch,
                                  onChanged: _onPinChanged,
                                ),

                                const SizedBox(height: 20),

                                // ── Confirm PIN ───────────────────────────
                                _FieldLabel(
                                    icon: Icons.lock_person_outlined,
                                    label: 'Confirm PIN'),
                                const SizedBox(height: 6),
                                Text(
                                  'Re-enter your 6-digit PIN to confirm.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _PinInputRow(
                                  key: const ValueKey('confirm-pin'),
                                  isError: _pinMismatch,
                                  onChanged: _onConfirmChanged,
                                ),

                                // ── Mismatch error ────────────────────────
                                if (_pinMismatch) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                          color:
                                              const Color(0xFFFCA5A5)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                            Icons.error_outline_rounded,
                                            color: Color(0xFFDC2626),
                                            size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          'PINs do not match. Please try again.',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color:
                                                const Color(0xFFDC2626),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 4),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Terms & Privacy checkbox ──────────────────
                          _TermsCheckbox(
                            agreed: _agreedToTerms,
                            onTap: () => setState(
                                () => _agreedToTerms = !_agreedToTerms),
                          ),

                          const SizedBox(height: 24),

                          // ── Create Account button ─────────────────────
                          PrimaryButton(
                            label: 'Create Account',
                            icon: Icons.check_circle_outline_rounded,
                            isLoading: _isLoading,
                            onPressed: _register,
                            backgroundColor: AppColors.primary,
                            borderRadius: 16,
                            height: 54,
                          ),

                          const SizedBox(height: 16),

                          // ── Already have account ──────────────────────
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Already have an account? Sign in',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
        ),
      ),
    );
  }

  // ── Phone field builder ───────────────────────────────────────────────────
  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      validator: AppValidators.phoneNumber,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
        _PhoneFormatter(),
      ],
      style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: '9XX XXX XXXX',
        hintStyle:
            GoogleFonts.inter(fontSize: 14, color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.inputFill,
        prefixIcon: _PhonePrefixWidget(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
      ),
    );
  }

  // ── Shared text field builder ─────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(
          fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            fontSize: 14, color: AppColors.textHint),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.textHint, size: 20)
            : null,
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFFDC2626), width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6-digit PIN input row — dots that fill as you type, numeric keyboard
// ─────────────────────────────────────────────────────────────────────────────

class _PinInputRow extends StatefulWidget {
  final void Function(String pin) onChanged;
  final bool isError;

  const _PinInputRow({
    super.key,
    required this.onChanged,
    this.isError = false,
  });

  @override
  State<_PinInputRow> createState() => _PinInputRowState();
}

class _PinInputRowState extends State<_PinInputRow> {
  late List<TextEditingController> _ctrls;
  late List<FocusNode> _nodes;
  static const int _len = 6;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(_len, (_) => TextEditingController());
    _nodes = List.generate(_len, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _onChange(String val, int idx) {
    if (val.length == 1 && idx < _len - 1) {
      _nodes[idx + 1].requestFocus();
    }
    if (val.isEmpty && idx > 0) {
      _nodes[idx - 1].requestFocus();
    }
    final full = _ctrls.map((c) => c.text).join();
    widget.onChanged(full);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final activeColor =
        widget.isError ? const Color(0xFFDC2626) : AppColors.primary;
    final filledColor =
        widget.isError ? const Color(0xFFDC2626) : AppColors.navy;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_len, (i) {
        final isFilled = _ctrls[i].text.isNotEmpty;

        return Container(
          width: 46,
          height: 54,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: TextFormField(
            controller: _ctrls[i],
            focusNode: _nodes[i],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            obscureText: true,
            obscuringCharacter: '●',
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) => _onChange(v, i),
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: filledColor,
              letterSpacing: 0,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: isFilled
                  ? filledColor.withValues(alpha: 0.06)
                  : AppColors.inputFill,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isFilled
                      ? filledColor.withValues(alpha: 0.4)
                      : AppColors.inputBorder,
                  width: isFilled ? 1.5 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: activeColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: Color(0xFFDC2626), width: 2),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Terms & Privacy checkbox
// ─────────────────────────────────────────────────────────────────────────────

class _TermsCheckbox extends StatelessWidget {
  final bool agreed;
  final VoidCallback onTap;

  const _TermsCheckbox({required this.agreed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: agreed ? AppColors.primarySurface : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: agreed ? AppColors.primary : AppColors.divider,
            width: agreed ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: agreed ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color:
                      agreed ? AppColors.primary : AppColors.inputBorder,
                  width: 1.5,
                ),
              ),
              child: agreed
                  ? const Icon(Icons.check_rounded,
                      color: AppColors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Register header bar
// ─────────────────────────────────────────────────────────────────────────────

class _RegisterHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Account',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Step 1 of 2 · Create Account',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.navy,
            ),
            child: const Icon(Icons.shield_rounded,
                color: AppColors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Field label with icon
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isOptional;

  const _FieldLabel({
    required this.icon,
    required this.label,
    this.isOptional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (isOptional) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              'Optional',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barangay dropdown
// ─────────────────────────────────────────────────────────────────────────────

class _BarangayDropdown extends StatelessWidget {
  final String? value;
  final void Function(String?) onChanged;

  const _BarangayDropdown(
      {required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      hint: Text(
        'Select your barangay',
        style: GoogleFonts.inter(
            fontSize: 14, color: AppColors.textHint),
      ),
      onChanged: onChanged,
      items: AppStrings.barangays
          .map((b) => DropdownMenuItem(
                value: b,
                child: Text(b,
                    style: GoogleFonts.inter(fontSize: 14)),
              ))
          .toList(),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.inputFill,
        prefixIcon: const Icon(Icons.location_on_outlined,
            color: AppColors.textHint, size: 20),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColors.primary, width: 1.5),
        ),
      ),
      style: GoogleFonts.inter(
          fontSize: 14, color: AppColors.textPrimary),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.textSecondary),
      borderRadius: BorderRadius.circular(12),
      isExpanded: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phone prefix widget (+63 flag) — reused from login
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

class _PhoneFormatter extends TextInputFormatter {
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
