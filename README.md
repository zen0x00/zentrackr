# ZenTrackr

A free, offline-first strength workout tracker for Android and iOS.

## MVP

- Bundled and custom exercises
- Reusable routines with set targets
- Autosaved workout drafts, RPE/RIR, warm-up sets, and rest timer
- Workout history, personal records, volume, and estimated 1RM trends
- Kilogram/pound display, light/dark themes, and local-only storage

No account or network connection is required. Data is stored in SQLite on the device. The SQL in `supabase/migrations` defines the future authenticated sync contract but is not used by the v1 app.

## Development

```sh
flutter pub get
flutter pub run build_runner build
flutter analyze
flutter test
flutter run
```

Android and iOS are the supported targets. iOS builds require Xcode on macOS.
