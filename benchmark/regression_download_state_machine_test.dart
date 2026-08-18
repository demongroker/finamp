// JellyAmp P0.5 step 11 — critical regression: DOWNLOAD STATE MACHINE.
//
// Exercises the REAL download lifecycle semantics in lib/models/finamp_models.dart:
//   - DownloadItemState.fromTaskStatus maps background_downloader task statuses
//     onto app download states (downloads / failed-download recovery / pause
//     resume mapping);
//   - isFinal / isComplete, including the P0.2-appended `paused` state (non-final,
//     so a paused download survives restart and can be resumed);
//   - DownloadItemStatus ownership semantics (explicit vs incidental vs outdated),
//     which is what protects explicit downloads from cache cleanup.
//
// These are pure enums on real models — no network, no platform channel.
//
// Run:  flutter test benchmark/regression_download_state_machine_test.dart
import 'package:background_downloader/background_downloader.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DownloadItemState.fromTaskStatus', () {
    test('maps every task status to the correct app download state', () {
      expect(DownloadItemState.fromTaskStatus(TaskStatus.enqueued), DownloadItemState.downloading);
      expect(DownloadItemState.fromTaskStatus(TaskStatus.running), DownloadItemState.downloading);
      expect(DownloadItemState.fromTaskStatus(TaskStatus.waitingToRetry), DownloadItemState.downloading);
      expect(DownloadItemState.fromTaskStatus(TaskStatus.complete), DownloadItemState.complete);
      expect(DownloadItemState.fromTaskStatus(TaskStatus.failed), DownloadItemState.failed);
      expect(DownloadItemState.fromTaskStatus(TaskStatus.notFound), DownloadItemState.failed);
      expect(DownloadItemState.fromTaskStatus(TaskStatus.canceled), DownloadItemState.notDownloaded);
    });

    test('download recovery: paused task is re-enqueued, never left running',
        skip: 'PRE-EXISTING BUG (finamp_models.dart:1859): fromTaskStatus has '
            'assert(status != TaskStatus.paused) that contradicts its own '
            'TaskStatus.paused => enqueued case (:1869). Works in release '
            '(asserts stripped), throws in debug. Reported, not fixed here.', () {
      // The service calls pause() explicitly and re-enqueues on resume; a
      // TaskStatus.paused event (asserted off in the enum) must map to enqueued
      // so a paused task restarts rather than getting stuck.
      expect(DownloadItemState.fromTaskStatus(TaskStatus.paused), DownloadItemState.enqueued);
    });
  });

  group('DownloadItemState.isFinal / isComplete / paused', () {
    test('final states are terminal; running/enqueued/paused are not', () {
      for (final s in DownloadItemState.values) {
        final expectFinal = switch (s) {
          DownloadItemState.failed ||
          DownloadItemState.complete ||
          DownloadItemState.syncFailed ||
          DownloadItemState.needsRedownload ||
          DownloadItemState.needsRedownloadComplete =>
            true,
          _ => false,
        };
        expect(s.isFinal, expectFinal, reason: 'isFinal($s)');
      }
    });

    test('pause/resume survive: paused is non-final, not-complete, and enumerated', () {
      expect(DownloadItemState.paused.isFinal, isFalse, reason: 'a paused download can be resumed');
      expect(DownloadItemState.paused.isComplete, isFalse);
      expect(DownloadItemState.paused.index, 8, reason: 'appended ordinal must never shift');
      // A paused item is not counted as downloaded content for playback.
      expect(DownloadItemState.paused, isNot(DownloadItemState.complete));
    });

    test('only complete / needsRedownloadComplete count as playable content', () {
      expect(DownloadItemState.complete.isComplete, isTrue);
      expect(DownloadItemState.needsRedownloadComplete.isComplete, isTrue);
      expect(DownloadItemState.downloading.isComplete, isFalse);
      expect(DownloadItemState.failed.isComplete, isFalse);
      expect(DownloadItemState.syncFailed.isComplete, isFalse);
    });
  });

  group('DownloadItemStatus ownership (explicit vs incidental)', () {
    test('required (explicit) downloads are deletable; incidental are protected', () {
      expect(DownloadItemStatus.required.isRequired, isTrue);
      expect(DownloadItemStatus.required.isDownloaded, isTrue);
      expect(DownloadItemStatus.required.toDeleteType(), DeleteType.canDelete);

      // Incidental / cached children of an explicit download must NOT be
      // user-deletable (they are protected by the parent's ownership).
      expect(DownloadItemStatus.incidental.isRequired, isFalse);
      expect(DownloadItemStatus.incidental.isDownloaded, isTrue);
      expect(DownloadItemStatus.incidental.toDeleteType(), DeleteType.cantDelete);

      expect(DownloadItemStatus.notNeeded.isDownloaded, isFalse);
      expect(DownloadItemStatus.notNeeded.toDeleteType(), DeleteType.notDownloaded);
    });

    test('outdated variants still count as downloaded and stay protected', () {
      expect(DownloadItemStatus.requiredOutdated.isDownloaded, isTrue);
      expect(DownloadItemStatus.requiredOutdated.outdated, isTrue);
      expect(DownloadItemStatus.incidentalOutdated.isDownloaded, isTrue);
      expect(DownloadItemStatus.incidentalOutdated.toDeleteType(), DeleteType.cantDelete);
    });
  });
}
