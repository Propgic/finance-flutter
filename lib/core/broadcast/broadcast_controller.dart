import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../auth/auth_controller.dart';

/// A super-admin broadcast shown to staff as a dismissible top banner.
class Broadcast {
  final String id;
  final String title;
  final String message;

  const Broadcast({required this.id, required this.title, required this.message});

  factory Broadcast.fromJson(Map<String, dynamic> j) => Broadcast(
        id: j['id'].toString(),
        title: j['title']?.toString() ?? '',
        message: j['message']?.toString() ?? '',
      );
}

/// Holds the active, not-yet-dismissed broadcasts for the current staff login.
/// Refetches whenever the active account changes; dismissing one persists the
/// dismissal server-side so it never returns (here or on web).
class BroadcastController extends Notifier<List<Broadcast>> {
  @override
  List<Broadcast> build() {
    // Re-run (and refetch) when the active login changes — login / logout /
    // switch account. Avoids showing one org's banners to another account.
    ref.watch(authProvider.select((s) => s.accountId));
    _load();
    return const [];
  }

  Future<void> _load() async {
    if (!ref.read(authProvider).isAuthed) {
      state = const [];
      return;
    }
    try {
      final res = await ref.read(apiClientProvider).get('/broadcasts');
      final list = res is Map && res['broadcasts'] is List
          ? res['broadcasts'] as List
          : (res is List ? res : const []);
      state = list.map((e) => Broadcast.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      // Never block the app on a banner fetch; just show nothing.
      state = const [];
    }
  }

  Future<void> refresh() => _load();

  Future<void> dismiss(String id) async {
    // Hide immediately; the server records it so it stays gone.
    state = state.where((b) => b.id != id).toList();
    try {
      await ref.read(apiClientProvider).post('/broadcasts/$id/dismiss');
    } catch (_) {
      // If it failed it simply reappears on the next load.
    }
  }
}

final broadcastProvider =
    NotifierProvider<BroadcastController, List<Broadcast>>(BroadcastController.new);
