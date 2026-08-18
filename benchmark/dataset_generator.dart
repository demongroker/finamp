// JellyAmp P0.1 benchmark dataset generator.
//
// Reproducibly synthesizes Jellyfin/JellyAmp-shaped library datasets at the
// P0.1 target scales (10k / 25k / 50k / 100k tracks). Output is written as
// JSON in the exact wire shape the app parses through the REAL parsing path:
//   QueryResult_BaseItemDto = { "Items": [BaseItemDto...], "TotalRecordCount": N, "StartIndex": 0 }
// with PascalCase field names (jellyfin_models.g.dart `_$BaseItemDtoFromJson`).
//
// Why JSON-in-API-shape instead of an Isar import:
//   - The app does NOT keep the browsable library in Isar. Library browsing
//     (music_screen_provider) fetches items from the Jellyfin API and parses
//     them via BaseItemDto.fromJson, then sorts/filters client-side. So the
//     dominant "large library" cost in online mode is large API responses +
//     JSON parsing + client-side sort/filter. These files exercise exactly
//     that path headless via `flutter test benchmark/bench_test.dart`.
//   - Isar download/library import would require the app's native libisar.so
//     (device / app runtime), which is not available to a bare headless Dart
//     script on this box; that path is covered on-device by the integration
//     harness instead (see benchmark/integration_test.dart).
//
// Determinism: a fixed seed (default 0x1e11amp) drives a single Random instance,
// so identical input flags produce byte-identical output on every run.
//
// Usage (from repo root):
//   dart run benchmark/dataset_generator.dart                       # all 4 scales, tracks
//   dart run benchmark/dataset_generator.dart --scales 10k,100k     # selected scales
//   dart run benchmark/dataset_generator.dart --type albums         # also albums / artists
//   dart run benchmark/dataset_generator.dart --out benchmark/data  # output dir
//   dart run benchmark/dataset_generator.dart --seed 42             # custom seed
//
// Output: benchmark/data/library_<N>_<type>.json  (N = 10000|25000|50000|100000)

import 'dart:convert';
import 'dart:io';
import 'dart:math';

const int _defaultSeed = 0x1E11; // readable constant name for the fixed seed
const String _defaultOutDir = 'benchmark/data';
const List<String> _scales = ['10k', '25k', '50k', '100k'];
const List<String> _types = ['tracks', 'albums', 'artists'];

const List<String> _codecs = ['flac', 'mp3', 'opus', 'aac', 'alac', 'wav', 'ogg'];
const List<String> _genres = [
  'Rock', 'Pop', 'Jazz', 'Classical', 'Electronic', 'Hip-Hop', 'Metal',
  'Progressive Rock', 'Ambient', 'Blues', 'Folk', 'Soul', 'Reggae', 'Punk',
  'Country', 'Synthwave', 'Post-Rock', 'Shoegaze', 'Techno', 'Indie',
];

class DatasetOptions {
  DatasetOptions(this.scales, this.types, this.outDir, this.seed);
  final List<String> scales;
  final List<String> types;
  final String outDir;
  final int seed;
}

DatasetOptions _parseArgs(List<String> args) {
  List<String> scales = List.of(_scales);
  List<String> types = List.of(_types);
  String outDir = _defaultOutDir;
  int seed = _defaultSeed;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--scales':
        scales = args[++i].split(',').map((s) => s.trim()).toList();
        break;
      case '--type':
        types = args[++i].split(',').map((s) => s.trim()).toList();
        break;
      case '--out':
        outDir = args[++i];
        break;
      case '--seed':
        seed = int.parse(args[++i]);
        break;
      default:
        throw ArgumentError('Unknown flag: ${args[i]}');
    }
  }
  return DatasetOptions(scales, types, outDir, seed);
}

int _trackCountForScale(String scale) => switch (scale) {
      '10k' => 10000,
      '25k' => 25000,
      '50k' => 50000,
      '100k' => 100000,
      _ => throw ArgumentError('Unknown scale "$scale" (expected 10k/25k/50k/100k)'),
    };

String _typeOf(String type) => switch (type) {
      'tracks' => 'Audio',
      'albums' => 'MusicAlbum',
      'artists' => 'MusicArtist',
      _ => throw ArgumentError('Unknown type "$type"'),
    };

// The numeric portion of a scale (e.g. '100k' -> 100000) is used to size the
// bounded artist/album pools so relationships stay realistic and stable.
class LibraryGen {
  LibraryGen(int seed) : _rng = Random(seed);
  final Random _rng;

  int albumCount = 0;
  int artistCount = 0;
  late String _container;
  late String _codec;
  late String _bitDepth;
  late int _sampleRate;
  late int _bitRate;

