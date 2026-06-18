import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app is currently blocked by backend maintenance, plus the
/// message to show. Flipped on by the API client when the backend answers 503
/// (platform-wide or per-org maintenance) and consumed by [MaintenanceGate].
class MaintenanceState {
  final bool active;
  final String message;
  const MaintenanceState({this.active = false, this.message = ''});
}

class MaintenanceController extends Notifier<MaintenanceState> {
  @override
  MaintenanceState build() => const MaintenanceState();

  void trigger(String message) {
    if (state.active && state.message == message) return;
    state = MaintenanceState(active: true, message: message);
  }

  void clear() {
    if (!state.active) return;
    state = const MaintenanceState();
  }
}

final maintenanceProvider =
    NotifierProvider<MaintenanceController, MaintenanceState>(MaintenanceController.new);
