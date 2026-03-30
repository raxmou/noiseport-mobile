# Noiseport

Cross-platform mobile music player for Jellyfin servers.

## Overview

Noiseport is a Flutter/Dart music player for Android and iOS that connects to Jellyfin media servers. Fork of [jmshrv/finamp](https://github.com/jmshrv/finamp) with added Soulseek (slskd) and Spotify API integrations for music discovery and downloading.

## Tech Stack

- Flutter / Dart (SDK >= 3.3.0)
- Hive (local storage)
- Chopper (HTTP client generation)
- get_it (dependency injection)
- audio_service (background playback)

## Prerequisites

- Flutter SDK
- Android Studio / Xcode
- Android emulator or physical device

## Getting Started

```bash
make install
make dev
```

## Usage

```bash
make dev          # Run on connected device
make run-emulator # Launch Android emulator
make devices      # List connected devices
make build-apk    # Build Android release APK
make build-ios    # Build iOS release
make codegen      # Run build_runner after model changes
make analyze      # Run Dart static analysis
```

## Architecture

```
lib/
├── screens/        # Full page implementations
├── components/     # Reusable widgets (by feature subdirectory)
├── models/         # Hive-annotated data models
├── services/       # API clients (Jellyfin, slskd, Spotify)
└── l10n/           # i18n (ARB files, 40+ languages via Weblate)
```

Key patterns:
- **DI**: `get_it` service locator, singletons registered in `main.dart`
- **Storage**: Hive with `@HiveType` annotations and generated adapters
- **API**: Chopper-generated clients; use `jellyfin_api_helper.dart`, not `jellyfin_api.dart`
- **State**: Hive `ValueListenable` + Provider + Riverpod (player screen)
- **Audio**: Background playback via `audio_service` isolate

## Deployment

CI/CD via GitHub Actions (`.github/workflows/build.yml`):
- Android: debug APK on ubuntu-latest (Java 17)
- iOS: release build (no codesign) on macos-latest

## License

GPL-3.0.
