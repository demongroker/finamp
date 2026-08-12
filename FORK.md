# Jellyamp — fork notes

**Repo:** https://github.com/demongroker/jellyamp  
**Branch:** `features/share-seek-qol`  
**Upstream:** [finamp-app/finamp](https://github.com/finamp-app/finamp) (`redesign`)  
**Local path (this host):** `/home/adnan/finamp`

## Identity

| Item | Value |
|------|--------|
| App name | Jellyamp |
| Android `applicationId` | `com.demongroker.jellyamp` |
| Kotlin namespace | `com.unicornsonlsd.finamp` (unchanged) |
| Default accent | `#AA5CC3` |
| Icon bg | `#0B1220` |
| Jellyfin `Client` header | `Jellyamp` |

## Feature map

| Feature | Code |
|---------|------|
| Share original audio (FLAC…) | `lib/services/media_share_helper.dart`, `share_track_file_menu_entry.dart` |
| Share / copy link / title | `share_item_link_menu_entry.dart`, `copy_item_info_menu_entry.dart` |
| Long-press / double-tap seek | `playback_seek_helper.dart`, `player_buttons.dart`, `player_screen_album_image.dart` |
| Share APK + Wi‑Fi serve | `lib/services/app_share_helper.dart`, Settings tiles |
| Brand assets | `assets/icon/`, `images/jellyamp_icon.svg`, `docs/brand/`, `GitHub_Banner.png` |

## Releases

https://github.com/demongroker/jellyamp/releases

## Build APK

```bash
export JAVA_HOME=$HOME/sdk/java
export ANDROID_SDK_ROOT=$HOME/sdk/android
export PATH="$HOME/.cargo/bin:$JAVA_HOME/bin:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$HOME/sdk/flutter/bin:$PATH"
cd /home/adnan/finamp   # or your clone
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

Signing: `android/key.properties` + keystore (gitignored).

## Sync upstream

```bash
git fetch upstream
git merge upstream/redesign   # or rebase — resolve conflicts carefully
```
