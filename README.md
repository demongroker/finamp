<p align="center">
  <img src="GitHub_Banner.png" alt="Jellyamp" width="100%"/>
</p>

<p align="center">
  <strong>Jellyamp</strong> — a Jellyfin music player for the music you already own.<br/>
  Open source · Android · based on <a href="https://github.com/finamp-app/finamp">Finamp</a> redesign
</p>

<p align="center">
  <a href="https://github.com/demongroker/jellyamp/releases/latest"><img src="https://img.shields.io/github/v/release/demongroker/jellyamp?label=latest%20release&color=aa5cc3" alt="release"/></a>
  <a href="https://github.com/demongroker/jellyamp/releases"><img src="https://img.shields.io/github/downloads/demongroker/jellyamp/total?color=00a4dc" alt="downloads"/></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-MPL--2.0-blue" alt="license"/></a>
</p>

---

## Download

| | |
|--|--|
| **Latest APK** | [Releases](https://github.com/demongroker/jellyamp/releases/latest) |
| **Share files build** | [v0.9.25-jellyamp-share](https://github.com/demongroker/jellyamp/releases/tag/v0.9.25-jellyamp-share) |

**Package ID:** `com.demongroker.jellyamp`  
Installs **next to** official Finamp (different package + signing).

> You need your own [Jellyfin](https://jellyfin.org/) server. Jellyamp does not ship any music.

---

## What is Jellyamp?

**Jellyamp** is [demongroker](https://github.com/demongroker)’s fork of **[Finamp](https://github.com/finamp-app/finamp)** — the open-source Jellyfin music client — with a distinct brand and practical QoL for homeserver use.

### Brand

| | |
|--|--|
| Name | **Jellyamp** |
| Icon | Note + **J** badge, Jellyfin blue → purple |
| Accent | Jellyfin purple `#AA5CC3` |
| Jellyfin client name | `Jellyamp` |

### From Finamp (upstream redesign)

- Modern player UI, offline downloads, gapless playback  
- Lyrics & volume normalization (Jellyfin 10.9+)  
- Transcoded streaming / downloads, playback reporting  
- Dynamic colors, playlists, favorites, radio / instant mix  

### Jellyamp extras

| Feature | How |
|---------|-----|
| **Share audio file** | Track menu → download **original** file (FLAC when the library is FLAC) → system share |
| **Share / copy link** | Track, album, artist, playlist, genre menus |
| **Copy title** | `Artist — Title` to clipboard |
| **Long-press seek** | Hold Previous / Next → −10s / +30s |
| **Double-tap cover** | Left third −10s · center favorite · right +30s |
| **Share app APK** | Settings → share install file, or **Wi‑Fi serve** on port `8765` |

---

## Screenshots / design

| Asset | Path |
|-------|------|
| GitHub banner | [`GitHub_Banner.png`](./GitHub_Banner.png) |
| Brand pack | [`docs/brand/`](./docs/brand/) |
| App icon source | [`assets/icon/`](./assets/icon/) |
| In-app logo | [`images/jellyamp_icon.svg`](./images/jellyamp_icon.svg) |

**Palette**

| Token | Hex | Use |
|-------|-----|-----|
| Navy | `#0B1220` | Adaptive icon / splash dark |
| Jellyfin blue | `#00A4DC` | Gradients, highlights |
| Jellyfin purple | `#AA5CC3` | Default accent, badge |
| Light splash | `#FCFDFE` | Native splash (light) |

---

## Install (Android)

1. Download the APK from [Releases](https://github.com/demongroker/jellyamp/releases).  
2. Allow install from your browser/file manager if prompted.  
3. Open **Jellyamp** → log into your Jellyfin server.  

**Share Jellyamp to another phone (same Wi‑Fi):**  
Settings → **Share Jellyamp over Wi‑Fi** → open the shown URL on the other device.

---

## Development

Active branch: **`features/share-seek-qol`** (fork work).  
Upstream line: Finamp **`redesign`**.

```bash
git clone https://github.com/demongroker/jellyamp.git
cd jellyamp
git checkout features/share-seek-qol

# Flutter 3.9+ (or use the pinned toolchain you prefer)
flutter pub get
flutter run   # or: flutter build apk --release
```

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the full Finamp/Flutter setup notes (still largely valid).  
Fork-specific notes: [FORK.md](./FORK.md).

### Remotes

| Remote | URL |
|--------|-----|
| `origin` | `https://github.com/demongroker/jellyamp.git` |
| `upstream` | `https://github.com/finamp-app/finamp.git` |

---

## Privacy

- **No analytics, no ads, no telemetry.**
- Talks only to **your** Jellyfin server (plus optional features you turn on).
- Android: **no storage/photos/camera/location** permission prompts; downloads stay app-private.
- Details: [PRIVACY.md](./PRIVACY.md)

## Credits & license

- **Jellyamp** changes © demongroker (this fork).  
- **Finamp** © [finamp-app](https://github.com/finamp-app/finamp) / contributors — primary application.  
- **Jellyfin** © Jellyfin contributors.  

Licensed under the **Mozilla Public License 2.0** — see [LICENSE](./LICENSE).

Upstream project, issues, and community:  
https://github.com/finamp-app/finamp  

Privacy: [PRIVACY.md](./PRIVACY.md)

---

<p align="center">
  <sub>Built for self-hosted music · Powered by Jellyfin · Based on Finamp</sub>
</p>
