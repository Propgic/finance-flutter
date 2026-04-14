import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../app_shell.dart';
import '../../core/widgets/app_bottom_nav.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  File? _photoFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authProvider).user;
    _name.text = u?.name ?? '';
    _phone.text = u?.phone ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 80);
    if (x != null) setState(() => _photoFile = File(x.path));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final form = FormData.fromMap({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        if (_photoFile != null) 'photo': await MultipartFile.fromFile(_photoFile!.path),
      });
      final api = ref.read(apiClientProvider);
      final data = await api.put('/profile', data: form) as Map;
      final user = Map<String, dynamic>.from(data['user'] ?? data);
      await ref.read(authProvider.notifier).updateProfilePhoto(
            user['photo']?.toString(),
            name: user['name']?.toString(),
            phone: user['phone']?.toString(),
          );
      setState(() => _photoFile = null);
      showToast('Profile updated');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Current')),
            const SizedBox(height: 10),
            TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'New')),
            const SizedBox(height: 10),
            TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Change')),
        ],
      ),
    );
    if (ok != true) return;
    if (next.text != confirm.text) {
      showToast('Passwords do not match', error: true);
      return;
    }
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/profile/change-password', data: {
        'currentPassword': current.text,
        'newPassword': next.text,
      });
      showToast('Password changed');
    } on ApiException catch (e) {
      showToast(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final org = ref.watch(authProvider).org;
    return Scaffold(
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: const Text('Profile'),
        leading: Builder(
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: _photoFile != null ? FileImage(_photoFile!) : null,
                  child: _photoFile == null
                      ? Avatar(url: user?.photo, name: user?.name ?? '', size: 96)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: _pickPhoto,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: 'Personal Information',
            child: Column(
              children: [
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 12),
                TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 12),
                TextField(
                  enabled: false,
                  decoration: InputDecoration(labelText: 'Email', hintText: user?.email ?? ''),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Organization',
            child: Column(
              children: [
                KeyValueRow(label: 'Organization', value: org?.name ?? '-'),
                KeyValueRow(label: 'Role', value: user?.role ?? '-'),
                KeyValueRow(label: 'Plan', value: org?.subscriptionStatus ?? '-'),
              ],
            ),
          ),
          SectionCard(
            title: 'Security',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change Password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _changePassword,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await confirmDialog(context, message: 'Sign out of your account?', destructive: true, confirmText: 'Logout');
              if (!ok) return;
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout, color: AppColors.danger),
            label: const Text('Logout', style: TextStyle(color: AppColors.danger)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
