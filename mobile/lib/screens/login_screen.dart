import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/premium_provider.dart';
import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';

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
                  Text(
                    AppLocalizations.t('appTitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.t('loginTagline'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 40),
                  if (!_isLogin)
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: AppLocalizations.t('name')),
                      validator: (v) => (v == null || v.trim().isEmpty) ? AppLocalizations.t('errors.nameRequired') : null,
                    ),
                  if (!_isLogin) const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: AppLocalizations.t('email')),
                    keyboardType: TextInputType.emailAddress,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) {
                      final email = v?.trim() ?? '';
                      if (email.isEmpty) return AppLocalizations.t('errors.emailRequired');
                      if (!RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email)) {
                        return AppLocalizations.t('errors.invalidEmail');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: AppLocalizations.t('password')),
                    obscureText: true,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) {
                      final pwd = v ?? '';
                      if (pwd.isEmpty) return AppLocalizations.t('errors.passwordRequired');
                      if (pwd.length < 8) return AppLocalizations.t('errors.passwordTooShort');
                      if (!RegExp(r'[A-Za-z]').hasMatch(pwd)) return AppLocalizations.t('errors.passwordRequiresLetter');
                      if (!RegExp(r'[0-9]').hasMatch(pwd)) return AppLocalizations.t('errors.passwordRequiresNumber');
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
                          : Text(_isLogin ? AppLocalizations.t('login') : AppLocalizations.t('createAccount'), style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() {
                      _isLogin = !_isLogin;
                      _error = null;
                    }),
                    child: Text(_isLogin ? "${AppLocalizations.t('noAccount')} ${AppLocalizations.t('register')}" : "${AppLocalizations.t('haveAccount')} ${AppLocalizations.t('login')}"),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      // 跳过登录，使用本地模式
                      Navigator.pushReplacementNamed(context, '/dashboard');
                    },
                    child: Text(AppLocalizations.t('continueWithoutAccount')),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_outlined, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.t('cloudSyncHint'),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
      String msg;
      try {
        msg = (e as dynamic).message as String;
      } catch (_) {
        msg = e.toString();
      }
      setState(() => _error = msg);
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
