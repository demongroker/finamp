# JellyAmp — Playback Architecture

**Engine:** `just_audio` (fork) + `just_audio_media_kit` → **media_kit / libmpv (MPV)**,
wrapped by **audio_service** for background/lock-screen integration.

---

## 1. Component roles

```
audio_service (background handler, lock-screen, Bluetooth)
        │  owns the media session + queue lifecycle
        ▼
just_audio (playback API: queue, gapless, seek, speed)
        │  a thin controller over the actual decoder
        ▼
just_audio_media_kit → media_kit → libmpv (MPV)
        │  native decoder; feeds PCM to the OS audio output
        ▼
iOS: AVAudioSession  ·  Android: AudioTrack/MediaSession
```

- **just_audio** provides the Dart-facing API (play/pause/seek/queue/gapless/speed) and
  the audio-session handling.
- **media_kit/libmpv** is the *decoder*. It decodes **FLAC, ALAC, AAC, MP3, Opus, WAV,
  DSD, and more** natively in-process. This is the decisive architectural fact: the
  FLAC library direct-plays with **no server transcoding**.

## 2. Direct play (default)

1. App requests `GET /Items/{id}/PlaybackInfo` → `MediaSources[]` with the original
   codec/bitDepth/sampleRate and a direct stream URL.
2. That URL (effectively the original file, `/Items/{id}/File` or the source URL) is
   handed to just_audio → media_kit → libmpv.
3. libmpv decodes the FLAC/ALAC/… natively and plays losslessly.

**Result:** original quality preserved end-to-end; zero server CPU.

## 3. Direct Stream / Transcode (opt-in)

- **Direct Stream** = remux only (same codec, new container) — rarely needed for audio.
- **Transcode** = server re-encodes via `GET /Audio/{id}/Universal` with
  `audioCodec` / `container` / `audioBitRate` / `sampleRate` / `maxAudioChannels` query
  params. The app exposes a transcode toggle + bitrate + streaming-format +
  multichannel-downmix settings, and the Now Playing chip explains
  `source → output → reason`.
- **When transcode is actually required** on the native app: essentially *only* when the
  user forces it (e.g. cap bitrate on metered data, or downmix multichannel). It is NOT
  needed for FLAC — libmpv handles FLAC. (Contrast: a browser/PWA *would* need it for
  FLAC, see §5.)

## 4. FLAC / iPhone behavior (the key question)

- **Native app:** FLAC direct-plays on iPhone because libmpv (bundled via media_kit)
  decodes FLAC. No Apple codec dependency, no transcode. ✅
- **ALAC** also direct-plays (libmpv decodes it; Apple hardware also handles ALAC natively).
- **AAC / MP3** direct-play trivially.
- **Opus** direct-plays via libmpv (a browser would not reliably play Opus either).

## 5. Native vs browser/PWA for playback

- **FLAC is NOT the blocker.** iOS Safari 11+ *does* decode FLAC in the `<audio>`
  element (caniuse.com/flac: "Safari on iOS 11+" = Supported; MDN codec guide). So a PWA
  could technically direct-play the FLAC library — no forced transcode. (Opus/OGG remains
  unsupported in Safari `<audio>`, but that's a minority of a FLAC library.)
  - **Detection quirk:** Safari's `canPlayType('audio/flac')` returns an *empty string*
    even though playback works (caniuse.com/flac note 1) — a feature-detection-based web
    player (e.g. Jellyfin Web) can wrongly conclude FLAC is unsupported and fall back to
    server transcode. Native media_kit does not feature-detect; it just plays.
- **The real blockers are background + lock-screen.** iOS Safari suspends audio when the
  tab is backgrounded or the screen locks, and Media Session API support on iOS is
  *partial* (metadata can appear; play/pause/seek/next action handlers are unreliable and
  background continuation is not dependable). For a music player that must keep playing
  with the screen locked and respond to Bluetooth/headphone controls, this is the
  disqualifier — not codec support.
- The native path (libmpv + audio_service → AVAudioSession + MPRemoteCommandCenter)
  gives reliable background audio and full lock-screen / Control Center / Bluetooth
  controls — which the mission explicitly wants.

## 6. Gapless

- **Direct play is gapless-capable** via just_audio's gapless transitions (album tracks
  flow without gaps). libmpv's continuous decode makes this clean for FLAC/ALAC albums.
- Transcoding introduces per-track transcode seams; gapless is best-effort there (the
  app prefers direct play, so gapless holds for the FLAC library).

## 7. Queue + session persistence

- The queue lives in the `audio_service` handler (survives app backgrounding).
- Saved queues are persisted in Isar and restorable (`QueueRestoreScreen`, previous-queue).
- Data-source switching (direct↔transcode↔offline↔server URL change) triggers a
  queue reload with an archive option — queue behavior stays predictable.

## 8. Progress / play history reporting

- `POST /Sessions/Playing` (+ `/Progress`, `/Stopped`) report playback to Jellyfin
  (resume points, "now playing", play history).
- Local `playback_history_service` tracks listened history; PlayOn plugin integration
  is optional and already implemented.

## 9. Visibility (mission: "make playback decision visible/debuggable")

- Now Playing **feature chip** shows the live mode: **Direct Play / Direct Streaming /
  Transcoding**, plus codec, bitrate, bit depth, sample rate, container, size, path,
  server (track info sheet). Already satisfies the requirement without cluttering the
  normal UI.
