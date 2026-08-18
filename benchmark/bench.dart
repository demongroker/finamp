// JellyAmp P0.1 headless benchmark harness (pure Dart, no Flutter deps).
//
// Measures the parts of the large-library pipeline that CAN be measured on a
// headless Linux box without the app runtime: raw JSON decode cost and dataset
// footprint. The app-model-level costs (real BaseItemDto.fromJson parsing, the
// client-side sortItems() sorter, and SearchQuery matching) need the Flutter
// runtime and are measured headless by `benchmark/bench_test.dart`
// (`flutter test benchmark/bench_test.dart`). Genuine device-only metrics
// (app-shell time, cold/warm launch, scroll FPS, peak device memory, offline
// startup) run via the on-device integration harness
// (`benchmark/integration_test.dart`) and are PENDING here — see
// benchmark/results/BASELINE_*.md.
//
// Usage (from repo root):
//   dart run benchmark/bench.dart                      # all datasets in benchmark/data
//   dart run benchmark/bench.dart --scales 10k,100k    # subset
//   dart run benchmark/bench.dart --type tracks        # subset by type
//   dart run benchmark/bench.dart --runs 5             # repetitions per measurement
//   dart run benchmark/bench.dart --format json        # output JSON to stdout
//
// Output: key=value lines (or JSON) suitable for capturing into the baseline file.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

const String _dataDir = 'benchmark/data';

void main(List<String> args) {
  var runs = 3;
  var format = 'kv';
  List<String>? scales;
  List<String>? types;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--runs':
        runs = int.parse(args[++i]);
        break;
      case '--format':
        format = args[++i];
        break;
      case '--scales':
        scales = args[++i].split(',').map((s) => s.trim()).toList();
        break;
      case '--type':
        types = args[++i].split(',').map((s) => s.trim()).toList();
        break;
      default:
        throw ArgumentError('Unknown flag: ${args[i]}');
    }
  }

  final files = Directory(_dataDir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (scales != null) {
    files.retainWhere((f) => scales!.any((s) => f.path.contains('_${s}_')));
  }
  if (types != null) {
    files.retainWhere((f) => types!.any((t) => f.path.endsWith('_$t.json')));
  }

  if (files.isEmpty) {
    stderr.writeln('No datasets found under $_dataDir. Run the generator first:');
    stderr.writeln('  dart run benchmark/dataset_generator.dart');
    exitCode = 2;
    return;
  }

  final rows = <Map<String, Object>>[];

  for (final f in files) {
    final name = f.path.split('/').last.replaceFirst('.json', '');
    final bytes = f.readAsBytesSync();
    final mb = bytes.length / (1024 * 1024);

    // Raw jsonDecode timing (cold start of the decode path, averaged).
    final decodeMs = _measure(() {
      jsonDecode(utf8.decode(bytes));
    }, runs);
    // Warm decode (operating-system page cache hot) for comparison.
    final decodeWarmMs = _measure(() {
      jsonDecode(utf8.decode(bytes));
    }, runs);
    // String decoding cost separately from map building.
    final utf8Ms = _measure(() {
      utf8.decode(bytes);
    }, runs);

    rows.add({
      'dataset': name,
      'tracks': _trackCount(name),
      'type': _typeOf(name),
      'file_mb': mb,
      'decode_cold_ms': decodeMs,
      'decode_warm_ms': decodeWarmMs,
      'utf8_decode_ms': utf8Ms,
    });
  }

  if (format == 'json') {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(rows));
  } else {
    for (final r in rows) {
      final kv = r.entries.map((e) => '${e.key}=${e.value}').join(' ');
      stdout.writeln(kv);
    }
  }
}

double _measure(void Function() fn, int runs) {
  // Warm up the JIT once so the first (compilation-heavy) iteration does not
  // dominate the reported average.
  fn();
  final stopwatch = Stopwatch()..start();
  for (var i = 0; i < runs; i++) {
    fn();
  }
  stopwatch.stop();
  return stopwatch.elapsedMicroseconds / (1000.0 * runs);
}

int _trackCount(String name) {
  final m = RegExp(r'(\d+)k').firstMatch(name);
  if (m == null) return 0;
  return int.parse(m.group(1)!) * 1000;
}

String _typeOf(String name) {
  for (final t in ['tracks', 'albums', 'artists']) {
    if (name.endsWith('_$t')) return t;
  }
  return 'unknown';
}
