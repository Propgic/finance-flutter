import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import 'auth_models.dart';
import 'biometric_service.dart';

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _bootstrap();
    return const AuthState(loading: true);
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userStr = prefs.getString('user');
    final orgStr = prefs.getString('org');
    if (token == null || userStr == null || orgStr == null) {
      state = const AuthState(loading: false);
      return;
    }
    try {
      final user = AuthUser.fromJson(jsonDecode(userStr) as Map<String, dynamic>);
      final org = AuthOrg.fromJson(jsonDecode(orgStr) as Map<String, dynamic>);
      state = AuthState(user: user, org: org, token: token, loading: false);
      // refresh /me in background
      _refreshMe();
    } catch (_) {
      await _clear();
    }
  }

  Future<void> refreshMe() => _refreshMe();

  Future<void> _refreshMe() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/auth/me') as Map<String, dynamic>;
      final user = AuthUser.fromJson(Map<String, dynamic>.from(data['user']));
      final org = AuthOrg.fromJson(Map<String, dynamic>.from(data['org']));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(user.toJson()));
      await prefs.setString('org', jsonEncode(org.toJson()));
      state = state.copyWith(user: user, org: org);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> loginStep1(String phone, String password) async {
    final api = ref.read(apiClientProvider);
    final data = await api.post('/auth/login', data: {'phone': phone, 'password': password});
    if (data is Map && data['multipleAccounts'] == true) {
      final accs = (data['accounts'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return accs;
    }
    await _persistLogin(Map<String, dynamic>.from(data as Map));
    return [];
  }

  Future<void> loginStep2({required String phone, required String password, required String orgId}) async {
    final api = ref.read(apiClientProvider);
    final data = await api.post('/auth/login', data: {'phone': phone, 'password': password, 'orgId': orgId});
    await _persistLogin(Map<String, dynamic>.from(data as Map));
  }

  Future<void> _persistLogin(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    final user = AuthUser.fromJson(Map<String, dynamic>.from(data['user']));
    final org = AuthOrg.fromJson(Map<String, dynamic>.from(data['org']));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('user', jsonEncode(user.toJson()));
    await prefs.setString('org', jsonEncode(org.toJson()));
    state = AuthState(token: token, user: user, org: org, loading: false);
  }

  Future<void> logout() async {
    await _clear();
  }

  Future<void> _clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('org');
    await prefs.remove('permissions');
    // Disable biometric login on logout so next login is a full sign-in
    await ref.read(biometricServiceProvider).disable();
    state = const AuthState(loading: false);
  }

  Future<void> updateOrgFeatures(Map<String, bool> features) async {
    if (state.org == null) return;
    final updated = AuthOrg(
      id: state.org!.id,
      slug: state.org!.slug,
      name: state.org!.name,
      logo: state.org!.logo,
      features: {...state.org!.features, ...features},
      menuOrder: state.org!.menuOrder,
      subscriptionStatus: state.org!.subscriptionStatus,
      renewalDate: state.org!.renewalDate,
      billingCycle: state.org!.billingCycle,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('org', jsonEncode(updated.toJson()));
    state = state.copyWith(org: updated);
  }

  Future<void> updateProfilePhoto(String? photo, {String? name, String? phone}) async {
    if (state.user == null) return;
    final updated = AuthUser(
      id: state.user!.id,
      email: state.user!.email,
      name: name ?? state.user!.name,
      role: state.user!.role,
      phone: phone ?? state.user!.phone,
      photo: photo ?? state.user!.photo,
      permissions: state.user!.permissions,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(updated.toJson()));
    state = state.copyWith(user: updated);
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
