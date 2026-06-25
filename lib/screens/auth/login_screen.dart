import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/glass_card.dart';
import '../home/home_screen.dart';

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
  bool _useMagicLink = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    if (_useMagicLink) {
      await _sendMagicLink();
      return;
    }

    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);

    final result = await authService.signInWithEmailPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (mounted) setState(() => _isLoading = false);

    if (result['success']) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } else {
      Fluttertoast.showToast(msg: result['message'] ?? 'Login failed');
    }
  }

  Future<void> _sendMagicLink() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final result =
        await authService.sendMagicLink(_emailController.text.trim());
    if (mounted) setState(() => _isLoading = false);

    Fluttertoast.showToast(
      msg: result['message'] ??
          (result['success'] == true
              ? 'Magic link sent'
              : 'Unable to send magic link'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 32),
                    _buildHero(),
                    const SizedBox(height: 26),
                    _buildLoginCard(),
                    const SizedBox(height: 24),
                    _buildSignupLink(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        _RoundIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: const Text(
            'Secure college access',
            style: TextStyle(
              color: AppTheme.secondaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AuthLogo(size: 76),
        const SizedBox(height: 24),
        const Text(
          'Welcome back',
          style: TextStyle(
            color: AppTheme.darkTextColor,
            fontSize: 34,
            height: 1.04,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Sign in to manage clubs, discover college events, and stay connected with ${AppConstants.appName}.',
          style: const TextStyle(
            color: AppTheme.secondaryColor,
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return GlassCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAuthModeSwitch(),
          const SizedBox(height: 22),
          CustomTextField(
            label: 'Email Address',
            hint: 'gmail.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.validateEmail,
            prefixIcon: Icons.alternate_email_rounded,
          ),
          if (!_useMagicLink) ...[
            const SizedBox(height: 18),
            CustomTextField(
              label: 'Password',
              hint: 'Enter your password',
              controller: _passwordController,
              obscureText: true,
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Password is required'
                  : null,
              prefixIcon: Icons.lock_outline_rounded,
            ),
          ],
          const SizedBox(height: 22),
          CustomButton(
            text: _useMagicLink ? 'Send Magic Link' : 'Sign In',
            onPressed: _login,
            isLoading: _isLoading,
            height: 54,
            icon: _useMagicLink
                ? Icons.auto_awesome_rounded
                : Icons.login_rounded,
            backgroundColor: AppTheme.darkTextColor,
          ),
          const SizedBox(height: 14),
          Text(
            _useMagicLink
                ? 'We will send a secure sign-in link to your email.'
                : 'Use your password, or switch to a passwordless email magic link.',
            style: const TextStyle(
              color: AppTheme.lightTextColor,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthModeSwitch() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: 'Password',
              selected: !_useMagicLink,
              onTap: () => setState(() => _useMagicLink = false),
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: 'Magic Link',
              selected: _useMagicLink,
              onTap: () => setState(() => _useMagicLink = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupLink() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            "New to KlubConnect? ",
            style: TextStyle(
              color: AppTheme.secondaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Choose your role',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppTheme.primaryColor : AppTheme.secondaryColor,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.74),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: 46,
          width: 46,
          child: Icon(icon, color: AppTheme.darkTextColor),
        ),
      ),
    );
  }
}

class _AuthLogo extends StatelessWidget {
  final double size;

  const _AuthLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.18),
      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEFF6FF),
            Color(0xFFF8FAFC),
            Color(0xFFEFFDF9),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -70,
            child: _SoftOrb(
                color: AppTheme.primaryColor.withValues(alpha: 0.16),
                size: 210),
          ),
          Positioned(
            bottom: 70,
            left: -100,
            child: _SoftOrb(
                color: AppTheme.accentColor.withValues(alpha: 0.13), size: 210),
          ),
        ],
      ),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _SoftOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color, blurRadius: 90, spreadRadius: 24),
        ],
      ),
    );
  }
}
