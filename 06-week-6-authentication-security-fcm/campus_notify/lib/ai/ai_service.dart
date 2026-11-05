import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiService {
  final _storage = const FlutterSecureStorage();
  final Map<String, String> _cache = {};

  static const _apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent';
  static const _dailyLimit = 50;
  static const _requestTimeout = Duration(seconds: 45);

  static final _nikPattern = RegExp(r'\b\d{16}\b');
  static final _phonePattern = RegExp(r'(?:\+62|62|0)8\d{8,12}\b');

  Future<String> ask(String question) async {
    final trimmed = question.trim();

    if (trimmed.isEmpty) {
      throw Exception('Pertanyaan tidak boleh kosong.');
    }

    _ensureSafeText(trimmed);

    final cacheKey = trimmed.toLowerCase();
    final cached = _cache[cacheKey];

    if (cached != null) {
      return cached;
    }

    final apiKey = await _readApiKey();
    await _reserveRequest();

    final data = await _post(apiKey, {
      'contents': [
        {
          'parts': [
            {'text': trimmed},
          ],
        },
      ],
    });

    final text = _extractText(data);
    _cache[cacheKey] = text;

    return text;
  }

  Future<String> recognizeText(File imageFile) {
    return _analyzeImage(
      imageFile,
      'Extract all readable text from this image. '
      'Preserve the original language and line breaks. '
      'Return only the extracted text.',
    );
  }

  Future<String> understandImage(
    File imageFile, {
    String question = 'Describe this image in detail.',
  }) {
    return _analyzeImage(imageFile, question);
  }

  Future<String> speechToText(File audioFile) {
    return _analyzeAudio(
      audioFile,
      'Transcribe this audio exactly as spoken. '
      'Preserve the original language. Return only the transcript.',
    );
  }

  Future<void> saveApiKey(String key) async {
    await _storage.write(key: 'ai_api_key', value: key.trim());
    _cache.clear();
  }

  Future<String> _readApiKey() async {
    final apiKey = await _storage.read(key: 'ai_api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key tidak tersedia. Silakan atur di pengaturan.');
    }

    return apiKey;
  }

  Future<void> _reserveRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString('ai_usage_date');
    final used = storedDate == today
        ? (prefs.getInt('ai_usage_count') ?? 0)
        : 0;

    if (used >= _dailyLimit) {
      throw Exception(
        'Batas penggunaan AI harian ($_dailyLimit request) '
        'tercapai. Coba lagi besok.',
      );
    }

    await prefs.setString('ai_usage_date', today);
    await prefs.setInt('ai_usage_count', used + 1);
  }

  Future<String> _analyzeImage(File imageFile, String prompt) async {
    final apiKey = await _readApiKey();
    await _reserveRequest();

    final bytes = await imageFile.readAsBytes();
    final extension = imageFile.path.split('.').last.toLowerCase();

    final mimeType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };

    final data = await _post(apiKey, {
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inlineData': {'mimeType': mimeType, 'data': base64Encode(bytes)},
            },
          ],
        },
      ],
    });

    return _extractText(data);
  }

  Future<String> _analyzeAudio(File audioFile, String prompt) async {
    final apiKey = await _readApiKey();
    await _reserveRequest();

    final bytes = await audioFile.readAsBytes();
    final extension = audioFile.path.split('.').last.toLowerCase();

    final mimeType = switch (extension) {
      'mp3' => 'audio/mp3',
      'ogg' => 'audio/ogg',
      'flac' => 'audio/flac',
      'aac' => 'audio/aac',
      'm4a' => 'audio/mp4',
      'aiff' => 'audio/aiff',
      _ => 'audio/wav',
    };

    final data = await _post(apiKey, {
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inlineData': {'mimeType': mimeType, 'data': base64Encode(bytes)},
            },
          ],
        },
      ],
    });

    return _extractText(data);
  }

  Future<Map<String, dynamic>> _post(
    String apiKey,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }

        throw Exception('Respons AI tidak valid.');
      }

      throw Exception(_errorMessage(response.statusCode));
    } on TimeoutException {
      throw Exception('Koneksi ke AI timeout. Silakan coba lagi.');
    } on SocketException {
      throw Exception('Tidak ada koneksi internet. Periksa jaringan Anda.');
    } on http.ClientException {
      throw Exception(
        'Gagal menghubungi layanan AI. Periksa koneksi internet.',
      );
    } on FormatException {
      throw Exception('Respons AI tidak valid.');
    }
  }

  String _extractText(Map<String, dynamic> data) {
    final candidates = data['candidates'];

    if (candidates is List && candidates.isNotEmpty) {
      final first = candidates.first;

      if (first is Map) {
        final content = first['content'];

        if (content is Map) {
          final parts = content['parts'];

          if (parts is List) {
            final buffer = StringBuffer();

            for (final part in parts) {
              if (part is Map && part['text'] is String) {
                buffer.write(part['text']);
              }
            }

            final text = buffer.toString().trim();

            if (text.isNotEmpty) {
              return text;
            }
          }
        }
      }
    }

    final feedback = data['promptFeedback'];

    if (feedback is Map && feedback['blockReason'] != null) {
      throw Exception('AI menolak permintaan ini karena kebijakan konten.');
    }

    throw Exception('Respons AI kosong atau tidak valid.');
  }

  String _errorMessage(int statusCode) {
    if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
      return 'API key tidak valid. Silakan masukkan API key '
          'yang benar di pengaturan.';
    }

    if (statusCode == 429) {
      return 'Kuota AI habis atau terlalu banyak permintaan. '
          'Coba lagi nanti.';
    }

    if (statusCode == 503) {
      return 'Server AI sedang sibuk. Silakan coba lagi '
          'beberapa saat.';
    }

    if (statusCode >= 500) {
      return 'Layanan AI sedang bermasalah. '
          'Silakan coba lagi nanti.';
    }

    return 'Gagal memanggil AI API: $statusCode.';
  }

  void _ensureSafeText(String text) {
    if (_nikPattern.hasMatch(text)) {
      throw Exception(
        'Pertanyaan berisi NIK. Hapus data sensitif '
        'sebelum mengirim ke AI.',
      );
    }

    if (_phonePattern.hasMatch(text)) {
      throw Exception(
        'Pertanyaan berisi nomor telepon. Hapus data sensitif '
        'sebelum mengirim ke AI.',
      );
    }
  }
}
