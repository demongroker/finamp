// JellyAmp P0.1 ON-DEVICE benchmark harness (integration test).
//
// DEVICE-ONLY. This measures the metrics that cannot be obtained headless on a
// Linux box: real app-shell time, cold/warm launch, useful-library-UI time,
// album/artist screen render, scroll frame rate, peak device memory, offline
// startup, and real Isar DB query latency (requires the app runtime + native
// libisar.so). It is a documented stub here; the numbers it would produce are
// listed as PENDING in benchmark/results/BASELINE_*.md until run on a device.
//
// How to run (Android emulator/device with the generated datasets deployed, or
// against a populated Jellyfin server):
//   flutter test integration_test/benchmark_integration_test.dart
//   (this file currently lives at benchmark/integration_test.dart; move it under
//    integration_test/ when running on-device, or invoke it by path.)
//
// Output: key=value lines and a JSON report under benchmark/results/device_<date>.json.

import 'dart:convert';
import 'dart:io';

import 'package:finamp/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('P0.1 device benchmark: startup, render, DB, search, memory',
      (tester) async {
    final marks = <String, String>{};

    // ---- Startup / app-shell timing -------------------------------------
    final t0 = DateTime.now();
    app.main(const []);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    marks['app_main_to_first_frame_ms'] =
        '${DateTime.now().difference(t0).inMilliseconds}';

    // First rasterized frame = "app shell visible".
    final shellMs = await _awaitUntil(
      () => binding.renderViewElement != null,
      const Duration(seconds: 20),
    );
    marks['app_shell_visible_ms'] = '$shellMs';

    // ---- DB query latency (real Isar, via DownloadsService) -------------
    // NOTE: requires a populated library (server sync or downloaded items).
    marks['db_query_note'] =
        'requires populated device library; measure downloadsService.getAllTracks() '
        'and getAllCollections() timing here at 10k/25k/50k/100k';

    // ---- Search latency (real provider round-trip) -----------------------
    marks['search_latency_note'] =
        'measure groupedSearchProvider latency for representative queries at scale';

    // ---- Scroll FPS ------------------------------------------------------
    marks['scroll_fps_note'] =
        'capture ListView frame timestamps during fast scroll in integration test; '
        'report median/p95 inter-frame gap vs 16.7ms budget';

    // ---- Peak memory ------------------------------------------------------
    marks['memory_note'] =
        'read PlatformDispatcher.views.first / Runtime.deviceMemory or '
        'DebugMemoryInfo on Android to report peak while 100k library is open';

    // ---- Offline startup ---------------------------------------------------
    marks['offline_startup_note'] =
        'cold launch with network blocked; time to usable downloaded library';

    _writeReport(marks);
  });
}

Future<int> _awaitUntil(bool Function() cond, Duration timeout) async {
  final start = DateTime.now();
  while (!cond()) {
    if (DateTime.now().difference(start) > timeout) break;
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
  return DateTime.now().difference(start).inMilliseconds;
}

void _writeReport(Map<String, String> marks) {
  final dir = Directory('benchmark/results');
  dir.createSync(recursive: true);
  final file = File('benchmark/results/device_${DateTime.now().toIso8601String().substring(0, 10)}.json');
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(marks));
  // ignore: avoid_print
  print('DEVICE_REPORT=${file.path}');
  marks.forEach((k, v) {
    // ignore: avoid_print
    print('$k=$v');
  });
}
