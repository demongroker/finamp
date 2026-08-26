# Jellyamp

A Jellyfin music player (Finamp fork) for Android, built with Flutter.

![CI](https://github.com/demongroker/jellyamp/actions/workflows/ci.yml/badge.svg)

## Overview

Jellyamp is a Flutter-based music player that connects to your Jellyfin server to stream and manage your music library.

## Getting Started

### Prerequisites

- Flutter SDK (>=3.19.0)
- Android Studio / Xcode / VS Code with Flutter and Dart plugins
- A Jellyfin server (version 10.8+ recommended)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/demongroker/jellyamp.git
   cd jellyamp
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app on an emulator or device:
   ```bash
   flutter run
   ```

### Building for Release

- **APK**:
  ```bash
  flutter build apk --release
  ```
- **AAB** (Android App Bundle):
  ```bash
  flutter build appbundle --release
  ```
- **IPA** (iOS) – requires a Mac with Xcode:
  ```bash
  flutter build ios --release
  ```

## Development

### Linting and Formatting

We use `flutter analyze` and `dart format` for code quality.

Run the linter:
```bash
flutter analyze
```

Format the code:
```bash
dart format .
```

### Testing

Run unit and widget tests:
```bash
flutter test
```

### Pre‑commit (optional)

Install and enable the pre‑commit hook to run formatting and analysis on each commit:

```bash
pip install pre-commit
pre-commit install
```

## CI / CD

GitHub Actions is configured to:
- Run `flutter analyze`
- Run `flutter test`
- Build release APK and AAB
- Upload the build artifacts

See `.github/workflows/ci.yml` for details.

## Dependencies

Dependencies are managed via `pubspec.yaml`. Dependabot is configured to keep them up‑to‑date.

## License

This project is private – not for redistribution.

---

*Enjoy your music!* 🎵