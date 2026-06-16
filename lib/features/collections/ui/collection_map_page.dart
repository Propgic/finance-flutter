import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../data/collection_repo.dart';

const _kPaymentModeLabels = <String, String>{
  'CASH': 'Cash',
  'UPI': 'UPI',
  'BANK_TRANSFER': 'Bank Transfer',
  'CHEQUE': 'Cheque',
  'ONLINE': 'Online',
};

// Hyderabad — sensible default when there is no GPS fix and no collections.
const _kDefaultCenter = LatLng(17.385, 78.4867);

/// Parse a coordinate that may arrive as num, String or null. Returns null
/// (not 0) when absent/invalid so missing GPS fixes are filtered out.
double? _coord(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class CollectionMapPage extends ConsumerStatefulWidget {
  const CollectionMapPage({super.key});
  @override
  ConsumerState<CollectionMapPage> createState() => _CollectionMapPageState();
}

class _CollectionMapPageState extends ConsumerState<CollectionMapPage> {
  final _mapController = MapController();
  late String _date;
  bool _loading = true;
  bool _mapReady = false;
  List<Map<String, dynamic>> _geo = const [];
  int _missing = 0;
  LatLng? _myLocation;

  @override
  void initState() {
    super.initState();
    _date = formatInputDate(DateTime.now());
    _load();
    _resolveMyLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await ref.read(collectionRepoProvider).forMap(date: _date);
      final geo = <Map<String, dynamic>>[];
      for (final c in all) {
        final lat = _coord(c['latitude']);
        final lng = _coord(c['longitude']);
        if (lat == null || lng == null) continue;
        geo.add({...c, '_lat': lat, '_lng': lng});
      }
      // Chronological order so marker numbers reflect visit order.
      geo.sort((a, b) {
        final at = DateTime.tryParse(a['collectedAt']?.toString() ?? '');
        final bt = DateTime.tryParse(b['collectedAt']?.toString() ?? '');
        if (at == null || bt == null) return 0;
        return at.compareTo(bt);
      });
      if (!mounted) return;
      setState(() {
        _geo = geo;
        _missing = all.length - geo.length;
        _loading = false;
      });
      _fitBounds();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast('Failed to load map: $e', error: true);
    }
  }

  Future<void> _resolveMyLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return; // No location — map simply centres on collections / default.
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
    } on Object {
      // Location is best-effort; ignore failures silently.
    }
  }

  void _fitBounds() {
    if (!_mapReady || _geo.isEmpty) return;
    final points = _geo.map((c) => LatLng(c['_lat'] as double, c['_lng'] as double)).toList();
    if (points.length == 1) {
      _mapController.move(points.first, 15);
    } else {
      _mapController.fitCamera(
        CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(48)),
      );
    }
  }

  Future<void> _pickDate() async {
    final init = DateTime.tryParse(_date) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: init,
    );
    if (d != null) {
      setState(() => _date = formatInputDate(d));
      _load();
    }
  }

  void _showDetail(Map<String, dynamic> c, int index) {
    final cust = Map<String, dynamic>.from(c['customer'] ?? {});
    final name = '${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim();
    final mode = c['paymentMode']?.toString() ?? '';
    final collectedBy = Map<String, dynamic>.from(c['collectedBy'] ?? {});
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary,
                    child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name.isEmpty ? 'Customer' : name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              KeyValueRow(label: 'Amount', value: formatCurrency(c['amount'])),
              KeyValueRow(label: 'Mode', value: _kPaymentModeLabels[mode] ?? mode),
              KeyValueRow(label: 'Collected At', value: formatDateTime(c['collectedAt'])),
              if (c['receiptNumber'] != null)
                KeyValueRow(label: 'Receipt', value: c['receiptNumber'].toString()),
              if (collectedBy['name'] != null)
                KeyValueRow(label: 'Collector', value: collectedBy['name'].toString()),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push('/collections/${c['id']}/receipt');
                  },
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Open Receipt'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'Pick date',
            onPressed: _pickDate,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text(_date, style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_geo.length} stop${_geo.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_geo.isEmpty) {
      return EmptyView(
        message: 'No geo-tagged collections for $_date',
        icon: Icons.location_off_outlined,
        action: OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today, size: 16),
          label: const Text('Change date'),
        ),
      );
    }
    final center = _myLocation ??
        (_geo.isNotEmpty ? LatLng(_geo.first['_lat'] as double, _geo.first['_lng'] as double) : _kDefaultCenter);
    final routePoints = _geo.map((c) => LatLng(c['_lat'] as double, c['_lng'] as double)).toList();
    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
              onMapReady: () {
                _mapReady = true;
                _fitBounds();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'in.rupit.financer',
              ),
              if (routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(points: routePoints, strokeWidth: 4, color: AppColors.primary.withValues(alpha: 0.6)),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < _geo.length; i++)
                    Marker(
                      point: LatLng(_geo[i]['_lat'] as double, _geo[i]['_lng'] as double),
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: () => _showDetail(_geo[i], i),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  if (_myLocation != null)
                    Marker(
                      point: _myLocation!,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.info,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_missing > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Text(
              '$_missing collection${_missing == 1 ? '' : 's'} had no location data and ${_missing == 1 ? 'is' : 'are'} not shown.',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }
}
