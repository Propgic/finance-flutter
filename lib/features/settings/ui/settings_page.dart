import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../app_shell.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _companyName = TextEditingController();
  final _tagline = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _receiptPrefix = TextEditingController();
  final _loanPrefix = TextEditingController();
  final _defaultRate = TextEditingController();
  final _defaultLateFee = TextEditingController();
  bool _hydrated = false;
  Map<String, dynamic>? _settings;
  Map<String, dynamic>? _features;
  Object? _error;
  bool _loading = true;
  bool _saving = false;
  File? _logoFile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.get('/settings'),
        api.get('/settings/features'),
      ]);
      final s = Map<String, dynamic>.from(results[0] as Map);
      final f = Map<String, dynamic>.from(results[1] as Map);
      if (!_hydrated) {
        _companyName.text = s['companyName']?.toString() ?? '';
        _tagline.text = s['tagline']?.toString() ?? '';
        _address.text = s['address']?.toString() ?? '';
        _phone.text = s['phone']?.toString() ?? '';
        _receiptPrefix.text = s['receiptPrefix']?.toString() ?? '';
        _loanPrefix.text = s['loanNumberPrefix']?.toString() ?? '';
        _defaultRate.text = s['defaultInterestRate']?.toString() ?? '';
        _defaultLateFee.text = s['defaultLateFee']?.toString() ?? '';
        _hydrated = true;
      }
      if (mounted) setState(() { _settings = s; _features = f; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e; _loading = false; });
    }
  }

  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    if (x != null) setState(() => _logoFile = File(x.path));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/settings', data: {
        'companyName': _companyName.text.trim(),
        'tagline': _tagline.text.trim(),
        'address': _address.text.trim(),
        'phone': _phone.text.trim(),
        'receiptPrefix': _receiptPrefix.text.trim(),
        'loanNumberPrefix': _loanPrefix.text.trim(),
        if (_defaultRate.text.trim().isNotEmpty) 'defaultInterestRate': double.tryParse(_defaultRate.text.trim()),
        if (_defaultLateFee.text.trim().isNotEmpty) 'defaultLateFee': double.tryParse(_defaultLateFee.text.trim()),
      });
      if (_logoFile != null) {
        final form = FormData.fromMap({'logo': await MultipartFile.fromFile(_logoFile!.path)});
        await api.post('/settings/logo', data: form);
      }
      showToast('Settings saved');
      _load();
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleFeature(String key, bool value) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.put('/settings/features', data: {key: value}) as Map;
      final org = Map<String, dynamic>.from(res['org'] ?? {});
      final features = Map<String, dynamic>.from(org['features'] ?? {});
      final boolFeatures = <String, bool>{for (final e in features.entries) e.key: e.value == true};
      await ref.read(authProvider.notifier).updateOrgFeatures(boolFeatures);
      _load();
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Settings'),
        leading: Builder(
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Roles & Permissions',
            onPressed: () => context.push('/settings/roles'),
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error.toString(), onRetry: _load)
              : _buildBody(_settings ?? const {}, _features ?? const {}),
    );
  }

  Widget _buildBody(Map<String, dynamic> s, Map<String, dynamic> f) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        SectionCard(
          title: 'Branding',
          child: Column(
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: _pickLogo,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: _logoFile != null
                          ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_logoFile!, fit: BoxFit.cover))
                          : const Icon(Icons.image_outlined, size: 32, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.upload),
                      label: const Text('Choose Logo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: _companyName, decoration: const InputDecoration(labelText: 'Company Name')),
              const SizedBox(height: 10),
              TextField(controller: _tagline, decoration: const InputDecoration(labelText: 'Tagline')),
              const SizedBox(height: 10),
              TextField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 10),
              TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
            ],
          ),
        ),
        SectionCard(
          title: 'Defaults',
          child: Column(
            children: [
              TextField(controller: _receiptPrefix, decoration: const InputDecoration(labelText: 'Receipt Prefix')),
              const SizedBox(height: 10),
              TextField(controller: _loanPrefix, decoration: const InputDecoration(labelText: 'Loan Number Prefix')),
              const SizedBox(height: 10),
              TextField(controller: _defaultRate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Default Interest Rate (%)')),
              const SizedBox(height: 10),
              TextField(controller: _defaultLateFee, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Default Late Fee')),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save Settings'),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Features',
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Customer Portal'),
                subtitle: const Text('Allow customers to login via self-service portal'),
                contentPadding: EdgeInsets.zero,
                value: f['enableCustomerPortal'] == true,
                onChanged: (v) => _toggleFeature('enableCustomerPortal', v),
              ),
              const Divider(),
              _featureReadOnly('Loans', f['enableLoans'] == true),
              _featureReadOnly('Savings', f['enableSavings'] == true),
              _featureReadOnly('Chitfunds', f['enableChitfund'] == true),
              _featureReadOnly('Investments', f['enableInvestments'] == true),
              _featureReadOnly('Reports', f['enableReports'] == true),
              _featureReadOnly('Group Loans', f['enableGroupLoan'] == true),
              const SizedBox(height: 8),
              const Text(
                'Contact support to enable/disable module features.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _featureReadOnly(String name, bool enabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(enabled ? Icons.check_circle : Icons.cancel_outlined,
              color: enabled ? AppColors.accent : AppColors.textSecondary, size: 18),
          const SizedBox(width: 10),
          Text(name),
          const Spacer(),
          StatusChip(label: enabled ? 'ENABLED' : 'DISABLED', color: enabled ? AppColors.accent : AppColors.textSecondary),
        ],
      ),
    );
  }
}
