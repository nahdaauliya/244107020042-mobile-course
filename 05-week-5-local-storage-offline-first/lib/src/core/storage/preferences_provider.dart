import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences_service.dart';

/// Di-override di `main()` dengan instance yang sudah di-load.
///
/// Sengaja `throw` dan bukan nilai default: kalau sampai terisi, berarti ada
/// entry point yang lupa meng-inject, dan lebih baik gagal cepat daripada
/// diam-diam memakai preferensi palsu yang membuat test lolos tanpa benar-benar
/// menguji apa pun.
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  throw UnimplementedError(
    'preferencesServiceProvider harus di-override di main() atau di test.',
  );
});