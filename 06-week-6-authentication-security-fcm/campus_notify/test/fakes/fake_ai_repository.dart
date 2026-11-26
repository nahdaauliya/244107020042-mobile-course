import 'dart:io';

import 'package:campus_notify/ai/ai_repository.dart';

class FakeAiRepository implements AiRepository {
  String response = 'Halo! Saya AI Assistant.';
  bool shouldFail = false;

  int askCallCount = 0;
  String? lastQuestion;

  @override
  Future<String> ask(String question) async {
    askCallCount++;
    lastQuestion = question;

    if (shouldFail) {
      throw Exception('Gagal menghubungi layanan AI.');
    }

    return response;
  }

  @override
  Future<void> saveApiKey(String key) async {
    if (key.trim().isEmpty) {
      throw Exception('API key tidak boleh kosong.');
    }
  }

  @override
  Future<String> speechToText(File audioFile) async {
    if (shouldFail) {
      throw Exception('Transkripsi gagal.');
    }

    return 'Hasil transkripsi suara.';
  }

  @override
  Future<String> recognizeText(File imageFile) async {
    if (shouldFail) {
      throw Exception('OCR gagal.');
    }

    return 'Hasil pembacaan teks gambar.';
  }

  @override
  Future<String> understandImage(
    File imageFile, {
    String question = 'Describe this image in detail.',
  }) async {
    if (shouldFail) {
      throw Exception('Analisis gambar gagal.');
    }

    return 'Gambar berhasil dianalisis.';
  }
}
