import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
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

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _accounts != null ? _buildOrgSelect() : _buildLoginForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.account_balance, color: AppColors.primary, size: 40),
        ).asCenter(),
        const SizedBox(height: 18),
        const Text('Finance', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Sign in to your account', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 32),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
        ),
        const SizedBox(height: 14),
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
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Sign In'),
        ),
      ],
    );
  }

  Widget _buildOrgSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        const Text('Select Organization',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Choose which organization to sign in to',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        ..._accounts!.map((acc) {
          final logo = resolveUrl(acc['logo']?.toString());
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                foregroundImage: logo != null ? CachedNetworkImageProvider(logo) : null,
                child: Text(
                  (acc['name']?.toString() ?? '?').substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
              title: Text(acc['name']?.toString() ?? '-'),
              subtitle: Text(acc['role']?.toString() ?? ''),
              trailing: const Icon(Icons.chevron_right),
              onTap: _loading ? null : () => _selectOrg(acc['orgId'].toString()),
            ),
          );
        }),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _loading ? null : () => setState(() => _accounts = null),
          child: const Text('Back'),
        ),
      ],
    );
  }
}

extension _CenterExt on Widget {
  Widget asCenter() => Center(child: this);
}
