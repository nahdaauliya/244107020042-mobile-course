import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_validator.dart';
import 'ai_repository.dart';

class AiService implements AiRepository {
  final _storage = const FlutterSecureStorage();
  final Map<String, String> _cache = {};

  static const _baseUrl = 'https://api.x.ai/v1';
  static const _chatModel = 'grok-4.7';
  static const _audioModel = 'grok-voice-transcribe-2.0';

  static const _dailyLimit = 50;
  static const _requestTimeout = Duration(seconds: 45);

  @override
  Future<String> ask(String question) async {
    final trimmed = ChatValidator.validate(question);

    final cacheKey = trimmed.toLowerCase();
    final cached = _cache[cacheKey];

    if (cached != null) {
      return cached;
    }

    final apiKey = await _readApiKey();
    await _reserveRequest();

    final data = await _post(apiKey, {
      'model': _chatModel,
      'input': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'input_text',
              'text': trimmed,
            },
          ],
        },
      ],
    });

    final answer = _extractResponseText(data);
    _cache[cacheKey] = answer;

    return answer;
  }

  @override
  Future<String> recognizeText(File imageFile) {
    return _analyzeImage(
      imageFile,
      'Extract all readable text from this image. '
      'Preserve the original language and line breaks. '
      'Return only the extracted text.',
    );
  }

  @override
  Future<String> understandImage(
    File imageFile, {
    String question = 'Describe this image in detail.',
  }) {
    return _analyzeImage(imageFile, question);
  }

  @override
  Future<String> speechToText(File audioFile) async {
    if (!await audioFile.exists()) {
      throw Exception('File audio tidak ditemukan.');
    }

    final apiKey = await _readApiKey();
    await _reserveRequest();

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/stt'),
      );

      request.headers['Authorization'] = 'Bearer $apiKey';

      request.fields['model'] = _audioModel;
      request.fields['format'] = 'true';

      // File harus menjadi field terakhir pada multipart request.
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          audioFile.path,
        ),
      );

      final streamedResponse = await request
          .send()
          .timeout(_requestTimeout);

      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(_requestTimeout);

      if (response.statusCode != 200) {
        throw Exception(
          _errorMessage(
            response.statusCode,
            response.body,
          ),
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic> &&
          decoded['text'] is String) {
        final transcript = (decoded['text'] as String).trim();

        if (transcript.isNotEmpty) {
          return transcript;
        }
      }

      throw Exception('Hasil transkripsi audio kosong.');
    } on TimeoutException {
      throw Exception('Transkripsi audio timeout. Coba lagi.');
    } on SocketException {
      throw Exception(
        'Tidak ada koneksi internet. Periksa jaringan Anda.',
      );
    } on http.ClientException {
      throw Exception(
        'Gagal menghubungi layanan transkripsi Grok.',
      );
    } on FormatException {
      throw Exception('Respons transkripsi tidak valid.');
    }
  }

  @override
  Future<void> saveApiKey(String key) async {
    final trimmedKey = key.trim();

    if (trimmedKey.isEmpty) {
      throw Exception('API key tidak boleh kosong.');
    }

    await _storage.write(
      key: 'ai_api_key',
      value: trimmedKey,
    );

    _cache.clear();
  }

  Future<String> _readApiKey() async {
    final apiKey = await _storage.read(key: 'ai_api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'API key Grok tidak tersedia. '
        'Silakan atur di pengaturan.',
      );
    }

    return apiKey;
  }

  Future<void> _reserveRequest() async {
    final prefs = await SharedPreferences.getInstance();

    final today = DateTime.now()
        .toIso8601String()
        .substring(0, 10);

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

  Future<String> _analyzeImage(
    File imageFile,
    String prompt,
  ) async {
    if (!await imageFile.exists()) {
      throw Exception('File gambar tidak ditemukan.');
    }

    final apiKey = await _readApiKey();
    await _reserveRequest();

    final extension = imageFile.path
        .split('.')
        .last
        .toLowerCase();

    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => throw Exception(
          'Format gambar tidak didukung Grok. '
          'Gunakan JPG, JPEG, atau PNG.',
        ),
    };

    final bytes = await imageFile.readAsBytes();

    final imageData =
        'data:$mimeType;base64,${base64Encode(bytes)}';

    final data = await _post(apiKey, {
      'model': _chatModel,
      'input': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'input_text',
              'text': prompt,
            },
            {
              'type': 'input_image',
              'image_url': imageData,
            },
          ],
        },
      ],
    });

    return _extractResponseText(data);
  }

  Future<Map<String, dynamic>> _post(
    String apiKey,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/responses'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }

        throw Exception('Respons Grok tidak valid.');
      }

      throw Exception(
        _errorMessage(
          response.statusCode,
          response.body,
        ),
      );
    } on TimeoutException {
      throw Exception('Koneksi ke Grok timeout. Silakan coba lagi.');
    } on SocketException {
      throw Exception(
        'Tidak ada koneksi internet. Periksa jaringan Anda.',
      );
    } on http.ClientException {
      throw Exception(
        'Gagal menghubungi layanan Grok. Periksa koneksi internet.',
      );
    } on FormatException {
      throw Exception('Respons Grok tidak valid.');
    }
  }

  String _extractResponseText(Map<String, dynamic> data) {
    final output = data['output'];

    if (output is List) {
      final buffer = StringBuffer();

      for (final item in output) {
        if (item is! Map) continue;

        final content = item['content'];

        if (content is! List) continue;

        for (final part in content) {
          if (part is Map &&
              part['type'] == 'output_text' &&
              part['text'] is String) {
            buffer.write(part['text']);
          }
        }
      }

      final answer = buffer.toString().trim();

      if (answer.isNotEmpty) {
        return answer;
      }
    }

    final error = data['error'];

    if (error is Map && error['message'] is String) {
      throw Exception(error['message']);
    }

    throw Exception('Respons Grok kosong atau tidak valid.');
  }

  String _errorMessage(
    int statusCode,
    String responseBody,
  ) {
    String? apiMessage;

    try {
      final decoded = jsonDecode(responseBody);

      if (decoded is Map) {
        final error = decoded['error'];

        if (error is Map && error['message'] is String) {
          apiMessage = error['message'] as String;
        } else if (error is String) {
          apiMessage = error;
        }
      }
    } catch (_) {
      // Gunakan pesan umum jika respons bukan JSON.
    }

    if (statusCode == 400) {
      return apiMessage ?? 'Permintaan ke Grok tidak valid.';
    }

    if (statusCode == 401 || statusCode == 403) {
      return 'API key Grok tidak valid atau tidak memiliki akses.';
    }

    if (statusCode == 404) {
      return 'Endpoint atau model Grok tidak ditemukan.';
    }

    if (statusCode == 429) {
      return 'Batas penggunaan atau kuota Grok tercapai. '
          'Periksa kredit dan limit akun xAI.';
    }

    if (statusCode >= 500) {
      return 'Server Grok sedang bermasalah. Coba lagi nanti.';
    }

    return apiMessage ?? 'Gagal memanggil Grok API: $statusCode.';
  }
}