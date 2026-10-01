import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences_provider.dart';
import '../../notes/domain/conflict.dart';

/// Sakelar "pakai mode pesawat" untuk demo.
///
/// BUKAN gaya: di desktop, di CI, dan di golden test tidak ada cara menyalakan
/// mode pesawat sungguhan, padahal alur offline-first justru bagian paling
/// penting untuk dibuktikan. Sakelar ini mereproduksi efek yang sama persis —
/// repository berhenti memanggil jaringan dan membaca cache lokal — sehingga
/// bukti di `screenshots/` identik dengan yang terjadi di perangkat.
class SimulateOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(preferencesServiceProvider).readSimulateOffline();

  Future<void> setOffline(bool value) async {
    state = value;
    await ref.read(preferencesServiceProvider).writeSimulateOffline(value);
  }
}

final simulateOfflineProvider =
    NotifierProvider<SimulateOfflineNotifier, bool>(SimulateOfflineNotifier.new);

/// Aturan resolusi konflik yang aktif, dibaca repository setiap siklus sync.
class ConflictStrategyNotifier extends Notifier<ConflictStrategy> {
  @override
  ConflictStrategy build() =>
      ref.read(preferencesServiceProvider).readConflictStrategy();

  Future<void> setStrategy(ConflictStrategy strategy) async {
    state = strategy;
    await ref.read(preferencesServiceProvider).writeConflictStrategy(strategy);
  }
}

final conflictStrategyProvider =
    NotifierProvider<ConflictStrategyNotifier, ConflictStrategy>(
  ConflictStrategyNotifier.new,
);