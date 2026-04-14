import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class CollectionRepo {
  final ApiClient api;
  CollectionRepo(this.api);

  Future<Map<String, dynamic>> list({int page = 1, int limit = 20, String? search, String? status, String? verificationStatus, String? date}) async {
    final q = <String, dynamic>{'page': page, 'limit': limit};
    if (search?.isNotEmpty ?? false) q['search'] = search;
    if (verificationStatus?.isNotEmpty ?? false) q['verificationStatus'] = verificationStatus;
    if (date?.isNotEmpty ?? false) q['date'] = date;
    final res = await api.raw(() => api.dio.get('/collections', queryParameters: q));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> dailySummary({String? date}) async {
    final q = <String, dynamic>{};
    if (date?.isNotEmpty ?? false) q['date'] = date;
    final d = await api.get('/collections/daily-summary', query: q);
    return Map<String, dynamic>.from(d as Map);
  }

  Future<List<dynamic>> pendingVerifications() async {
    final d = await api.get('/collections/pending-verification');
    if (d is List) return d;
    if (d is Map && d['data'] is List) return d['data'];
    return const [];
  }

  Future<Map<String, dynamic>> get(String id) async {
    final d = await api.get('/collections/$id');
    return Map<String, dynamic>.from(d as Map);
  }

  Future<Map<String, dynamic>> getReceipt(String id) async {
    final d = await api.get('/collections/$id/receipt');
    return Map<String, dynamic>.from(d as Map);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final d = await api.post('/collections', data: body);
    return Map<String, dynamic>.from(d as Map);
  }

  Future<void> createGroup(Map<String, dynamic> body) async => api.post('/collections/group', data: body);

  Future<void> verify(String id, {required bool approve, String? remarks}) async {
    await api.patch('/collections/$id/verify', data: {'approve': approve, if (remarks != null) 'remarks': remarks});
  }
}

final collectionRepoProvider = Provider<CollectionRepo>((ref) => CollectionRepo(ref.read(apiClientProvider)));
