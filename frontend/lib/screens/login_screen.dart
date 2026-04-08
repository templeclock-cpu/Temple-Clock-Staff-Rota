import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'staff/staff_dashboard.dart';
import 'admin/admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        final user = result['user'] as Map<String, dynamic>;
        final userModel = UserModel.fromJson(user);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => user['role'] == 'admin'
                ? AdminDashboard(user: userModel)
                : StaffDashboard(user: userModel),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Login failed'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } on ApiConnectionException {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot connect to server. Please check your connection and try again.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 5),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Scaffold(
      backgroundColor: const Color(0xFF0F2C59),
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  // ── Wide: left brand panel + right form ──────────────────────────────────
  Widget _wideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F2C59), Color(0xFF1A4A8A)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(top: -80, left: -80,
                    child: _circle(260, Colors.white.withValues(alpha: 0.04))),
                Positioned(bottom: -100, right: -100,
                    child: _circle(340, Colors.white.withValues(alpha: 0.03))),
                Positioned(top: 200, right: -50,
                    child: _circle(130, AppColors.teal.withValues(alpha: 0.12))),
                Padding(
                  padding: const EdgeInsets.all(52),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/logo.png', height: 60),
                      const SizedBox(height: 28),
                      const Text('Temple Clock',
                          style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 10),
                      Text(
                        'Workforce management\nfor care teams.',
                        style: TextStyle(
                            fontSize: 17,
                            color: Colors.white.withValues(alpha: 0.7),
                            height: 1.65),
                      ),
                      const SizedBox(height: 44),
                      _featureRow(Icons.schedule_rounded, 'Smart rota scheduling'),
                      const SizedBox(height: 14),
                      _featureRow(Icons.fingerprint_rounded, 'Geo-fenced clock-in/out'),
                      const SizedBox(height: 14),
                      _featureRow(Icons.bar_chart_rounded, 'Payroll & attendance reports'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            color: const Color(0xFFF8F9FA),
            child: Center(child: _formCard()),
          ),
        ),
      ],
    );
  }

  // ── Narrow: brand strip on top + form below ───────────────────────────────
  Widget _narrowLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 44, 24, 36),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F2C59), Color(0xFF1A4A8A)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/images/logo.png', height: 40),
                  const SizedBox(height: 14),
                  const Text('Temple Clock',
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Workforce management for care teams',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.65))),
                ],
              ),
            ),
            Container(
              color: const Color(0xFFF8F9FA),
              padding: const EdgeInsets.all(20),
              child: _formCard(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form card ─────────────────────────────────────────────────────────────
  Widget _formCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome back',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Sign in to your account',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 28),
            _fieldLabel('Email address'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 14),
              decoration: _inputDeco(
                  hint: 'you@example.com', icon: Icons.email_outlined),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Email is required' : null,
            ),
            const SizedBox(height: 18),
            _fieldLabel('Password'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(fontSize: 14),
              decoration: _inputDeco(
                hint: '••••••••',
                icon: Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password is required' : null,
              onFieldSubmitted: (_) => _isLoading ? null : _login(),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Sign In',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary));

  InputDecoration _inputDeco(
      {required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
      suffixIcon: suffix,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: AppColors.teal),
        ),
        const SizedBox(width: 10),
        Text(text,
            style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.82),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _circle(double size, Color color) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}
