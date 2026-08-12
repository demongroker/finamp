# Jellyamp privacy policy

**Jellyamp does not collect personal data.**  
There are no analytics SDKs, no crash-reporting cloud, no ads, and no demongroker accounts.

## What leaves your device

| Traffic | Where | Why |
|---------|--------|-----|
| Jellyfin API + media streams | **Only** the Jellyfin server URL **you** enter | Login, library, playback, optional downloads |
| Optional “Play On” / websockets | Your Jellyfin server | Only if you use remote control features |
| Optional Discord RPC | Discord (if you enable it) | Off by default |
| Optional APK Wi‑Fi share | LAN devices you choose | Temporary; you start/stop it |

Nothing is sent to demongroker, GitHub, Google Analytics, Firebase, Sentry, or similar.

## Permissions (Android)

Jellyamp is built for **no runtime permission dialogs** for storage, photos, camera, mic, location, contacts, or Bluetooth scan.

| Permission | Status |
|------------|--------|
| Internet | Required (talk to your Jellyfin server) |
| Foreground service (media playback) | Required (background music) |
| Wake lock | Required (keep playback stable) |
| Storage / media / camera / mic / location / contacts | **Removed** |
| Vibration | **Removed** |
| Post notifications | **Removed** (system media session may still show controls) |

Downloads use **app-private storage** only (no “Files and media” access).

Cloud **Android Auto Backup** of app data is **disabled**.

## Data on device

- Login tokens, settings, queue, and offline downloads stay in the app’s private directory on your phone.
- Uninstalling Jellyamp removes that data.
- Sharing a track file or the APK uses the system share sheet **you** choose; Jellyamp does not upload those files for you.

## Logs

Logs stay local unless **you** export/share them from Settings.

## Upstream

Jellyamp is based on [Finamp](https://github.com/finamp-app/finamp). This privacy posture applies to the **Jellyamp** packaging and defaults; always review any upstream features you enable.

Contact for this fork: the [demongroker/jellyamp](https://github.com/demongroker/jellyamp) repository.
