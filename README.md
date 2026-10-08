# Algerian Pharmaceutical CRM - Flutter Field Mobile Companion

## 🎯 Architecture
This Flutter mobile app acts as the field companion (*Délégué Médical*) for the Algerian CRM web dashboard.

- **Offline-First**: Built with SQLite (`sqflite`) to support field visits across interior Algerian wilayas with intermittent 4G/3G connectivity.
- **GPS Verification**: Logs visit coordinates and timestamps to authenticate doctor visits.
- **Bi-directional Sync**: Syncs with Next.js REST API endpoints (`/api/mobile/visits`, `/api/mobile/doctors`, `/api/mobile/sync`).

## 🚀 Quick Start

1. Install Flutter (>= 3.2.0):
```bash
flutter --version
```

2. Get dependencies:
```bash
flutter pub get
```

3. Set your Next.js CRM Server URL in `lib/services/api_service.dart`:
```dart
String baseUrl = 'https://ais-dev-r5wfi6isomhc3kydzaxlig-541147284713.europe-west2.run.app';
```

4. Run on connected Android / iOS device or emulator:
```bash
flutter run
```

5. Build Release APK for Medical Reps in Algeria:
```bash
flutter build apk --release
```
