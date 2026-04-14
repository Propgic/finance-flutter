import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class ChitfundRepo {
  final ApiClient api;
  ChitfundRepo(this.api);

  Future<Map<String, dynamic>> list({int page = 1, int limit = 20, String? search, String? status}) async {
    final q = <String, dynamic>{'page': page, 'limit': limit};
    if (search?.isNotEmpty ?? false) q['search'] = search;
    if (status?.isNotEmpty ?? false) q['status'] = status;
    final res = await api.raw(() => api.dio.get('/chitfunds', queryParameters: q));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> get(String id) async {
    final d = await api.get('/chitfunds/$id');
    return Map<String, dynamic>.from(d as Map);
  }

  Future<void> create(Map<String, dynamic> body) async => api.post('/chitfunds', data: body);
  Future<void> start(String id) async => api.patch('/chitfunds/$id/start');
  Future<void> complete(String id) async => api.patch('/chitfunds/$id/complete');

  Future<List<dynamic>> members(String id) async {
    final d = await api.get('/chitfunds/$id/members');
    if (d is List) return d;
    if (d is Map && d['data'] is List) return d['data'];
    return const [];
  }

  Future<void> addMember(String id, String customerId) async => api.post('/chitfunds/$id/members', data: {'customerId': customerId});
  Future<void> removeMember(String id, String memberId) async => api.delete('/chitfunds/$id/members/$memberId');

  Future<List<dynamic>> auctions(String id) async {
    final d = await api.get('/chitfunds/$id/auctions');
    if (d is List) return d;
    if (d is Map && d['data'] is List) return d['data'];
    return const [];
  }

  Future<void> recordAuction(String id, String auctionId, {required String winnerMemberId, required num bidAmount}) async =>
      api.patch('/chitfunds/$id/auctions/$auctionId', data: {'winnerMemberId': winnerMemberId, 'bidAmount': bidAmount});

  Future<List<dynamic>> payments(String id) async {
    final d = await api.get('/chitfunds/$id/payments');
    if (d is List) return d;
    if (d is Map && d['data'] is List) return d['data'];
    return const [];
  }

  Future<void> recordPayment(String id, Map<String, dynamic> body) async => api.post('/chitfunds/$id/payments', data: body);
}

final chitfundRepoProvider = Provider<ChitfundRepo>((ref) => ChitfundRepo(ref.read(apiClientProvider)));
