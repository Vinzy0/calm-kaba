import 'dart:ui' show FramePhase, FrameTiming;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Developer metrics. Only this widget rebuilds, once per native packet (1 Hz).
///
/// Native values are measured in the camera pipeline. Flutter frames/s counts
/// composited Flutter frames; with texture-layer platform views each new camera
/// texture frame schedules one, so it estimates preview presentation FPS.
class DiagnosticsPanel extends StatefulWidget {
  final ValueListenable<Map<dynamic, dynamic>?> source;
  const DiagnosticsPanel({super.key, required this.source});

  @override
  State<DiagnosticsPanel> createState() => _DiagnosticsPanelState();
}

class _DiagnosticsPanelState extends State<DiagnosticsPanel> {
  final List<FrameTiming> _frames = [];

  void _onTimings(List<FrameTiming> timings) {
    _frames.addAll(timings);
    final cutoff =
        timings.last.timestampInMicroseconds(FramePhase.rasterFinish) - 2000000;
    _frames.removeWhere(
      (t) => t.timestampInMicroseconds(FramePhase.rasterFinish) < cutoff,
    );
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  String _n(Object? v, [int digits = 1]) =>
      v is num ? v.toStringAsFixed(digits) : 'n/a';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<dynamic, dynamic>?>(
      valueListenable: widget.source,
      builder: (context, d, _) {
        final style = const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: Colors.white,
          height: 1.3,
        );
        if (d == null) {
          return Container(
            color: Colors.black87,
            padding: const EdgeInsets.all(8),
            child: Text(
              'Diagnostics: waiting for camera pipeline',
              style: style,
            ),
          );
        }
        double? flutterFps;
        double? rasterP50;
        if (_frames.length > 1) {
          final span =
              _frames.last.timestampInMicroseconds(FramePhase.rasterFinish) -
              _frames.first.timestampInMicroseconds(FramePhase.rasterFinish);
          if (span > 0) flutterFps = (_frames.length - 1) * 1e6 / span;
          final raster =
              _frames
                  .map((f) => f.rasterDuration.inMicroseconds / 1000)
                  .toList()
                ..sort();
          rasterP50 = raster[raster.length ~/ 2];
        }
        final stages = (d['stages'] as Map?) ?? {};
        final labels = (d['stageLabels'] as Map?) ?? {};
        final lines = <String>[
          'RATES (2 s window)',
          ' camera capture   ${_n(d['captureFps'])} fps  (Camera2 callback)',
          ' preview est.     ${_n(flutterFps)} fps  (Flutter frames, raster p50 ${_n(rasterP50)} ms)',
          ' to analyzer      ${_n(d['deliveredFps'])} fps',
          ' processed        ${_n(d['processedFps'])} fps  (landmarks)',
          ' dropped est.     ${_n(d['droppedFpsEstimate'])} fps  skipped ${_n(d['skippedPerSecond'])}/s',
          ' predictions      ${_n(d['predictionHz'], 2)} Hz  (window step 2 s)',
          'STAGES ms         mean    p50    p95    max',
          for (final e in stages.entries)
            if (e.value is Map)
              ' ${(labels[e.key] ?? e.key).toString().padRight(16).substring(0, 16)}'
                  '${_n((e.value as Map)['mean']).padLeft(6)} ${_n((e.value as Map)['p50']).padLeft(6)}'
                  ' ${_n((e.value as Map)['p95']).padLeft(6)} ${_n((e.value as Map)['max']).padLeft(6)}'
            else
              ' ${(labels[e.key] ?? e.key).toString().padRight(16).substring(0, 16)}   unavailable',
          'TRACKING (share of processed frames)',
          ' ${((d['trackingRate'] as Map?) ?? {}).entries.map((e) => '${e.key} ${_n(e.value is num ? (e.value as num) * 100 : null, 0)}%').join('  ')}',
          'INPUT ${(d['input'] as Map?)?.entries.map((e) => '${e.key}=${e.value}').join(' ') ?? 'n/a'}',
          'DELEGATE ${(d['delegates'] as Map?)?.entries.where((e) => e.value != '').map((e) => '${e.key}=${e.value}').join(' ') ?? 'n/a'}',
          'EXPOSURE ${(d['exposure'] as Map?)?.entries.map((e) => '${e.key}=${e.value is num ? _n(e.value) : e.value}').join(' ') ?? 'n/a'}',
          'CLOCK ${d['clock']}  channel/s ${d['channelPackets']}',
        ];
        return Container(
          color: Colors.black87,
          padding: const EdgeInsets.all(8),
          child: Text(lines.join('\n'), style: style),
        );
      },
    );
  }
}
