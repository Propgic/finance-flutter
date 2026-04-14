import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class SavingsRepo {
  final ApiClient api;
  SavingsRepo(this.api);

  Future<Map<String, dynamic>> list({int page = 1, int limit = 20, String? search, String? type, String? status}) async {
    final q = <String, dynamic>{'page': page, 'limit': limit};
    if (search?.isNotEmpty ?? false) q['search'] = search;
    if (type?.isNotEmpty ?? false) q['accountType'] = type;
    if (status?.isNotEmpty ?? false) q['status'] = status;
    final res = await api.raw(() => api.dio.get('/savings', queryParameters: q));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> get(String id) async {
    final d = await api.get('/savings/$id');
    return Map<String, dynamic>.from(d as Map);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final d = await api.post('/savings', data: body);
    return Map<String, dynamic>.from(d as Map);
  }

  Future<void> deposit(String id, Map<String, dynamic> body) async => api.post('/savings/$id/deposit', data: body);
  Future<void> withdraw(String id, Map<String, dynamic> body) async => api.post('/savings/$id/withdraw', data: body);
  Future<void> close(String id) async => api.patch('/savings/$id/close');

  Future<List<dynamic>> transactions(String id) async {
    final d = await api.get('/savings/$id/transactions');
    if (d is List) return d;
    if (d is Map && d['data'] is List) return d['data'];
    return const [];
  }
}

final savingsRepoProvider = Provider<SavingsRepo>((ref) => SavingsRepo(ref.read(apiClientProvider)));
