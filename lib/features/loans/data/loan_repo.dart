import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class LoanRepo {
  final ApiClient api;
  LoanRepo(this.api);

  Future<Map<String, dynamic>> list({int page = 1, int limit = 20, String? search, String? status, String? type}) async {
    final q = <String, dynamic>{'page': page, 'limit': limit};
    if (search?.isNotEmpty ?? false) q['search'] = search;
    if (status?.isNotEmpty ?? false) q['status'] = status;
    if (type?.isNotEmpty ?? false) q['loanType'] = type;
    final res = await api.raw(() => api.dio.get('/loans', queryParameters: q));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<dynamic>> overdue() async {
    final d = await api.get('/loans/overdue');
    if (d is List) return d;
    if (d is Map && d['data'] is List) return d['data'];
    return const [];
  }

  Future<Map<String, dynamic>> get(String id) async {
    final d = await api.get('/loans/$id');
    return Map<String, dynamic>.from(d as Map);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final d = await api.post('/loans', data: body);
    return Map<String, dynamic>.from(d as Map);
  }

  Future<void> update(String id, Map<String, dynamic> body) async => api.put('/loans/$id', data: body);
  Future<void> delete(String id) async => api.delete('/loans/$id');
  Future<void> disburse(String id) async => api.patch('/loans/$id/disburse');
  Future<void> reject(String id) async => api.patch('/loans/$id/reject');
  Future<void> close(String id) async => api.patch('/loans/$id/close');

  Future<Map<String, dynamic>> closureSummary(String id) async {
    final d = await api.get('/loans/$id/closure-summary');
    return Map<String, dynamic>.from(d as Map);
  }

  Future<List<dynamic>> emiSchedule(String id) async {
    final d = await api.get('/loans/$id/emi-schedule');
    if (d is List) return d;
    if (d is Map && d['data'] is List) return d['data'];
    return const [];
  }
}

final loanRepoProvider = Provider<LoanRepo>((ref) => LoanRepo(ref.read(apiClientProvider)));
