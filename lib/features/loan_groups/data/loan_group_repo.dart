import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class LoanGroupRepo {
  final ApiClient api;
  LoanGroupRepo(this.api);

  Future<Map<String, dynamic>> list({int page = 1, int limit = 20, String? search}) async {
    final q = <String, dynamic>{'page': page, 'limit': limit};
    if (search?.isNotEmpty ?? false) q['search'] = search;
    final res = await api.raw(() => api.dio.get('/loan-groups', queryParameters: q));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> get(String id) async {
    final d = await api.get('/loan-groups/$id');
    return Map<String, dynamic>.from(d as Map);
  }

  Future<List<dynamic>> loans(String id) async {
    final d = await api.get('/loan-groups/$id/loans');
    if (d is List) return d;
    if (d is Map && d['data'] is List) return d['data'];
    return const [];
  }

  Future<void> create(Map<String, dynamic> body) async => api.post('/loan-groups', data: body);
  Future<void> update(String id, Map<String, dynamic> body) async => api.put('/loan-groups/$id', data: body);
  Future<void> toggleStatus(String id) async => api.patch('/loan-groups/$id/status');
  Future<void> removeLoan(String id, String loanId) async => api.delete('/loan-groups/$id/loans/$loanId');
  Future<void> assignLoans(String id, List<String> loanIds) async => api.post('/loan-groups/$id/loans', data: {'loanIds': loanIds});
}

final loanGroupRepoProvider = Provider<LoanGroupRepo>((ref) => LoanGroupRepo(ref.read(apiClientProvider)));
