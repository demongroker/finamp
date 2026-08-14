# Jellyamp Dependency Notes

This document explains the git-pinned dependencies in `pubspec.yaml` and why they are used instead of official releases.

## just_audio (custom fork)
- **Upstream**: https://github.com/ryanheise/just_audio
- **Current fork**: https://github.com/LennartEnns/just_audio_fork (commit 6dfdd07)
- **Reason**: Needed for queue/shuffle fixes that are not yet merged upstream (see https://github.com/ryanheise/just_audio/pull/1555).
- **Monitor**: Check the PR regularly. Revert to official once merged.

## just_audio_media_kit
- **Fork**: https://github.com/Komodo5197/just_audio_media_kit (branch `feat/queue-shuffle`)
- **Reason**: Queue + shuffle support required for Jellyamp's player.

## media-kit (Windows audio)
- **Fork**: https://github.com/Komodo5197/media-kit (specific commit)
- **Reason**: Transcoding support on Windows requires a newer MPV build than the official media-kit release provides.

## smtc_windows + flutter_rust_bridge
- **Forks**: frb_plugins and pinned `flutter_rust_bridge: 2.11.1`
- **Reason**: System media transport controls on Windows. The smtc_windows package depends on a very specific flutter_rust_bridge version; loose constraints in pubspec cause resolution failures.

## General policy
- All forks are documented here so future upstream merges are easier.
- When rebasing onto a new `finamp-app/finamp` redesign commit, re-test these areas first:
  - Gapless playback
  - Queue management
  - Windows build (if applicable)
  - Android media notification / lockscreen

Last updated: 2026-08-14 (by Xerxes)