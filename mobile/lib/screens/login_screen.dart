import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/premium_provider.dart';
import '../config/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.timer_outlined, size: 64, color: AppTheme.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Freelance Hub',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Track time, manage expenses, simplify taxes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 40),
                  if (!_isLogin)
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                    ),
                  if (!_isLogin) const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) {
                      final email = v?.trim() ?? '';
                      if (email.isEmpty) return 'Email is required';
                      if (!RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email)) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) {
                      final pwd = v ?? '';
                      if (pwd.isEmpty) return 'Password is required';
                      if (pwd.length < 8) return 'Password must be at least 8 characters';
                      if (!RegExp(r'[A-Za-z]').hasMatch(pwd)) return 'Password must contain at least one letter';
                      if (!RegExp(r'[0-9]').hasMatch(pwd)) return 'Password must contain at least one number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_error!, style: const TextStyle(color: AppTheme.danger)),
                    ),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_isLogin ? 'Sign In' : 'Create Account', style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() {
                      _isLogin = !_isLogin;
                      _error = null;
                    }),
                    child: Text(_isLogin ? "Don't have an account? Sign Up" : 'Already have an account? Sign In'),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      // 跳过登录，使用本地模式
                      Navigator.pushReplacementNamed(context, '/dashboard');
                    },
                    child: const Text('Continue without account (local only)'),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_outlined, size: 16, color: AppTheme.textSecondary),
                      SizedBox(width: 6),
                      Text(
                        'Sign in to enable cloud sync (Annual plan)',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    try {
      if (_isLogin) {
        await auth.login(_emailController.text, _passwordController.text);
      } else {
        await auth.register(_emailController.text, _passwordController.text, _nameController.text.trim());
      }
      await _syncPremium(context);
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Associates purchases with the authenticated account, then applies the
  /// server entitlement cache while RevenueCat webhook updates propagate.
  Future<void> _syncPremium(BuildContext context) async {
    final user = context.read<AuthProvider>().user;
    final premium = context.read<PremiumProvider>();
    if (user == null) return;
    await premium.identifyUser(user.userId);
    premium.applyServerEntitlement(
      premiumType: user.premiumType,
      expireTime: user.expireTime,
      trialEndTime: user.trialEndTime,
    );
  }
}
