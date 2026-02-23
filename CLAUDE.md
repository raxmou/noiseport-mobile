# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Finamp is a cross-platform mobile music player built with **Flutter/Dart** for users with Jellyfin media servers. It also integrates with Slskd (Soulseek) and Spotify APIs. Targets Android and iOS.

- **Dart SDK**: >=3.3.0 <4.0.0
- **Version**: 0.6.27+52

## Common Commands

### Development
```bash
flutter pub get              # Install dependencies
flutter run                  # Run app on connected device/emulator
make run-emulator            # Launch Android emulator (Pixel_6_API_34)
make confirm-devices         # List connected devices (adb devices)
```

### Build
```bash
flutter build apk --release  # Build Android release APK
flutter build apk --debug    # Build Android debug APK
flutter build ios --release --no-codesign  # Build iOS (no signing)
```

### Code Generation (required after modifying models)
```bash
dart run build_runner build --delete-conflicting-outputs
```
Run this when:
- Modifying classes returned by Jellyfin (e.g., `lib/models/jellyfin_models.dart`)
- Adding/changing fields on `@HiveType` annotated classes

Without regeneration: settings won't persist, Hive errors on startup, missing JSON deserialization.

### Analysis
```bash
flutter analyze              # Run Dart static analysis (uses flutter_lints)
```

## Architecture

### Dependency Injection
Uses `get_it` as a service locator. Singletons are registered in `main.dart` during `main()` initialization (e.g., `JellyfinApiHelper`, `FinampUserHelper`, `DownloadsHelper`).

### Data Layer
- **Hive** for all persistent local storage (settings, users, downloads, offline data)
- Models use `@HiveType` annotations with generated type adapters
- New Hive types must have their adapter registered in `setupHive()` in `main.dart`
- Hive changes must be backward-compatible with current release (upgrades must not crash)

### API Layer
- **Chopper** generates the HTTP client in `lib/services/jellyfin_api.dart` (auto-generated, do not edit directly)
- **`lib/services/jellyfin_api_helper.dart`** is the user-facing wrapper — app code should use this, not `jellyfin_api.dart`
- Additional API clients: `slskd_api.dart`, `spotify_api.dart`

### State Management
Mixed approach: Hive `ValueListenable` for persistent state, Provider for widget-level state, Riverpod (limited use, mainly in player screen).

### Audio
- Background audio playback via `audio_service` running in an isolate
- `music_player_background_task.dart` handles playback state, notifications, and queue management
- `audio_service_helper.dart` bridges the UI and background service

### UI Structure
- `lib/screens/` — full page implementations (routed via `main.dart`)
- `lib/components/` — reusable widgets, organized by feature in subdirectories (e.g., `PlayerScreen/`, `MusicScreen/`)

### Localization
- ARB-based i18n in `lib/l10n/`, template file: `app_en.arb`
- 40+ languages managed via Weblate
- Generated output: `lib/l10n/app_localizations.dart`

### Generated Files
Files matching `*.g.dart` and `*.chopper.dart` are auto-generated. Do not edit them manually — modify the source and re-run `build_runner`.

## CI/CD

GitHub Actions (`.github/workflows/build.yml`) runs on PRs and pushes:
- Android: builds debug APK on ubuntu-latest with Java 17
- iOS: builds release (no codesign) on macos-latest

No automated tests currently exist.
