import 'dart:async';

import 'package:dio/dio.dart';

import '../models/comment.dart';

/// Repository untuk mengambil data komentar dari JSONPlaceholder
/// menggunakan HTTP client Dio.
class CommentRepository {
  /// Base URL JSONPlaceholder.
  static const String _baseUrl = 'https://jsonplaceholder.typicode.com';

  /// Dio client yang dipakai untuk semua request.
  ///
  /// Bisa di-inject lewat constructor agar mudah di-mock saat pengujian.
  final Dio _dio;

  /// Constructor: menerima [Dio] opsional.
  /// Jika tidak dikirim, dibuat instance Dio default dengan [BaseOptions]
  /// berisi timeout koneksi dan penerimaan data (masing-masing 10 detik).
  ///
  /// `dioFactory` dijadikan parameter terpisah agar pengujian (unit test)
  /// bisa menyuntikkan implementasi sendiri dengan mudah.
  CommentRepository({Dio? dio}) : _dio = dio ?? _defaultDio();

  /// Membangun Dio bawaan dengan konfigurasi dasar.
  static Dio _defaultDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        // Header standar untuk komunikasi JSON.
        headers: {'Accept': 'application/json'},
      ),
    );
  }

  /// Mengambil daftar komentar milik sebuah post.
  ///
  /// Memanggil `GET /comments?postId={postId}`.
  /// Seluruh request dibatasi waktu 10 detik via `Future.timeout`.
  /// Apabila waktu habis, `TimeoutException` akan dilempar dan
  /// tetap bisa dipetakan oleh fungsi pesan error di provider.
  ///
  /// - [postId]: ID post yang komentarnya ingin diambil.
  /// - Returns: [List] berisi [Comment]; kosong bila tidak ada komentar.
  /// - Throws: [DioException] / [TimeoutException] bila gagal.
  Future<List<Comment>> fetchComments(int postId) async {
    // Request GET dengan query parameter postId.
    final response = await _dio
        .get<List<dynamic>>(
      '$_baseUrl/comments',
      queryParameters: {'postId': postId},
    )
        // Batas waktu 10 detik untuk seluruh operasi request.
        .timeout(const Duration(seconds: 10));

    // Validasi status HTTP: selain 200 dianggap error.
    final status = response.statusCode;
    if (status == null || status < 200 || status >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'HTTP $status saat mengambil komentar',
      );
    }

    // Parse body JSON menjadi List<Comment>.
    // Dio dengan responseType JSON otomatis mengubah body ke List/Map.
    return response.data!
        // Setiap elemen list dipetakan menjadi model Comment.
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}