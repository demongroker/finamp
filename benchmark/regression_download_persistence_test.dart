// JellyAmp P0.5 step 11 — critical regression: DOWNLOAD PERSISTENCE,
// RESTORATION, PAUSE/RESUME AND OFFLINE PLAYBACK STATE.
//
// Exercises the REAL Isar-backed DownloadItem model + DownloadStub seeding
// (lib/models/finamp_models.dart) against a real database on a temp dir, with
// a close/reopen in the middle to simulate an app restart. No network. Asserts
// the roadmap-critical invariants:
//   - existing downloads survive an app restart in their exact state
//     (complete / paused / enqueued) — existing-download restoration, pause/
//     resume persistence;
//   - the explicit-download ownership marker (userTranscodingProfile) survives,
//     so explicit user downloads remain recognizable and protected from cache
//     cleanup after restart;
//   - a complete download with a path is offline-playable content; incomplete
//     ones are not.
//
// Run:  flutter test benchmark/regression_download_persistence_test.dart
import 'dart:io';

import 'package:finamp/models/finamp_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'regression_helpers.dart';

void main() {
  late Isar isar;
  late Directory tempDir;
  final dbName = 'downloads';

  final ownerMarker = DownloadProfile(transcodeCodec: FinampTranscodingCodec.opus, bitrate: 128000);

  Future<void> seed() async {
    await isar.writeTxn(() async {
      await isar.downloadItems.putAll([
        // Explicit track download: complete + owned by the user.
        seedDownload('trk-1', 'Track One',
            state: DownloadItemState.complete, path: 'album/track_one.flac', userProfile: ownerMarker),
        // A paused download (P0.2): not final, must survive restart paused.
        seedDownload('trk-2', 'Track Two', state: DownloadItemState.paused, userProfile: ownerMarker),
        // A queued download waiting to run.
        seedDownload('trk-3', 'Track Three', state: DownloadItemState.enqueued, userProfile: ownerMarker),
        // An incidental/cached child (no ownership marker): must NOT be
        // confused with an explicit user download after restart.
        seedDownload('trk-4', 'Incidental', state: DownloadItemState.complete, path: 'cache/incidental.flac'),
      ]);
    });
  }

  test('existing downloads survive an app restart in their exact state', () async {
    (isar, tempDir) = await openTempIsar([DownloadItemSchema], name: dbName);
    await seed();

    // Sanity: 4 rows seeded.
    expect(await isar.downloadItems.count(), 4);

    // ---- simulate app restart: close the DB and reopen on the same dir ----
    final dir = tempDir;
    await isar.close(deleteFromDisk: false);
    isar = await Isar.open([DownloadItemSchema], directory: dir.path, name: dbName);

    final rows = await isar.downloadItems.where().findAll();
    expect(rows.length, 4, reason: 'no download row lost across restart');

    // Exact-state restoration.
    expect(rows.singleWhere((r) => r.id == 'trk-1').state, DownloadItemState.complete);
    expect(rows.singleWhere((r) => r.id == 'trk-1').path, 'album/track_one.flac');
    expect(rows.singleWhere((r) => r.id == 'trk-2').state, DownloadItemState.paused,
        reason: 'pause survives restart (resumable)');
    expect(rows.singleWhere((r) => r.id == 'trk-3').state, DownloadItemState.enqueued);
  });

  test('explicit-download ownership marker survives restart (cache-cleanup protection)', () async {
    final rows = await isar.downloadItems.where().findAll();

    final explicit = rows.singleWhere((r) => r.id == 'trk-1');
    final incidental = rows.singleWhere((r) => r.id == 'trk-4');

    // The marker isExplicitUserDownload() checks first — it must survive.
    expect(explicit.userTranscodingProfile, isNotNull, reason: 'explicit download stays owned');
    expect(incidental.userTranscodingProfile, isNull, reason: 'incidental cache stays unowned');
  });

  test('offline playback readiness: only complete+path downloads are playable offline', () async {
    final rows = await isar.downloadItems.where().findAll();
    final playableOffline = rows.where((r) => r.state.isComplete && r.path != null).toList();

    // trk-1 is playable offline; paused/enqueued/incidental-complete-with-path
    // semantics: only state-complete rows are trusted for offline playback.
    expect(playableOffline.map((r) => r.id), contains('trk-1'));
    expect(rows.singleWhere((r) => r.id == 'trk-2').state.isComplete, isFalse,
        reason: 'paused item is not playable offline yet');
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });
}
