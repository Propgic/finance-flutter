import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secure = FlutterSecureStorage();

/// One stored sign-in: a (login identity x organization) pair with its own
/// token bundle. The non-sensitive profile (user + org) lives in
/// SharedPreferences; the access/refresh tokens live in the OS keychain.
///
/// [id] is `"<userId>:<orgId>"`, so re-logging in or switching back to the same
/// (login x org) updates the existing entry in place rather than duplicating it.
class StoredAccount {
  final String id;
  final String phone; // login phone — display + re-auth hint
  final Map<String, dynamic> user; // raw AuthUser json
  final Map<String, dynamic> org; // raw AuthOrg json

  StoredAccount({
    required this.id,
    required this.phone,
    required this.user,
    required this.org,
  });

  String get userId => (user['id'] ?? '').toString();
  String get orgId => (org['id'] ?? '').toString();
  String get userName => (user['name'] ?? '').toString();
  String get role => (user['role'] ?? '').toString();
  String get orgName => (org['name'] ?? '').toString();
  String? get orgLogo => org['logo']?.toString();

  Map<String, dynamic> toJson() => {'id': id, 'phone': phone, 'user': user, 'org': org};

  factory StoredAccount.fromJson(Map<String, dynamic> j) => StoredAccount(
        id: j['id'].toString(),
        phone: (j['phone'] ?? '').toString(),
        user: Map<String, dynamic>.from(j['user'] as Map),
        org: Map<String, dynamic>.from(j['org'] as Map),
      );
}

/// Persistence for the Outlook-style multi-account switcher. All reads/writes
/// go through here so the rest of the app never touches raw keys.
class AccountStore {
  static const _kAccounts = 'accounts'; // prefs: JSON list of StoredAccount
  static const _kActiveId = 'active_account_id'; // prefs: String
  static const _kTokens = 'account_tokens'; // secure: { id: {access, refresh} }

  // Legacy single-session keys (installs from before multi-account).
  static const _kLegacyAccess = 'access_token';
  static const _kLegacyRefresh = 'refresh_token';

  static String accountId(String userId, String orgId) => '$userId:$orgId';

  // ---- account profiles (prefs) ----

  static Future<List<StoredAccount>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAccounts);
    if (raw == null || raw.isEmpty) return [];
    try {
      final arr = jsonDecode(raw) as List;
      return arr
          .map((e) => StoredAccount.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveList(List<StoredAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccounts, jsonEncode(accounts.map((a) => a.toJson()).toList()));
  }

  static Future<String?> activeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActiveId);
  }

  static Future<void> setActive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveId, id);
  }

  // ---- tokens (secure) ----

  static Future<Map<String, dynamic>> _allTokens() async {
    final raw = await _secure.read(key: _kTokens);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeAllTokens(Map<String, dynamic> map) async {
    await _secure.write(key: _kTokens, value: jsonEncode(map));
  }

  static Future<({String? access, String? refresh})> tokensFor(String id) async {
    final t = (await _allTokens())[id];
    if (t is Map) {
      return (access: t['access']?.toString(), refresh: t['refresh']?.toString());
    }
    return (access: null, refresh: null);
  }

  static Future<void> setTokens(String id, {String? access, String? refresh}) async {
    final all = await _allTokens();
    final cur = (all[id] is Map) ? Map<String, dynamic>.from(all[id] as Map) : <String, dynamic>{};
    if (access != null) cur['access'] = access;
    if (refresh != null) cur['refresh'] = refresh;
    all[id] = cur;
    await _writeAllTokens(all);
  }

  static Future<void> clearTokens(String id) async {
    final all = await _allTokens();
    all.remove(id);
    await _writeAllTokens(all);
  }

  // ---- mutations ----

  /// Insert or update an account profile (+ optional tokens), deduped by id.
  static Future<void> upsert({
    required StoredAccount account,
    String? access,
    String? refresh,
    bool makeActive = true,
  }) async {
    final all = await list();
    final idx = all.indexWhere((a) => a.id == account.id);
    if (idx >= 0) {
      all[idx] = account;
    } else {
      all.add(account);
    }
    await _saveList(all);
    if (access != null || refresh != null) {
      await setTokens(account.id, access: access, refresh: refresh);
    }
    if (makeActive) await setActive(account.id);
  }

  /// Remove an account's profile + tokens. If it was the active one, the active
  /// pointer is cleared (the caller picks the next active account).
  static Future<void> remove(String id) async {
    final all = await list();
    all.removeWhere((a) => a.id == id);
    await _saveList(all);
    await clearTokens(id);
    if (await activeId() == id) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kActiveId);
    }
  }

  /// Update the active account's stored profile in place (after /auth/me or a
  /// profile edit). Tokens and active pointer are untouched.
  static Future<void> updateActiveProfile({
    Map<String, dynamic>? user,
    Map<String, dynamic>? org,
  }) async {
    final id = await activeId();
    if (id == null) return;
    final all = await list();
    final idx = all.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    final cur = all[idx];
    all[idx] = StoredAccount(
      id: cur.id,
      phone: cur.phone,
      user: user ?? cur.user,
      org: org ?? cur.org,
    );
    await _saveList(all);
  }

  /// One-time upgrade of a legacy single-session install into the multi-account
  /// store. No-op once any account exists. Returns true if a session migrated.
  static Future<bool> migrateFromLegacy() async {
    if ((await list()).isNotEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    final orgStr = prefs.getString('org');
    final access = (await _secure.read(key: _kLegacyAccess)) ?? prefs.getString('token');
    final refresh = await _secure.read(key: _kLegacyRefresh);
    if (userStr == null || orgStr == null || access == null || access.isEmpty) return false;
    try {
      final user = Map<String, dynamic>.from(jsonDecode(userStr) as Map);
      final org = Map<String, dynamic>.from(jsonDecode(orgStr) as Map);
      final id = accountId(user['id'].toString(), org['id'].toString());
      await upsert(
        account: StoredAccount(
          id: id,
          phone: (user['phone'] ?? '').toString(),
          user: user,
          org: org,
        ),
        access: access,
        refresh: refresh,
        makeActive: true,
      );
      // Tear down legacy storage now that it lives in the account store.
      await _secure.delete(key: _kLegacyAccess);
      await _secure.delete(key: _kLegacyRefresh);
      await prefs.remove('token');
      await prefs.remove('user');
      await prefs.remove('org');
      await prefs.remove('permissions');
      return true;
    } catch (_) {
      return false;
    }
  }
}
