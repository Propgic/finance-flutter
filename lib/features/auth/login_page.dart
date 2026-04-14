import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/biometric_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  List<Map<String, dynamic>>? _accounts;
  bool _bioAvailable = false;
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBio();
  }

  Future<void> _checkBio() async {
    final bio = ref.read(biometricServiceProvider);
    final avail = await bio.isAvailable();
    final enabled = await bio.hasSavedCredentials();
    if (mounted) setState(() { _bioAvailable = avail; _bioEnabled = enabled; });
    if (avail && enabled) {
      // Auto-prompt biometric on load
      Future.delayed(const Duration(milliseconds: 300), _biometricLogin);
    }
  }

  Future<void> _biometricLogin() async {
    if (_loading) return;
    final bio = ref.read(biometricServiceProvider);
    final creds = await bio.authenticate(reason: 'Sign in to Rupit Financer');
    if (creds == null) return;
    _phone.text = creds.phone;
    _password.text = creds.password;
    await _submit(fromBiometric: true);
  }

  Future<void> _maybeOfferEnableBio() async {
    if (!_bioAvailable || _bioEnabled) return;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable Biometric Login?'),
        content: const Text('Sign in instantly next time using Face ID / Fingerprint.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enable')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(biometricServiceProvider).enable(phone: _phone.text.trim(), password: _password.text);
      showToast('Biometric login enabled');
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit({bool fromBiometric = false}) async {
    if (_phone.text.trim().isEmpty || _password.text.isEmpty) {
      showToast('Enter phone and password', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final ctrl = ref.read(authProvider.notifier);
      final accs = await ctrl.loginStep1(_phone.text.trim(), _password.text);
      if (accs.isNotEmpty) {
        setState(() => _accounts = accs);
      } else if (!fromBiometric) {
        // Single-org login completed
        await _maybeOfferEnableBio();
      }
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } catch (e) {
      showToast('Login failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectOrg(String orgId) async {
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).loginStep2(
            phone: _phone.text.trim(),
            password: _password.text,
            orgId: orgId,
          );
      await _maybeOfferEnableBio();
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.loginBg),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _brandHeader(),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Card(
                      elevation: 8,
                      shadowColor: Colors.black.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: _accounts != null ? _orgSelect() : _loginForm(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Powered by Rupit from Zyptr Labs',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: SvgPicture.asset('assets/logo.svg', width: 48, height: 48),
        ),
        const SizedBox(height: 12),
        const Text(
          'Rupit',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage your finances smarter',
          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
        ),
      ],
    );
  }

  Widget _loginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Welcome back', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Sign in to continue', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: !_showPassword,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        if (_bioAvailable && _bioEnabled) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _loading ? null : _biometricLogin,
            icon: const Icon(Icons.fingerprint, size: 22),
            label: const Text('Unlock with Biometrics'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ],
    );
  }

  Widget _orgSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _loading ? null : () => setState(() => _accounts = null),
              icon: const Icon(Icons.arrow_back, size: 20),
              style: IconButton.styleFrom(padding: EdgeInsets.zero),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Organization', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  Text('Choose which to sign into', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._accounts!.map((acc) {
          final logo = resolveUrl(acc['logo']?.toString());
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _loading ? null : () => _selectOrg(acc['orgId'].toString()),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      foregroundImage: logo != null ? CachedNetworkImageProvider(logo) : null,
                      child: Text(
                        (acc['name']?.toString() ?? '?').substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(acc['name']?.toString() ?? '-',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(acc['role']?.toString() ?? '',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
