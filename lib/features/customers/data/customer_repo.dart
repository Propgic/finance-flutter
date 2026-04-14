import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class CustomerRepo {
  final ApiClient api;
  CustomerRepo(this.api);

  Future<Map<String, dynamic>> list({int page = 1, int limit = 20, String? search, String? city, bool? status, bool forLoan = false}) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (city != null && city.isNotEmpty) query['city'] = city;
    if (status != null) query['status'] = status.toString();
    if (forLoan) query['forLoan'] = 'true';
    final res = await api.raw(() => api.dio.get('/customers', queryParameters: query));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> get(String id) async {
    final d = await api.get('/customers/$id');
    return Map<String, dynamic>.from(d as Map);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final d = await api.post('/customers', data: body);
    return Map<String, dynamic>.from(d as Map);
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> body) async {
    final d = await api.put('/customers/$id', data: body);
    return Map<String, dynamic>.from(d as Map);
  }

  Future<void> toggleStatus(String id) async => api.patch('/customers/$id/status');

  Future<void> delete(String id) async => api.delete('/customers/$id');

  Future<void> restore(String id) async => api.patch('/customers/$id/restore');

  Future<List<dynamic>> listDeleted() async {
    final d = await api.get('/customers/deleted');
    if (d is List) return d;
    if (d is Map && d['data'] is List) return d['data'];
    return const [];
  }

  Future<List<dynamic>> loans(String id) async {
    final d = await api.get('/customers/$id/loans');
    return (d as List?) ?? const [];
  }

  Future<List<dynamic>> savings(String id) async {
    final d = await api.get('/customers/$id/savings');
    return (d as List?) ?? const [];
  }

  Future<List<dynamic>> ledger(String id) async {
    final res = await api.raw(() => api.dio.get('/customers/$id/ledger'));
    final body = res.data;
    if (body is Map && body['data'] is List) return body['data'];
    if (body is List) return body;
    return const [];
  }
}

final customerRepoProvider = Provider<CustomerRepo>((ref) => CustomerRepo(ref.read(apiClientProvider)));
