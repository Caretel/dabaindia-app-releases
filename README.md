# DabaIndia Attendance App

APK release hosting and source for the DabaIndia Attendance App.

## 📱 Latest Release

Download the latest APK from the [Releases page](https://github.com/Caretel/dabaindia-app-releases/releases/latest).

## 🚀 Auto-Build & Release

Every push to `main` automatically:
1. Builds a release APK via GitHub Actions
2. Publishes it as a GitHub Release
3. The app checks for updates via the backend API and prompts users to update

## 🛠️ Development Setup

```bash
flutter pub get
flutter run
```

## 📦 Releasing a New Version

1. Bump `version` in `pubspec.yaml` (e.g. `1.0.2+3`)
2. Add a new entry in `backend/check_update.php`
3. Commit and push to `main` — GitHub Actions handles the rest

## Tech Stack

- Flutter (Android)
- Firebase Cloud Messaging (push notifications)
- Geofencing & background location
- GitHub Actions CI/CD
