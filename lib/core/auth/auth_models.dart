class AuthUser {
  final String id;
  final String email;
  final String name;
  final String role;
  final String? phone;
  final String? photo;
  final List<String> permissions;

  AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.photo,
    this.permissions = const [],
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'].toString(),
        email: j['email'] ?? '',
        name: j['name'] ?? '',
        role: j['role'] ?? '',
        phone: j['phone'],
        photo: j['photo'],
        permissions: (j['permissions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role,
        'phone': phone,
        'photo': photo,
        'permissions': permissions,
      };
}

class AuthOrg {
  final String id;
  final String slug;
  final String name;
  final String? logo;
  final Map<String, bool> features;
  final List<String>? menuOrder;
  final String? subscriptionStatus;
  final String? renewalDate;
  final String? billingCycle;

  AuthOrg({
    required this.id,
    required this.slug,
    required this.name,
    this.logo,
    required this.features,
    this.menuOrder,
    this.subscriptionStatus,
    this.renewalDate,
    this.billingCycle,
  });

  factory AuthOrg.fromJson(Map<String, dynamic> j) {
    final feats = <String, bool>{};
    final f = j['features'];
    if (f is Map) {
      f.forEach((k, v) => feats[k.toString()] = v == true);
    }
    List<String>? menu;
    if (j['menuOrder'] is List) {
      menu = (j['menuOrder'] as List).map((e) => e.toString()).toList();
    }
    return AuthOrg(
      id: j['id'].toString(),
      slug: j['slug']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      logo: j['logo']?.toString(),
      features: feats,
      menuOrder: menu,
      subscriptionStatus: j['subscriptionStatus']?.toString(),
      renewalDate: j['renewalDate']?.toString(),
      billingCycle: j['billingCycle']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'logo': logo,
        'features': features,
        'menuOrder': menuOrder,
        'subscriptionStatus': subscriptionStatus,
        'renewalDate': renewalDate,
        'billingCycle': billingCycle,
      };

  bool feature(String key) => features[key] == true;
}

class AuthState {
  final AuthUser? user;
  final AuthOrg? org;
  final String? token;
  final bool loading;

  const AuthState({this.user, this.org, this.token, this.loading = true});

  bool get isAuthed => token != null && user != null && org != null;

  AuthState copyWith({AuthUser? user, AuthOrg? org, String? token, bool? loading, bool clear = false}) {
    if (clear) return const AuthState(loading: false);
    return AuthState(
      user: user ?? this.user,
      org: org ?? this.org,
      token: token ?? this.token,
      loading: loading ?? this.loading,
    );
  }

  bool hasPermission(String perm) {
    if (user == null) return false;
    if (user!.role == 'ORG_ADMIN') return true;
    return user!.permissions.contains(perm);
  }

  bool hasRole(String role) => user?.role == role;
}
