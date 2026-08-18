// JellyAmp P0.5 step 11 — shared helpers for the critical regression suite.
//
// Reused by the benchmark/regression_*_test.dart files. Provides:
//   - real Isar core resolution + temp-dir Isar open (same pattern as the
//     migration benchmark) for tests that need REAL models persisted to disk;
//   - pure-model fixture builders (BaseItemDto audio items with media streams,
//     DownloadItem seeding, FinampQueueInfo construction) so each test file
//     stays focused on the behavior under test.
//
// NOT a test file: `*_test.dart` is the only pattern `flutter test` picks up.

import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart' show BaseItemDto, BaseItemId, MediaSourceInfo, MediaStream;
import 'package:isar/isar.dart';

/// Resolve the pinned native Isar core (libisar.so) for the current host ABI
/// from the isar_flutter_libs package in .dart_tool/package_config.json.
String resolveIsarCore() {
  final pkgConfig = File('.dart_tool/package_config.json');
  if (!pkgConfig.existsSync()) {
    throw StateError('.dart_tool/package_config.json not found');
  }
  final map = jsonDecode(pkgConfig.readAsStringSync()) as Map<String, dynamic>;
  for (final p in (map['packages'] as List).cast<Map<String, dynamic>>()) {
    if (p['name'] == 'isar_flutter_libs') {
      final root = Uri.parse(p['rootUri'] as String);
      final pkgPath = File.fromUri(root).path;
      final so = File('$pkgPath/linux/libisar.so');
      if (so.existsSync()) return so.path;
      throw StateError('libisar.so not found under $pkgPath/linux');
    }
  }
  throw StateError('isar_flutter_libs package not found in package_config');
}

/// Open a real Isar instance on a fresh temp directory.
Future<(Isar, Directory)> openTempIsar(
  List<CollectionSchema<dynamic>> schemas, {
  required String name,
}) async {
  await Isar.initializeIsarCore(libraries: {Abi.current(): resolveIsarCore()});
  final dir = await Directory.systemTemp.createTemp('jellyamp_regression_$name');
  final isar = await Isar.open(schemas, directory: dir.path, name: name);
  return (isar, dir);
}

// ---------------------------------------------------------------------------
// Pure-model fixture builders
// ---------------------------------------------------------------------------

/// A single audio media stream (FLAC or MP3) for a track item.
MediaStream _audioStream({String codec = 'flac', int? bitDepth = 24}) => MediaStream(
      type: 'Audio',
      index: 0,
      isInterlaced: false,
      isDefault: true,
      isForced: false,
      isExternal: false,
      isTextSubtitleStream: false,
      supportsExternalStream: false,
      codec: codec,
      bitDepth: bitDepth,
    );

MediaSourceInfo _mediaSource({String codec = 'flac', int? bitDepth = 24}) => MediaSourceInfo(
      protocol: 'File',
      type: 'Default',
      isRemote: false,
      supportsTranscoding: true,
      supportsDirectStream: true,
      supportsDirectPlay: true,
      isInfiniteStream: false,
      requiresOpening: false,
      requiresClosing: false,
      requiresLooping: false,
      supportsProbing: true,
      readAtNativeFramerate: false,
      ignoreDts: false,
      ignoreIndex: false,
      genPtsInput: false,
      mediaStreams: [_audioStream(codec: codec, bitDepth: bitDepth)],
    );

/// A Jellyfin Audio item (track) with an optional FLAC stream.
BaseItemDto audioItem(
  String id,
  String name, {
  int? productionYear,
  List<String>? genres,
  String codec = 'flac',
  int? bitDepth = 24,
  bool withSource = true,
  String? parentId,
}) =>
    BaseItemDto(
      id: BaseItemId(id),
      name: name,
      type: 'Audio',
      productionYear: productionYear,
      genres: genres,
      parentId: parentId == null ? null : BaseItemId(parentId),
      mediaSources: withSource ? [_mediaSource(codec: codec, bitDepth: bitDepth)] : null,
    );

/// A Jellyfin MusicAlbum item.
BaseItemDto albumItem(String id, String name, {int? productionYear, List<String>? genres}) =>
    BaseItemDto(
      id: BaseItemId(id),
      name: name,
      type: 'MusicAlbum',
      productionYear: productionYear,
      genres: genres,
    );

/// Seed a real [DownloadItem] (from a real [DownloadStub]) in the given state.
DownloadItem seedDownload(
  String id,
  String name, {
  required DownloadItemState state,
  String? path,
  DownloadProfile? userProfile,
}) {
  final item = DownloadStub.fromItem(
    type: DownloadItemType.track,
    item: audioItem(id, name, codec: 'flac', bitDepth: 24),
  ).asItem(null);
  item.state = state;
  item.path = path;
  item.userTranscodingProfile = userProfile;
  return item;
}

/// Build a [MediaItem] whose extras carry the itemJson a real [FinampQueueItem]
/// requires, plus an optional duration (ms) for ordering tests.
MediaItem queueMediaItem(String id, String name, {int? durationMs, String? parentId}) {
  // PascalCase Jellyfin JSON (as parsed by BaseItemDto.fromJson). The "Id" key
  // is what FinampQueueItem.baseItemId reads directly.
  final itemJson = <String, dynamic>{
    'Id': id,
    'Name': name,
    'Type': 'Audio',
    if (parentId != null) 'ParentId': parentId,
  };
  return MediaItem(
    id: id,
    title: name,
    duration: durationMs == null ? null : Duration(milliseconds: durationMs),
    extras: {'itemJson': itemJson},
  );
}

/// A real [FinampQueueItem] backed by [queueMediaItem].
FinampQueueItem queueTrack(String id, String name,
    {int? durationMs, QueueItemSourceType sourceType = QueueItemSourceType.album, String? parentId}) {
  return FinampQueueItem(
    item: queueMediaItem(id, name, durationMs: durationMs, parentId: parentId),
    source: QueueItemSource.rawId(
      type: sourceType,
      name: const QueueItemSourceName(type: QueueItemSourceNameType.preTranslated, pretranslatedName: 'src'),
      id: 'src',
    ),
    type: QueueItemQueueType.queue,
  );
}
