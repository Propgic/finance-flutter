import 'package:intl/intl.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _inrDec = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _dateFmt = DateFormat('dd MMM yyyy');
final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');
final _inputDate = DateFormat('yyyy-MM-dd');

String formatCurrency(dynamic v, {bool decimals = false}) {
  if (v == null) return '-';
  num? n;
  if (v is num) {
    n = v;
  } else {
    n = num.tryParse(v.toString());
  }
  if (n == null) return '-';
  return (decimals ? _inrDec : _inr).format(n);
}

String formatDate(dynamic v) {
  if (v == null) return '-';
  try {
    final d = v is DateTime ? v : DateTime.parse(v.toString()).toLocal();
    return _dateFmt.format(d);
  } catch (_) {
    return v.toString();
  }
}

String formatDateTime(dynamic v) {
  if (v == null) return '-';
  try {
    final d = v is DateTime ? v : DateTime.parse(v.toString()).toLocal();
    return _dateTimeFmt.format(d);
  } catch (_) {
    return v.toString();
  }
}

String formatInputDate(DateTime d) => _inputDate.format(d);

DateTime? tryParseDate(String? s) {
  if (s == null || s.isEmpty) return null;
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

List<dynamic> extractList(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    for (final k in const ['data', 'expenses', 'collections', 'items', 'loans', 'customers', 'savings', 'members', 'auctions', 'payments', 'transactions', 'entries', 'investments']) {
      if (data[k] is List) return data[k] as List;
    }
  }
  return const [];
}

num toNum(dynamic v, [num fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? fallback;
}

String titleCase(String s) {
  if (s.isEmpty) return s;
  return s
      .toLowerCase()
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