  void configure(int scale) {
    // ~10 tracks per album, ~4 albums per artist => bounded pools.
    albumCount = (scale / 10).ceil();
    artistCount = (albumCount / 4).ceil();
    _container = _codecs[_rng.nextInt(_codecs.length)];
    _codec = _codecs[_rng.nextInt(_codecs.length)];
    _bitDepth = '${[16, 24, 32][_rng.nextInt(3)]}';
    _sampleRate = [44100, 48000, 96000][_rng.nextInt(3)];
    _bitRate = 320000 + _rng.nextInt(1400000);
  }

  String _pick(List<String> pool) => pool[_rng.nextInt(pool.length)];

  String _idFor(String prefix, int idx) => '$prefix-${idx.toString().padLeft(6, '0')}';

  String _titleFor(String type, int idx) {
    const adjectives = ['Midnight', 'Electric', 'Silent', 'Golden', 'Broken',
        'Neon', 'Distant', 'Velvet', 'Static', 'Hollow'];
    const nouns = ['Horizon', 'River', 'Circuit', 'Garden', 'Signal',
        'Mountain', 'Echo', 'Lantern', 'Machines', 'Weather'];
    final a = _pick(adjectives);
    final n = _pick(nouns);
    final num = _rng.nextInt(9999) + 1;
    return switch (type) {
      'tracks' => '$a $n $num',
      'albums' => '$a $n',
      _ => '$a $n Collective',
    };
  }

  String _artistName(int idx) => 'Artist $idx';

  Map<String, dynamic> _userData() => {
        'PlaybackPositionTicks': _rng.nextInt(20000000),
        'PlayCount': _rng.nextInt(500),
        'IsFavorite': _rng.nextBool(),
        'Played': _rng.nextBool(),
        if (_rng.nextBool()) 'LastPlayedDate': '2026-0${_rng.nextInt(8) + 1}-1${_rng.nextInt(9)}T12:00:00.0000000Z',
      };

  Map<String, dynamic> _track(int idx) {
    final albumIdx = _rng.nextInt(albumCount);
    final artistIdx = _rng.nextInt(artistCount);
    final featIdx = _rng.nextInt(artistCount);
    final year = 1960 + _rng.nextInt(66);
    final runTicks = (1 + _rng.nextInt(9)) * 100000000 + _rng.nextInt(99999999); // 100s-1000s
    final primaryTag = 'img-${_rng.nextInt(albumCount * 4)}';
    return {
      'Name': _titleFor('tracks', idx),
      'Id': _idFor('track', idx),
      'SortName': 'track $idx',
      'Container': _container,
      'RunTimeTicks': runTicks,
      'ProductionYear': year,
      'IndexNumber': _rng.nextInt(24) + 1,
      'ParentIndexNumber': 1,
      'ParentId': _idFor('album', albumIdx),
      'AlbumId': _idFor('album', albumIdx),
      'Album': _titleFor('albums', albumIdx),
      'AlbumArtist': _artistName(artistIdx),
      // jellyfin_models.g.dart parses AlbumArtists as List<NameIdPair> (maps
      // with Name/Id/Type), g.dart:3839-3841 — NOT List<String>. Emit the same
      // shape as ArtistItems below.
      'AlbumArtists': [
        {'Name': _artistName(artistIdx), 'Id': _idFor('artist', artistIdx), 'Type': 'MusicArtist'},
      ],
      'Artists': featIdx == artistIdx
          ? [_artistName(artistIdx)]
          : [_artistName(artistIdx), _artistName(featIdx)],
      'ArtistItems': [
        {'Name': _artistName(artistIdx), 'Id': _idFor('artist', artistIdx), 'Type': 'MusicArtist'},
      ],
      'Genres': [_pick(_genres), _pick(_genres)],
      'ImageTags': {'Primary': primaryTag},
      'Type': 'Audio',
      'MediaType': 'Audio',
      'Path': '/mnt/library/${_artistName(artistIdx)}/${_titleFor('albums', albumIdx)}/$idx.flac',
      'MediaSources': [
        {
          'Protocol': 'File',
          'Path': '/mnt/library/${_artistName(artistIdx)}/${_titleFor('albums', albumIdx)}/$idx.flac',
          'Type': 'Audio',
          'Container': _container,
          'RunTimeTicks': runTicks,
          'IsRemote': false,
          'SupportsTranscoding': false,
          'SupportsDirectPlay': true,
          'SupportsDirectStream': true,
          'IsInfiniteStream': false,
          'RequiresOpening': false,
          'RequiresClosing': false,
          'RequiresLooping': false,
          'SupportsProbing': true,
          // jellyfin_models.g.dart _$MediaSourceInfoFromJson requires these as
          // non-null bools (g.dart:4196 ReadAtNativeFramerate, :4201 IgnoreDts,
          // :4202 IgnoreIndex, :4203 GenPtsInput); omit them and the headless
          // app-model parse path throws (null check on a non-null `as bool`).
          'ReadAtNativeFramerate': false,
          'IgnoreDts': false,
          'IgnoreIndex': false,
          'GenPtsInput': false,
          'MediaStreams': [
            {
              'Codec': _codec,
              'Type': 'Audio',
              'BitRate': _bitRate,
              'BitDepth': int.parse(_bitDepth),
              'SampleRate': _sampleRate,
              'Channels': 2,
              'Index': 0,
              'IsInterlaced': false,
              'IsDefault': true,
              'IsForced': false,
              'IsExternal': false,
              'IsTextSubtitleStream': false,
              'SupportsExternalStream': false,
            },
            {
              'Codec': 'mjpeg',
              'Type': 'EmbeddedImage',
              'Index': 1,
              'IsInterlaced': false,
              'IsDefault': false,
              'IsForced': false,
              'IsExternal': false,
              'IsTextSubtitleStream': false,
              'SupportsExternalStream': false,
            },
          ],
        },
      ],
      'UserData': _userData(),
      'DateCreated': '20${_rng.nextInt(10)}-0${_rng.nextInt(9) + 1}-1${_rng.nextInt(9)}T09:30:00.0000000Z',
    };
  }

