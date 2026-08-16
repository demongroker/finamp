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
| Default accent | `#7DD3FC` (ice cyan) |
| Icon bg | `#0B0F14` (charcoal) |
| Theme | Ice liquid glass |
| APK ABI | arm64-v8a only (~40MB) |
| Jellyfin `Client` header | `Jellyamp` |

## Privacy / permissions

| Item | Value |
|------|--------|
| Analytics | None |
| Cloud backup | Disabled (`allowBackup=false`) |
| Storage permission | Removed; app-private downloads only |
| Runtime permission dialogs | Avoided (no storage/media/camera/location) |
| Required install-time | `INTERNET`, wake lock, media playback FGS |
| Docs | [PRIVACY.md](./PRIVACY.md) |

## Feature map

| Feature | Code |
|---------|------|
| Share original audio (FLAC…) | `lib/services/media_share_helper.dart`, `share_track_file_menu_entry.dart` |
| Share / copy link / title | `share_item_link_menu_entry.dart`, `copy_item_info_menu_entry.dart` |
| Long-press / double-tap seek | `playback_seek_helper.dart`, `player_buttons.dart`, `player_screen_album_image.dart` |
| Share APK + Wi‑Fi serve | `lib/services/app_share_helper.dart`, Settings tiles |
| Brand assets | `assets/icon/`, `images/jellyamp_icon.svg`, `docs/brand/`, `GitHub_Banner.png` |
| Clean home + UI polish | `DefaultSettings.homeScreenConfiguration`, `_migrateHomescreen()`, HomeScreen components, `color_schemes.g.dart` |
| Ice glass theme + logo | `lib/components/glass/`, ice color schemes, `assets/icon/*`, adaptive launcher |

## Home layout (Jellyamp clean)

Default home is intentionally sparse (reset via **Settings → Home → reset**):

| Area | Default |
|------|---------|
| Quick actions | Shuffle · Previous queue · Surprise me |
| Sections | Recently played · Newly added albums · Favorite albums · Recent queues |
| Tabs | Home, Albums, Artists, Playlists, Tracks (Genres off by default) |
| Player chips | Explicit + codec only |
| Theme | Jellyfin purple `#AA5CC3` |

Users still on the old 4-action / 7-section stock layout are **auto-migrated once** on launch if they never customized. Customized homes are left alone.

## Releases

https://github.com/demongroker/jellyamp/releases

## Docs

- [ROADMAP.md](./ROADMAP.md) — identity + priorities (P0–P3) + NOT-planned
- [CHANGELOG.md](./CHANGELOG.md) — release history (Added/Changed/Fixed/Security)
- [docs/improvement-plan.md](./docs/improvement-plan.md) — current build focus

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
