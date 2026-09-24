import 'package:flutter_test/flutter_test.dart';

import 'package:ai_challange/models/comment.dart';

void main() {
  group('Comment.fromJson', () {
    test('mengembalikan null untuk field yang hilang / bernilai null', () {
      // Simulasi JSON tidak lengkap: hanya key 'id' yang tersedia,
      // sisanya (postId, name, email, body) TIDAK ADA di dalam JSON.
      final json = <String, dynamic>{'id': 1};

      final comment = Comment.fromJson(json);

      // Field yang kadarnya tersedia tetap terbaca.
      expect(comment.id, 1);

      // Field yang tidak ada di JSON menjadi null, TANPA error.
      expect(comment.postId, isNull);
      expect(comment.name, isNull);
      expect(comment.email, isNull);
      expect(comment.body, isNull);
    });

    test('mengembalikan null ketika value eksplisit null', () {
      // JSON lengkap tapi beberapa nilai null.
      final json = <String, dynamic>{
        'postId': 1,
        'id': 7,
        'name': null,
        'email': null,
        'body': null,
      };

      final comment = Comment.fromJson(json);

      expect(comment.postId, 1);
      expect(comment.id, 7);
      expect(comment.name, isNull);
      expect(comment.email, isNull);
      expect(comment.body, isNull);
    });

    test('mengembalikan null untuk field id/postId yang bertipe non-angka', () {
      // JSONPlaceholder selalu mengirim int, tapi dariJson tetap aman
      // bila server mengirim string "1" atau bahkan tidak valid.
      final json = <String, dynamic>{
        'postId': 'abc',
        'id': 3,
        'name': 'Nama',
        'email': 'a@b.c',
        'body': 'Isi komentar',
      };

      final comment = Comment.fromJson(json);

      // 'abc' bukan angka -> aman menjadi null.
      expect(comment.postId, isNull);
      expect(comment.id, 3);
      expect(comment.name, 'Nama');
      expect(comment.email, 'a@b.c');
      expect(comment.body, 'Isi komentar');
    });
  });
}