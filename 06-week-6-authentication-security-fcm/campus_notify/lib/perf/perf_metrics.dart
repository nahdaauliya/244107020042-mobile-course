import 'package:flutter/scheduler.dart';

/// Ringkasan frame timing untuk baseline profiling.
class PerfFrameStats {
  const PerfFrameStats({
    required this.totalFrames,
    required this.yellowFrames,
    required this.redFrames,
    required this.buildBudgetMisses,
    required this.rasterBudgetMisses,
    required this.averageFrameMs,
    required this.averageBuildMs,
    required this.averageRasterMs,
    required this.p90FrameMs,
    required this.p99FrameMs,
    required this.worstFrameMs,
    required this.averageTotalSpanMs,
  });

  final int totalFrames;
  final int yellowFrames;
  final int redFrames;
  final int buildBudgetMisses;
  final int rasterBudgetMisses;
  final double averageFrameMs;
  final double averageBuildMs;
  final double averageRasterMs;
  final double p90FrameMs;
  final double p99FrameMs;
  final double worstFrameMs;
  final double averageTotalSpanMs;

  double get jankRate =>
      totalFrames == 0 ? 0 : (yellowFrames + redFrames) / totalFrames;

  Map<String, Object> toJson() => {
    'totalFrames': totalFrames,
    'yellowFrames': yellowFrames,
    'redFrames': redFrames,
    'buildBudgetMisses': buildBudgetMisses,
    'rasterBudgetMisses': rasterBudgetMisses,
    'jankRate': double.parse(jankRate.toStringAsFixed(4)),
    'averageFrameMs': averageFrameMs,
    'averageBuildMs': averageBuildMs,
    'averageRasterMs': averageRasterMs,
    'p90FrameMs': p90FrameMs,
    'p99FrameMs': p99FrameMs,
    'worstFrameMs': worstFrameMs,
    'averageTotalSpanMs': averageTotalSpanMs,
  };

  @override
  String toString() => toJson().toString();
}

/// Mengumpulkan [FrameTiming] selama skenario profiling berjalan.
class PerfFrameCollector {
  static const double _yellowThresholdMs = 16.67;
  static const double _redThresholdMs = 33.33;

  final List<FrameTiming> _frames = <FrameTiming>[];
  bool _collecting = false;

  void start() {
    _frames.clear();
    _collecting = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    _collecting = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_collecting) {
      _frames.addAll(timings);
    }
  }

  PerfFrameStats summarize() {
    if (_frames.isEmpty) {
      return const PerfFrameStats(
        totalFrames: 0,
        yellowFrames: 0,
        redFrames: 0,
        buildBudgetMisses: 0,
        rasterBudgetMisses: 0,
        averageFrameMs: 0,
        averageBuildMs: 0,
        averageRasterMs: 0,
        p90FrameMs: 0,
        p99FrameMs: 0,
        worstFrameMs: 0,
        averageTotalSpanMs: 0,
      );
    }

    final frameMs = <double>[];
    final buildMs = <double>[];
    final rasterMs = <double>[];
    final totalSpanMs = <double>[];

    var yellow = 0;
    var red = 0;
    var buildMisses = 0;
    var rasterMisses = 0;

    for (final frame in _frames) {
      final build = frame.buildDuration.inMicroseconds / 1000;
      final raster = frame.rasterDuration.inMicroseconds / 1000;
      final total = build + raster;

      buildMs.add(build);
      rasterMs.add(raster);
      frameMs.add(total);
      totalSpanMs.add(frame.totalSpan.inMicroseconds / 1000);

      if (total > _redThresholdMs) {
        red++;
      } else if (total > _yellowThresholdMs) {
        yellow++;
      }

      if (build > _yellowThresholdMs) buildMisses++;
      if (raster > _yellowThresholdMs) rasterMisses++;
    }

    final sortedFrameMs = List<double>.from(frameMs)..sort();

    double average(List<double> values) =>
        values.reduce((a, b) => a + b) / values.length;

    double percentile(List<double> sorted, double p) {
      final index = ((sorted.length - 1) * p).round();
      return sorted[index];
    }

    return PerfFrameStats(
      totalFrames: frameMs.length,
      yellowFrames: yellow,
      redFrames: red,
      buildBudgetMisses: buildMisses,
      rasterBudgetMisses: rasterMisses,
      averageFrameMs: double.parse(average(frameMs).toStringAsFixed(2)),
      averageBuildMs: double.parse(average(buildMs).toStringAsFixed(2)),
      averageRasterMs: double.parse(average(rasterMs).toStringAsFixed(2)),
      p90FrameMs: double.parse(
        percentile(sortedFrameMs, 0.90).toStringAsFixed(2),
      ),
      p99FrameMs: double.parse(
        percentile(sortedFrameMs, 0.99).toStringAsFixed(2),
      ),
      worstFrameMs: double.parse(sortedFrameMs.last.toStringAsFixed(2)),
      averageTotalSpanMs: double.parse(average(totalSpanMs).toStringAsFixed(2)),
    );
  }
}
