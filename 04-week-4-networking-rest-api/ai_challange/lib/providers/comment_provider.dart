import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/comment.dart';
import '../repositories/comment_repository.dart';

/// Provider untuk [CommentRepository].
/// Digunakan bersama (shared) oleh seluruh provider yang butuh repository.
final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepository();
});

/// Provider mitra dengan parameter `postId`.
///
/// Notifier dibuat per-postId sehingga masing-masing post memiliki
/// AsyncValue (loading/data/error) sendiri secara otomatis.
final commentsProvider =
    AsyncNotifierProvider.family<CommentsNotifier, List<Comment>, int>(
  CommentsNotifier.new,
);

/// Notifier untuk mengambil daftar komentar berdasarkan postId.
class CommentsNotifier extends FamilyAsyncNotifier<List<Comment>, int> {
  /// Method yang dipanggil otomatis saat provider pertama kali di-watch.
  ///
  /// Error apa pun yang dilempar di sini **otomatis** ditangkap oleh Riverpod
  /// menjadi `AsyncError` (tanpa try-catch manual), lalu bisa dibaca lewat
  /// `AsyncValue.when(error: ...)` di lapisan UI.
  ///
  /// [arg] adalah postId yang dikirim pemakai provider.
  @override
  Future<List<Comment>> build(int arg) async {
    // Error apa pun (TimeoutException, DioException) yang dilempar dari sini
    // otomatis diubah Riverpod menjadi AsyncError pada state, tanpa try-catch
    // manual. UI cukup memanggil `ref.watch(commentsProvider(postId))`.
    return ref.read(commentRepositoryProvider).fetchComments(arg);
  }

  /// Memuat ulang (refresh) komentar untuk postId yang sama.
  Future<void> refresh() async {
    state = const AsyncLoading<List<Comment>>();
    // `AsyncValue.guard` mengubah hasil sukses menjadi AsyncData dan
    // error menjadi AsyncError, yang sama-sama disimpan ke attribute state.
    state = await AsyncValue.guard(
      () => ref.read(commentRepositoryProvider).fetchComments(arg),
    );
  }
}

/// Memetakan error menjadi pesan ramah pengguna (dalam Bahasa Indonesia).
///
/// Menangani kasus-kasus umum: timeout, error koneksi, HTTP 404, HTTP 500,
/// serta fallback untuk error yang tidak dikenal.
///
/// Karena Dio membungkus TimeoutException dari `Future.timeout` menjadi
/// DioException type connectionTimeout/receiveTimeout/sendTimeout, keduanya
/// diperiksa agar pesan timeout selalu konsisten.
String getCommentsErrorMessage(Object? error) {
  // 1) DioException: semua error dari lib Dio / HTTP berstatus.
  if (error is DioException) {
    // a) Kategori timeout (request atau respons terlalu lama).
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Waktu koneksi habis. Periksa jaringan Anda dan coba lagi.';
    }

    // b) Gagal melakukan koneksi (mis. tidak ada internet).
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.unknown) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
    }

    // c) Status HTTP yang muncul dari respons server.
    final statusCode = error.response?.statusCode;
    if (statusCode == 404) {
      return 'Data komentar tidak ditemukan (404).';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Server sedang bermasalah (500). Silakan coba lagi nanti.';
    }
  }

  // 2) TimeoutException murni dari `Future.timeout` (
  //    biasanya dipakai di luar Dio / di unit test).
  if (error is TimeoutException) {
    return 'Waktu koneksi habis. Periksa jaringan Anda dan coba lagi.';
  }

  // 3) Fallback: error tak dikenal.
  return 'Terjadi kesalahan yang tidak diketahui. Silakan coba lagi.';
}