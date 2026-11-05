import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../ai/ai_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final AiService _aiService = AiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];
  final ImagePicker _imagePicker = ImagePicker();

  AudioRecorder? _recorder;

  bool _isLoading = false;
  bool _isRecording = false;
  bool _isTranscribing = false;

  Future<void> _sendMessage() async {
    final question = _controller.text.trim();

    if (question.isEmpty || _isLoading || _isRecording || _isTranscribing) {
      return;
    }

    _controller.clear();
    await _sendQuestion(question, addUserMessage: true);
  }

  Future<void> _sendQuestion(
    String question, {
    required bool addUserMessage,
  }) async {
    if (_isLoading) return;

    setState(() {
      if (addUserMessage) {
        _messages.add(_ChatMessage(text: question, isUser: true));
      }

      _isLoading = true;
    });

    _scrollToBottom();

    String? retryQuestion;

    try {
      final answer = await _aiService.ask(question);

      if (!mounted) return;

      if (answer.trim().isEmpty) {
        throw Exception('AI tidak memberikan jawaban.');
      }

      final aiMessageIndex = _messages.length;
      setState(() {
        _messages.add(_ChatMessage(text: '', isUser: false));
      });

      for (int i = 0; i < answer.length; i += 3) {
        final end = (i + 3 < answer.length) ? i + 3 : answer.length;

        if (!mounted) return;

        setState(() {
          _messages[aiMessageIndex].text = answer.substring(0, end);
        });

        _scrollToBottom();

        await Future.delayed(const Duration(milliseconds: 30));
      }
    } catch (e) {
      if (!mounted) return;

      final action = await _showAiErrorDialog(e);

      if (!mounted) return;

      if (action == 'retry') {
        retryQuestion = question;
      } else if (action == 'offline') {
        setState(() {
          _messages.add(
            _ChatMessage(
              text:
                  'Mode offline: layanan AI tidak tersedia. '
                  'Silakan coba lagi nanti atau gunakan data lokal.',
              isUser: false,
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _scrollToBottom();
      }
    }

    if (retryQuestion != null && mounted) {
      await _sendQuestion(retryQuestion, addUserMessage: false);
    }
  }

  Future<String?> _showAiErrorDialog(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Layanan AI Bermasalah'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop('offline');
              },
              child: const Text('Mode Offline'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop('retry');
              },
              child: const Text('Coba Lagi'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleRecording() async {
    if (_isLoading || _isTranscribing) return;

    if (_isRecording) {
      await _stopRecordingAndTranscribe();
      return;
    }

    try {
      final recorder = _recorder ??= AudioRecorder();
      final hasPermission = await recorder.hasPermission();

      if (!hasPermission) {
        throw Exception(
          'Izin mikrofon ditolak. Aktifkan izin mikrofon '
          'di pengaturan aplikasi.',
        );
      }

      final path =
          '${Directory.systemTemp.path}/ai_voice_'
          '${DateTime.now().millisecondsSinceEpoch}.wav';

      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );

      if (!mounted) return;

      setState(() {
        _isRecording = true;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isRecording = false;
      });

      await _showAiErrorDialog(e);
    }
  }

  Future<void> _stopRecordingAndTranscribe() async {
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

    File? audioFile;

    try {
      final recorder = _recorder;

      if (recorder == null) {
        throw Exception('Perekam suara tidak tersedia.');
      }

      final path = await recorder.stop();

      if (path == null || path.isEmpty) {
        throw Exception('Rekaman gagal disimpan.');
      }

      audioFile = File(path);
      final text = await _aiService.speechToText(audioFile);

      if (!mounted) return;

      setState(() {
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: text.length);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teks berhasil diubah. Periksa lalu kirim.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      await _showAiErrorDialog(e);
    } finally {
      if (audioFile != null) {
        try {
          await audioFile.delete();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }

  Future<void> _showApiKeyDialog() async {
    final storage = const FlutterSecureStorage();

    final savedKey = await storage.read(key: 'ai_api_key') ?? '';

    final keyController = TextEditingController(text: savedKey);

    if (!mounted) {
      keyController.dispose();
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pengaturan API Key'),
          content: TextField(
            controller: keyController,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Masukkan API key'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final apiKey = keyController.text.trim();

                if (apiKey.isEmpty) return;

                await _aiService.saveApiKey(apiKey);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickAndAnalyzeImage({
    required ImageSource source,
    required bool useOcr,
  }) async {
    final XFile? pickedImage = await _imagePicker.pickImage(source: source);

    if (pickedImage == null) return;

    final imageFile = File(pickedImage.path);

    setState(() {
      _isLoading = true;

      _messages.add(
        _ChatMessage(
          text: useOcr
              ? 'Membaca teks dari gambar...'
              : 'Menganalisis gambar...',
          isUser: true,
        ),
      );
    });

    _scrollToBottom();

    try {
      final result = useOcr
          ? await _aiService.recognizeText(imageFile)
          : await _aiService.understandImage(imageFile);

      if (!mounted) return;

      setState(() {
        _messages.add(_ChatMessage(text: result, isUser: false));
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          _ChatMessage(text: 'Terjadi kesalahan: $e', isUser: false),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showImageOptions() async {
    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('OCR'),
                subtitle: const Text('Ambil teks dari gambar'),
                onTap: () => Navigator.pop(context, 'ocr'),
              ),
              ListTile(
                leading: const Icon(Icons.image_search),
                title: const Text('Image Understanding'),
                subtitle: const Text('Minta AI menjelaskan gambar'),
                onTap: () => Navigator.pop(context, 'understand'),
              ),
            ],
          ),
        );
      },
    );

    if (option == null || !mounted) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pilih dari galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Ambil foto dari kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    await _pickAndAnalyzeImage(source: source, useOcr: option == 'ocr');
  }

  @override
  void dispose() {
    final recorder = _recorder;

    if (recorder != null) {
      unawaited(recorder.dispose());
    }

    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      appBar: AppBar(
        title: const Text('AI Chat'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showApiKeyDialog,
          ),
        ],
      ),

      body: Column(
        children: [
          // Area percakapan
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Mulai percakapan dengan AI',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];

                      return _buildMessage(message);
                    },
                  ),
          ),

          // Indikator loading
          if (_isLoading || _isRecording || _isTranscribing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (_isRecording)
                    const Icon(
                      Icons.fiber_manual_record,
                      size: 18,
                      color: Colors.red,
                    )
                  else
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isRecording
                          ? 'Merekam... ketuk tombol stop untuk '
                                'mengubah ke teks.'
                          : _isTranscribing
                          ? 'Mengubah suara menjadi teks...'
                          : 'AI sedang menjawab...',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),

          // Input pesan
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isLoading || _isTranscribing
                        ? null
                        : _toggleRecording,
                    icon: Icon(
                      _isRecording ? Icons.stop_circle : Icons.mic,
                      color: _isRecording ? Colors.red : Colors.blue,
                    ),
                    tooltip: _isRecording ? 'Stop rekaman' : 'Input suara',
                  ),

                  IconButton(
                    onPressed: _isLoading || _isRecording || _isTranscribing
                        ? null
                        : _showImageOptions,
                    icon: const Icon(Icons.image_outlined, color: Colors.blue),
                    tooltip: 'Pilih gambar',
                  ),

                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isLoading && !_isRecording && !_isTranscribing,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Tulis pesan...',
                        filled: true,
                        fillColor: const Color(0xFFF1F1F1),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Tombol kirim
                  IconButton(
                    onPressed: _isLoading || _isRecording || _isTranscribing
                        ? null
                        : _sendMessage,
                    icon: const Icon(Icons.send, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue,
                      disabledBackgroundColor: Colors.grey,
                      padding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget untuk menampilkan pesan
  Widget _buildMessage(_ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// Model pesan chat
class _ChatMessage {
  String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}
