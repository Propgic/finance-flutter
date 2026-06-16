import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class LoanRepo {
  final ApiClient api;
  LoanRepo(this.api);

  Future<Map<String, dynamic>> list({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    String? type,
    String? assignedToId,
    String? fromDate,
    String? toDate,
  }) async {
    final q = <String, dynamic>{'page': page, 'limit': limit};
    if (search?.isNotEmpty ?? false) q['search'] = search;
    if (status?.isNotEmpty ?? false) q['status'] = status;
    if (type?.isNotEmpty ?? false) q['loanType'] = type;
    if (assignedToId?.isNotEmpty ?? false) q['assignedToId'] = assignedToId;
    if (fromDate?.isNotEmpty ?? false) q['fromDate'] = fromDate;
    if (toDate?.isNotEmpty ?? false) q['toDate'] = toDate;
    final res = await api.raw(() => api.dio.get('/loans', queryParameters: q));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<dynamic>> overdue({bool groupByCustomer = false}) async {
    final q = <String, dynamic>{};
    if (groupByCustomer) q['groupBy'] = 'customer';
    final res = await api.raw(() => api.dio.get('/loans/overdue', queryParameters: q));
    final body = res.data;
    if (body is Map && body['data'] is List) return body['data'];
    if (body is List) return body;
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

  /// Uploads one or more loan documents in a single multipart request.
  /// Backend route: POST /loans/:id/documents (upload.array('documents', 10)).
  /// The file title defaults to the filename (matches the web's `titles` field).
  Future<void> uploadDocuments(String id, List<File> files) async {
    final form = FormData();
    for (final f in files) {
      final name = f.path.split(Platform.pathSeparator).last;
      form.files.add(MapEntry('documents', await MultipartFile.fromFile(f.path, filename: name)));
      form.fields.add(MapEntry('titles', name.replaceFirst(RegExp(r'\.[^/.]+$'), '')));
    }
    await api.post('/loans/$id/documents', data: form);
  }

  /// Removes the document at [index] (DELETE /loans/:id/documents/:docIndex).
  Future<void> deleteDocument(String id, int index) async => api.delete('/loans/$id/documents/$index');

  /// Renames the document at [index] (PUT /loans/:id/documents/:docIndex { title }).
  Future<void> renameDocument(String id, int index, String title) async =>
      api.put('/loans/$id/documents/$index', data: {'title': title});
}

final loanRepoProvider = Provider<LoanRepo>((ref) => LoanRepo(ref.read(apiClientProvider)));
