# Finamp fork — local enhancements

**Upstream:** [finamp-app/finamp](https://github.com/finamp-app/finamp) (`redesign` branch)  
**Local path:** `/home/adnan/finamp`  
**Feature branch:** `features/share-seek-qol`

This is a local development fork of Finamp (open-source Jellyfin music player) with small, practical UX features that fit existing menu and player patterns.

## Features added

### 1. Share / copy library items
Available on **track, album, artist, playlist, and genre** context menus:

| Action | What it does |
|--------|----------------|
| **Share** | System share sheet with `Artist — Title` + Jellyfin web deep link |
| **Copy link** | Copies `{server}/web/#/details?id={itemId}` to the clipboard |
| **Copy title** | Copies a human-readable line (e.g. `Daft Punk — Get Lucky`) |

Deep links use the logged-in server base URL (`public` or `local`, same as Finamp networking prefs). Hidden while offline.

### 2. Long-press seek on skip buttons
On the player screen:

- **Long-press Previous** → seek **−10 seconds**
- **Long-press Next** → seek **+30 seconds**

Intervals match the existing desktop keyboard shortcuts (Ctrl+← / Ctrl+→).

### 3. Double-tap zones on album art
On the full-screen player cover:

| Zone | Action |
|------|--------|
| **Left third** | Seek −10s |
| **Center third** | Toggle favorite (unchanged) |
| **Right third** | Seek +30s |

Single tap still toggles play/pause; horizontal swipe still skips tracks.

## Build / run

Dev still happens against the **redesign** line of Finamp. You need Flutter (SDK ^3.9) and the usual Android/iOS/desktop toolchains — see [CONTRIBUTING.md](./CONTRIBUTING.md).

```bash
cd /home/adnan/finamp
git checkout features/share-seek-qol
# Prefer the repo flutter wrapper if present:
./flutterw pub get
./flutterw gen-l10n   # or: flutter gen-l10n
./flutterw run
```

Localizations: new strings are in `lib/l10n/app_en.arb`. Generated `lib/l10n/*.dart` files are gitignored; Flutter generates them at build time.

## Publish a GitHub fork

`gh` is not installed on this host, and no GitHub auth is configured. When you want a real remote fork:

```bash
# Install GitHub CLI if needed, then authenticate
# sudo apt install gh && gh auth login

gh repo fork finamp-app/finamp --clone=false
cd /home/adnan/finamp
git remote rename origin upstream
git remote add origin git@github.com:demongroker/finamp.git
git push -u origin features/share-seek-qol
```

Or use the GitHub website **Fork** button, then:

```bash
git remote rename origin upstream
git remote add origin https://github.com/demongroker/finamp.git
git push -u origin features/share-seek-qol
```

## Key files

| Path | Role |
|------|------|
| `lib/services/media_share_helper.dart` | Jellyfin URL + share/copy helpers |
| `lib/services/playback_seek_helper.dart` | ± seek helpers |
| `lib/menus/components/menuEntries/share_item_link_menu_entry.dart` | Share / copy-link menu rows |
| `lib/menus/components/menuEntries/copy_item_info_menu_entry.dart` | Copy-title menu row |
| `lib/components/PlayerScreen/player_buttons.dart` | Long-press seek |
| `lib/components/PlayerScreen/player_screen_album_image.dart` | Double-tap seek zones |
| `lib/l10n/app_en.arb` | New English strings |

## Ideas for next features

- Configurable seek intervals (settings + Hive field)
- Android Auto polish
- Multi-user / multi-server switcher
- Share as Jellyfin “deep link” protocol if/when Finamp registers one
- SyncPlay support (upstream issue #640)
