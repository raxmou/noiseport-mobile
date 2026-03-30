# CLAUDE.md

## Project Overview

Cross-platform mobile music player for Jellyfin, built with Flutter/Dart. Fork of [jmshrv/finamp](https://github.com/jmshrv/finamp) with added slskd and Spotify integrations. Dart SDK >= 3.3.0.

## Commands

```bash
make install      # flutter pub get
make dev          # flutter run on connected device
make run-emulator # Launch Android emulator (Pixel_6_API_34)
make devices      # List connected devices (adb)
make build-apk    # Build Android release APK
make build-ios    # Build iOS release (no codesign)
make codegen      # Run build_runner (required after model changes)
make analyze      # Dart static analysis
make clean        # flutter clean
```

## Architecture

```
lib/
├── screens/        # Full page implementations (routed via main.dart)
├── components/     # Reusable widgets, organized by feature subdirectory
├── models/         # Hive-annotated data models (@HiveType)
├── services/       # API clients
│   ├── jellyfin_api.dart        # Chopper-generated (DO NOT EDIT)
│   ├── jellyfin_api_helper.dart # User-facing wrapper (USE THIS)
│   ├── slskd_api.dart           # Soulseek API client
│   └── spotify_api.dart         # Spotify API client
└── l10n/           # i18n (ARB files, 40+ languages via Weblate)
```

## Conventions

- **DI**: `get_it` service locator. Singletons registered in `main()`.
- **Storage**: Hive with `@HiveType` annotations. New types need adapter registration in `setupHive()`.
- **API**: Use `jellyfin_api_helper.dart`, never `jellyfin_api.dart` directly.
- **State**: Hive `ValueListenable` for persistent state, Provider for widgets, Riverpod (player screen only).
- **Audio**: Background playback via `audio_service` in an isolate.
- **Generated files**: `*.g.dart` and `*.chopper.dart` are auto-generated — modify source, run `make codegen`.

## Code Generation

Run `make codegen` after modifying:
- Classes in `lib/models/jellyfin_models.dart`
- Any `@HiveType` annotated class fields

Without regeneration: settings won't persist, Hive errors on startup, missing JSON deserialization.

## Key Dependencies

- `flutter`, `dart` — framework
- `hive` — local storage
- `chopper` — HTTP client generation
- `get_it` — dependency injection
- `audio_service` — background playback
- `just_audio` — audio engine
