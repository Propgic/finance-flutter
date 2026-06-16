import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/widgets/common.dart';

/// Builds a properly-escaped CSV from [headers] + [rows], writes it to a
/// temporary file, and shares it via share_plus. On any failure it surfaces
/// a toast and never throws to the caller.
Future<void> exportAndShareCsv(
  BuildContext context, {
  required String filename,
  required List<String> headers,
  required List<List<dynamic>> rows,
  String? subject,
}) async {
  try {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escapeCsvField).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCsvField).join(','));
    }

    final dir = await getTemporaryDirectory();
    final safeName = filename.endsWith('.csv') ? filename : '$filename.csv';
    final file = File('${dir.path}/$safeName');
    await file.writeAsString(buffer.toString());

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      subject: subject ?? safeName,
      text: subject ?? 'Attached report',
    ));
  } catch (e) {
    showToast('Export failed: $e', error: true);
  }
}

/// Escapes a single CSV field. Wraps the value in double quotes when it
/// contains a comma, double-quote, carriage return, or newline, and doubles
/// any internal double-quotes.
String _escapeCsvField(dynamic value) {
  final s = value == null ? '' : value.toString();
  final needsQuoting = s.contains(',') ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r');
  if (!needsQuoting) return s;
  return '"${s.replaceAll('"', '""')}"';
}
