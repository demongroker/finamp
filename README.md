<p align="center">
  <img src="GitHub_Banner.png" alt="Jellyamp" width="100%"/>
</p>

<p align="center">
  <strong>Jellyamp</strong> — the <em>power-user</em> Jellyfin music client.<br/>
  Open source · Android · forked from <a href="https://github.com/finamp-app/finamp">Finamp</a>
</p>

<p align="center">
  <a href="https://github.com/demongroker/jellyamp/releases/latest"><img src="https://img.shields.io/github/v/release/demongroker/jellyamp?label=latest%20release&color=aa5cc3" alt="release"/></a>
  <a href="https://github.com/demongroker/jellyamp/releases"><img src="https://img.shields.io/github/downloads/demongroker/jellyamp/total?color=00a4dc" alt="downloads"/></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-MPL--2.0-blue" alt="license"/></a>
</p>

> **Your music. Your server. No tracking.**

---

## Download

| | |
|--|--|
| **Latest APK** | [Releases](https://github.com/demongroker/jellyamp/releases/latest) |

**Package ID:** `com.demongroker.jellyamp` · installs **next to** official Finamp (different package + signing). You need your own [Jellyfin](https://jellyfin.org/) server — Jellyamp ships no music.

---

## Why Jellyamp?

Jellyamp is a Finamp fork rebuilt for **power users**: people who own their music, run their own Jellyfin server, keep large libraries, care about lossless quality and Direct Play, and want real control — with zero telemetry.

| You want… | Jellyamp gives you |
|-----------|--------------------|
| Find anything, fast | **Unified search** across Artists / Albums / Tracks / Playlists / Genres, with query syntax |
| See exactly what's playing | **Direct Play / Direct Streaming / Transcoding**, codec, bit depth, sample rate, bitrate, server, file |
| Trust your audio quality | Lossless / Hi-Res / 24-bit visibility and filters |
| Control the queue | Reorder, swipe-remove, undo, Play Next, Clear After Current |
| Play offline with certainty | Reliable downloads, app-private storage |
| Update safely | In-app updates with **SHA-256 verification** before install |
| Stay private | No analytics, no ads, no telemetry, no cloud |

---

## Power search

One box searches your **entire library**, grouped by type — and accepts a real query language:

```
metallica
artist:metallica year:1983-1991
codec:flac bit:24 favorite:true
downloaded:true
album:"master of puppets"
```

Keys: `artist:` · `album:` · `track:` · `playlist:` · `genre:` · `year:` (single or range) · `codec:` · `bit:` / `bitdepth:` · `favorite:` · `downloaded:`

Album semantics are strict: an album matches `codec:flac` only when **all** its tracks are FLAC.

---

## Playback transparency

Tap the playback-mode chip on the Now Playing screen for a full technical sheet — and when something is transcoding, Jellyamp tells you **why**, with the source → output chain:

```
Source   FLAC · 24-bit · 96 kHz · 2841 kbps
Output   AAC · 256 kbps
Why      Streaming quality setting
```

---

## From Finamp (upstream)

Modern player UI, offline downloads, gapless playback, lyrics, volume normalization, transcoded streaming/downloads, playback reporting, dynamic colors, playlists, favorites, radio / instant mix.

## What Jellyamp adds

| Feature | How |
|---------|-----|
| Unified search + query syntax | Search box → grouped results across the whole library |
| Playback transparency | Playback mode, codec, bit depth, sample rate, bitrate, container, size, path, server |
| Transcoding explanation | Source → output → reason |
| Share original audio | Track menu → share the **original** FLAC file |
| Share / copy link & title | `Artist — Title` to clipboard |
| Long-press seek | Hold Previous / Next → −10s / +30s |
| Double-tap cover | Left −10s · center favorite · right +30s |
| Secure in-app updates | SHA-256 verified, exact-asset, with release notes |
| Share the app | Settings → share APK, or **Wi‑Fi serve** on port `8765` |

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

**Share Jellyamp to another phone (same Wi‑Fi):** Settings → **Share Jellyamp over Wi‑Fi** → open the URL on the other device.

---

## Development

Active branch: **`features/share-seek-qol`** (fork work) · upstream: Finamp **`redesign`**.

```bash
git clone https://github.com/demongroker/jellyamp.git
cd jellyamp
git checkout features/share-seek-qol

flutter pub get
flutter run   # or: flutter build apk --release
```

See [CONTRIBUTING.md](./CONTRIBUTING.md) for Finamp/Flutter setup notes, and [FORK.md](./FORK.md) for fork-specific details. Roadmap: [ROADMAP.md](./ROADMAP.md) · Changelog: [CHANGELOG.md](./CHANGELOG.md).

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

Licensed under the **Mozilla Public License 2.0** — see [LICENSE](./LICENSE). Upstream project & community: https://github.com/finamp-app/finamp

---

<p align="center">
  <sub>Built for self-hosted music · Powered by Jellyfin · Based on Finamp</sub>
</p>
