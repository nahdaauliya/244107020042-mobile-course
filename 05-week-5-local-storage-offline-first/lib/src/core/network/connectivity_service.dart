import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Pembaca status koneksi yang dibungkus supaya sisanya tidak pernah
/// bergantung pada plugin langsung.
///
/// Catatan jujur soal batasannya: [Connectivity] melaporkan **ada/tidaknya
/// interface jaringan**, bukan apakah internet benar-benar terjangkau. Wi-Fi
/// yang terhubung ke jaringan tanpa uplink tetap terbaca "online". Karena itu
/// aplikasi memperlakukan ini sebagai petunjuk, dan kode sync tetap wajib
/// siap untuk exception jaringan apa pun — itulah yang membuat UI tidak crash
/// saat benar-benar tidak ada uplink.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _hasLink(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<bool> isOnline() async {
    try {
      return _hasLink(await _connectivity.checkConnectivity());
    } catch (_) {
      // Plugin tidak tersedia (mis. desktop tanpa implementasi): anggap online
      // dan biarkan penanganan error jaringan yang jadi penentu.
      return true;
    }
  }

  Stream<bool> onStatusChange() {
    try {
      return _connectivity.onConnectivityChanged.map(_hasLink);
    } catch (_) {
      return const Stream<bool>.empty();
    }
  }
}