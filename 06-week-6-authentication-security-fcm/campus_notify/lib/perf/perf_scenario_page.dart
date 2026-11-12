import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../features/notes/domain/entities/note.dart';
import '../features/notes/presentation/pages/note_detail_page.dart';
import '../features/notes/presentation/pages/notes_page.dart';
import '../features/notes/presentation/providers/notes_providers.dart';
import 'perf_metrics.dart';

/// Halaman harness untuk merekam baseline performa daftar catatan.
///
/// Jalankan dengan `PERF_AUTORUN=true` untuk skenario otomatis, atau
/// `PERF_AUTORUN=false` jika ingin merekam manual lewat DevTools.
class PerfScenarioPage extends ConsumerStatefulWidget {
  const PerfScenarioPage({super.key});

  @override
  ConsumerState<PerfScenarioPage> createState() => _PerfScenarioPageState();
}

class _PerfScenarioPageState extends ConsumerState<PerfScenarioPage> {
  static const bool _autoRun = bool.fromEnvironment(
    'PERF_AUTORUN',
    defaultValue: true,
  );
  static const String _reportUrl = String.fromEnvironment('PERF_REPORT_URL');
  static const int _noteCount = int.fromEnvironment(
    'PERF_NOTE_COUNT',
    defaultValue: 500,
  );

  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();
  final PerfFrameCollector _collector = PerfFrameCollector();

  PerfFrameStats? _stats;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    if (_autoRun) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_runScenario());
      });
    }
  }

  @override
  void dispose() {
    _collector.stop();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _runScenario() async {
    if (_running) return;
    setState(() => _running = true);

    try {
      await Future<void>.delayed(const Duration(seconds: 8));
      final notes = await ref.read(notesProvider.future);
      if (!mounted || notes.isEmpty) return;

      // Warm-up: jalankan semua jalur sekali agar text layout, shader, dan
      // route transition tidak ikut terukur sebagai jank startup.
      await _scrollToBottom();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _scrollToTop();
      await _openAndCloseDetail(notes.first);
      await _pullToRefresh();
      await Future<void>.delayed(const Duration(seconds: 2));

      _collector.start();

      for (var i = 0; i < 3; i++) {
        await _scrollToBottom();
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await _scrollToTop();
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }

      await _openAndCloseDetail(notes.first);
      await _pullToRefresh();

      await Future<void>.delayed(const Duration(seconds: 2));
      _collector.stop();

      final stats = _collector.summarize();
      if (mounted) {
        setState(() => _stats = stats);
      }
      await _report(stats);
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _openAndCloseDetail(Note note) async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final route = MaterialPageRoute<void>(
      builder: (_) => NoteDetailPage(note: note),
    );
    final routeFuture = navigator.push(route);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (navigator.canPop()) {
      navigator.pop();
    }
    await routeFuture;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _pullToRefresh() async {
    final refresh = _refreshKey.currentState;
    if (refresh != null) {
      await refresh.show();
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _report(PerfFrameStats stats) async {
    final payload = jsonEncode({
      'scenario': 'notes-list-detail-refresh',
      'noteCount': _noteCount,
      'stats': stats.toJson(),
    });
    debugPrint('PERF_BASELINE_JSON: $payload');

    if (_reportUrl.isEmpty) return;

    try {
      await http.post(
        Uri.parse(_reportUrl),
        headers: const {'Content-Type': 'text/plain'},
        body: payload,
      );
    } catch (error) {
      debugPrint('PERF_REPORT_ERROR: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: NotesPage(
            scrollController: _scrollController,
            refreshIndicatorKey: _refreshKey,
          ),
        ),
        if (_stats != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Frames: ${_stats!.totalFrames} | '
                    'Kuning: ${_stats!.yellowFrames} | '
                    'Merah: ${_stats!.redFrames} | '
                    'Avg: ${_stats!.averageFrameMs} ms',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
