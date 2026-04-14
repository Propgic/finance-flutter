import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class ExpenseRepo {
  final ApiClient api;
  ExpenseRepo(this.api);

  Future<Map<String, dynamic>> list({int page = 1, int limit = 20, String? category, String? month}) async {
    final q = <String, dynamic>{'page': page, 'limit': limit};
    if (category?.isNotEmpty ?? false) q['category'] = category;
    if (month?.isNotEmpty ?? false) q['month'] = month;
    final res = await api.raw(() => api.dio.get('/expenses', queryParameters: q));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> summary() async {
    final d = await api.get('/expenses/summary');
    return Map<String, dynamic>.from(d as Map);
  }

  Future<List<dynamic>> categories() async {
    final d = await api.get('/expenses/categories');
    if (d is List) return d;
    if (d is Map && d['categories'] is List) return d['categories'];
    return const [];
  }

  Future<Map<String, dynamic>> get(String id) async {
    final d = await api.get('/expenses/$id');
    return Map<String, dynamic>.from(d as Map);
  }

  Future<void> create(Map<String, dynamic> body) async => api.post('/expenses', data: body);
  Future<void> update(String id, Map<String, dynamic> body) async => api.put('/expenses/$id', data: body);
  Future<void> delete(String id) async => api.delete('/expenses/$id');
}

final expenseRepoProvider = Provider<ExpenseRepo>((ref) => ExpenseRepo(ref.read(apiClientProvider)));
