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
  Future<void> update(String id, Map<String, dynamic> body) async => api.put('/chitfunds/$id', data: body);
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

  Future<Map<String, dynamic>> auctionDetail(String id, String auctionId) async {
    final d = await api.get('/chitfunds/$id/auctions/$auctionId');
    return Map<String, dynamic>.from(d as Map);
  }

  Future<void> extraAuction(String id, {required String winnerMemberId, required num bidAmount}) async =>
      api.post('/chitfunds/$id/extra-auction', data: {'winnerMemberId': winnerMemberId, 'bidAmount': bidAmount});

  Future<void> reverseAuction(String id, String auctionId) async =>
      api.post('/chitfunds/$id/auctions/$auctionId/reverse');

  Future<Map<String, dynamic>> monthlyDues(String id, int monthNumber) async {
    final d = await api.get('/chitfunds/$id/monthly-dues/$monthNumber');
    return Map<String, dynamic>.from(d as Map);
  }

  Future<Map<String, dynamic>> finalDues(String id) async {
    final d = await api.get('/chitfunds/$id/final-dues');
    return Map<String, dynamic>.from(d as Map);
  }

  Future<List<dynamic>> payments(String id, {int? monthNumber, String? memberId, String? type, String? status}) async {
    final q = <String, dynamic>{};
    if (monthNumber != null) q['monthNumber'] = monthNumber;
    if (memberId != null) q['memberId'] = memberId;
    if (type != null) q['type'] = type;
    if (status != null) q['status'] = status;
    final d = await api.get('/chitfunds/$id/payments', query: q.isEmpty ? null : q);
    if (d is List) return d;
    if (d is Map && d['data'] is List) return d['data'];
    return const [];
  }

  Future<void> recordPayment(String id, Map<String, dynamic> body) async => api.post('/chitfunds/$id/payments', data: body);

  Future<void> deletePayment(String id, String paymentId) async => api.delete('/chitfunds/$id/payments/$paymentId');

  Future<List<dynamic>> payouts(String id) async {
    final d = await api.get('/chitfunds/$id/payouts');
    if (d is List) return d;
    if (d is Map && d['data'] is List) return d['data'];
    return const [];
  }

  Future<void> settlePayout(String id, String payoutId, Map<String, dynamic> body) async =>
      api.patch('/chitfunds/$id/payouts/$payoutId/settle', data: body);

  Future<void> unsettlePayout(String id, String payoutId) async =>
      api.patch('/chitfunds/$id/payouts/$payoutId/unsettle');
}

final chitfundRepoProvider = Provider<ChitfundRepo>((ref) => ChitfundRepo(ref.read(apiClientProvider)));