  Map<String, dynamic> _album(int idx) {
    final artistIdx = _rng.nextInt(artistCount);
    final year = 1960 + _rng.nextInt(66);
    return {
      'Name': _titleFor('albums', idx),
      'Id': _idFor('album', idx),
      'SortName': 'album $idx',
      'RunTimeTicks': (40 + _rng.nextInt(30)) * 100000000,
      'ProductionYear': year,
      'ParentId': _idFor('artist', artistIdx),
      'AlbumArtist': _artistName(artistIdx),
      // Same List<NameIdPair> shape as _track(): AlbumArtists is maps, not
      // List<String> (jellyfin_models.g.dart:3839-3841).
      'AlbumArtists': [
        {'Name': _artistName(artistIdx), 'Id': _idFor('artist', artistIdx), 'Type': 'MusicArtist'},
      ],
      'Artists': [_artistName(artistIdx)],
      'ArtistItems': [
        {'Name': _artistName(artistIdx), 'Id': _idFor('artist', artistIdx), 'Type': 'MusicArtist'},
      ],
      'Genres': [_pick(_genres)],
      'ImageTags': {'Primary': 'img-album-$idx'},
      'Type': 'MusicAlbum',
      'MediaType': 'Audio',
      'ChildCount': 1 + _rng.nextInt(20),
      'RecursiveItemCount': 1 + _rng.nextInt(24),
      'UserData': _userData(),
      'DateCreated': '20${_rng.nextInt(10)}-0${_rng.nextInt(9) + 1}-1${_rng.nextInt(9)}T09:30:00.0000000Z',
    };
  }

  Map<String, dynamic> _artist(int idx) => {
        'Name': _artistName(idx),
        'Id': _idFor('artist', idx),
        'SortName': 'artist $idx',
        'Type': 'MusicArtist',
        'MediaType': 'Audio',
        'ImageTags': {'Primary': 'img-artist-$idx'},
        'ChildCount': 1 + _rng.nextInt(40),
        'UserData': _userData(),
        'DateCreated': '20${_rng.nextInt(10)}-0${_rng.nextInt(9) + 1}-1${_rng.nextInt(9)}T09:30:00.0000000Z',
      };

  Map<String, dynamic> _itemFor(String type, int idx) => switch (type) {
        'tracks' => _track(idx),
        'albums' => _album(idx),
        _ => _artist(idx),
      };
}

/// Returns the full QueryResult_BaseItemDto JSON map for a given scale/type.
Map<String, dynamic> generateResult(LibraryGen gen, int count, String type) {
  gen.configure(count);
  final items = <Map<String, dynamic>>[
    for (var i = 0; i < count; i++) gen._itemFor(type, i),
  ];
  return {
    'Items': items,
    'TotalRecordCount': count,
    'StartIndex': 0,
  };
}

void _emitResult(String path, Map<String, dynamic> result) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  final sink = file.openWrite();
  // Single-line JSON keeps the file compact; deterministic encoding via
  // JsonEncoder with an indent of 0 (stable key order from LinkedHashMap).
  sink.write(const JsonEncoder.withIndent('').convert(result));
  sink.close().then((_) {
    stdout.writeln('wrote ${file.path} (${_mb(file.lengthSync())} MB)');
  });
}

String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(2);

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  final gen = LibraryGen(opts.seed);
  stdout.writeln('JellyAmp dataset generator (seed=${opts.seed}, out=${opts.outDir})');
  stdout.writeln('Generating ${opts.types.join(', ')} at ${opts.scales.join(', ')} tracks...');

  final start = DateTime.now();
  for (final type in opts.types) {
    for (final scale in opts.scales) {
      final count = _trackCountForScale(scale);
      final result = generateResult(gen, count, type);
      final path = '${opts.outDir}/library_${scale}_$type.json';
      _emitResult(path, result);
      await Future<void>.delayed(Duration.zero); // let the write flush
    }
  }
  final ms = DateTime.now().difference(start).inMilliseconds;
  stdout.writeln('Done in ${ms}ms.');
}
