import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class SearchRepo {
  final ApiClient api;
  SearchRepo(this.api);

  /// Cross-entity global search.
  ///
  /// Hits `GET /search?q=<query>` and returns the grouped result map with
  /// keys `customers`, `loans`, `team`, `savings` (each a `List`).
  /// The backend returns empty groups for queries shorter than 2 chars.
  Future<Map<String, dynamic>> search(String q) async {
    final d = await api.get('/search', query: {'q': q});
    if (d is Map) return Map<String, dynamic>.from(d);
    return const {'customers': [], 'loans': [], 'team': [], 'savings': []};
  }
}

final searchRepoProvider = Provider<SearchRepo>((ref) => SearchRepo(ref.read(apiClientProvider)));
