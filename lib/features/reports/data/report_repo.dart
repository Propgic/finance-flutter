import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class ReportRepo {
  final ApiClient api;
  ReportRepo(this.api);

  Future<Map<String, dynamic>> fetch(String path, {Map<String, dynamic>? params}) async {
    final d = await api.get('/reports/$path', query: params);
    return Map<String, dynamic>.from(d as Map);
  }
}

final reportRepoProvider = Provider<ReportRepo>((ref) => ReportRepo(ref.read(apiClientProvider)));
