# JellyAmp — PWA / Offline Assessment

**Question the mission asked:** should JellyAmp be a PWA, and is offline v1?
**Answer:** **PWA = NO. Offline = already shipped (native), not via PWA.**

---

## 1. PWA — NOT recommended

The mission's own framing ("Add to Home Screen, standalone display, background/lock-screen
playback where supported") already hinted the constraint. The reality is worse than
"where supported" — the two things that matter most for a *music player* are the two
things iOS Safari does worst:

| Requirement | iOS Safari / PWA reality |
|---|---|
| FLAC / lossless playback | 🟡 Safari 11+ *does* decode FLAC in `<audio>` (caniuse) — direct-play is technically possible |
| Opus / OGG | ❌ Safari does not decode Opus in `<audio>` — would need transcode |
| Background playback | ❌ Unreliable — audio suspends when the tab is backgrounded or the screen locks |
| Lock-screen controls | ❌ Media Session API on iOS is **partial** (metadata works; play/pause/seek/next action handlers unreliable) |
| Bluetooth / headphone controls | 🟡 Inconsistent via Media Session |
| Offline storage | ❌ Service-worker Cache API is best-effort + **evictable** — Safari evicts after ~7 days without interaction (ITP) and ~60% disk/origin (iOS 17+); unsuitable for a lossless library |
| Install | 🟡 "Add to Home Screen" works (standalone since iOS 15.4), but still Safari under the hood |

A PWA *could* direct-play FLAC (Safari 11+ supports it), so codec support is **not** the
reason to avoid PWA. The disqualifier is that a music player must keep playing with the
screen locked and respond to Bluetooth/headphone controls, and iOS web apps do that
unreliably: background audio works for standalone home-screen apps only since **iOS 15.4**
(and only for a plain `<audio>` element — WebAudio/JS-decode is blocked when backgrounded,
WebKit bug 198277), and Media Session *action* handlers (next/prev/seek) are not reliably
delivered on the lock screen. Offline is also eviction-prone (7-day ITP). Native wins on
the requirements that matter, not on codec grounds.

**Recommendation: PWA = NO.** The native Flutter app already delivers everything a PWA
would, better: native codec decode (no transcode), reliable background audio via
AVAudioSession, full lock-screen/Control Center/Bluetooth controls, CarPlay, Siri,
AirPlay, and real offline storage.

## 2. Offline — already implemented (native), keep

The native app already ships offline downloads (`background_downloader`):

- Per-item and per-album downloads, app-private storage, per-location download folders.
- **Transcode-on-download** option (e.g. store AAC instead of FLAC to save space).
- Offline mode with data-source switching; downloaded-vs-cached distinction.
- Repair/sync for downloads.

**Offline v1 = already done.** No work needed. (A PWA offline model would be strictly
worse — storage quotas, eviction, and a much harder download story for a lossless
library.)

## 3. What "iPhone install" looks like instead of PWA

Instead of "Add to Home Screen", the native route is an **App Store / TestFlight /
sideload install**:

- TestFlight (paid Apple Developer account, $99/yr) or ad-hoc/sideload (AltStore/
  SideStore, free-account 7-day cert, or a signing service).
- This is the one real dependency: macOS (Xcode or a macOS CI runner) + an Apple
  Developer account. It is a *delivery* dependency, not a code problem.

## 4. Bottom line

- **PWA: NO** — wrong tool for a lossless, background-playback music player on iPhone.
- **Offline v1: YES, already shipped** in the native app.
- The correct v1 path is: keep the native Flutter app, set up the iOS build/sign/
  distribute pipeline, and ship to the iPhone.
