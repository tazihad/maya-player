# Maya Player (Android) 🎬

A modern, fast Android video player built with **Flutter** and powered by **mpv** (`media_kit`), featuring **VLC-like automatic video discovery and folder grouping**.

---

## ✨ Features

- **mpv Engine Core**: High-performance video playback with hardware acceleration support powered by `libmpv` (`media_kit`).
- **Automatic Video Discovery**: Automatically scans and indexes all local device videos.
- **Folder Grouping (VLC Style)**: Organizes videos into their containing folders with video count and size indicators.
- **Dual Tab Interface**:
  - **Folders**: Grid view of video directories with dynamic previews.
  - **All Videos**: Chronological / alphabetical list of all videos on device.
- **VLC-like Gesture Controls**:
  - **Vertical swipe (left side)**: Adjust brightness.
  - **Vertical swipe (right side)**: Adjust volume.
  - **Double-tap (left/right)**: Quick seek -10s / +10s.
  - **Lock Button**: Lock controls to prevent accidental taps while watching.
- **Stream / URL Playback**: Direct support for network stream URLs (HLS, RTSP, HTTP, MP4).
- **Playback Controls**:
  - Variable speed (0.25x - 2.0x).
  - Aspect ratio cycling (Fit, Crop, Stretch).
  - Playlist auto-advance and previous/next track support.
- **Automated CI/CD**: Pre-configured GitHub Actions workflow to build split & universal APKs and publish Alpha releases.

---

## 📁 Project Structure

```
maya-player/
├── .github/
│   └── workflows/
│       └── release.yml          # GitHub Actions CI/CD to build & release APKs
├── android/
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── AndroidManifest.xml
│   │   │   └── kotlin/bd/com/zihad/maya_player/MainActivity.kt
│   │   └── build.gradle
│   ├── build.gradle
│   └── settings.gradle
├── lib/
│   ├── models/
│   │   ├── video_model.dart     # Video metadata & thumbnail provider
│   │   └── folder_model.dart    # Folder / group representation
│   ├── services/
│   │   └── video_discovery_service.dart # MediaStore scanner & sorting
│   ├── screens/
│   │   ├── home_screen.dart     # Folders & All Videos discovery tabs
│   │   ├── folder_detail_screen.dart # Videos within a selected folder
│   │   └── player_screen.dart   # MPV Video player with gestures & controls
│   ├── widgets/
│   │   ├── folder_grid_item.dart
│   │   ├── video_list_item.dart
│   │   └── video_thumbnail_widget.dart
│   ├── theme/
│   │   └── app_theme.dart       # Dark theme styling
│   └── main.dart                # App entrypoint with MPV initialization
├── pubspec.yaml
└── README.md
```

---

## 🚀 Automated Builds & Alpha Releases (GitHub Actions)

This project is set up to build entirely in the cloud via **GitHub Actions**.

### How to trigger a build:
1. **Push to `main`**: Automatically triggers the workflow, builds the APKs, and creates a pre-release.
2. **Push a Git Tag**:
   ```bash
   git tag v0.1.0-alpha
   git push origin v0.1.0-alpha
   ```
3. **Manual Trigger (workflow_dispatch)**:
   - Go to your repository on GitHub.
   - Click on the **Actions** tab -> **Build & Release Alpha**.
   - Click **Run workflow** and optionally specify a release tag name.

### Generated APK Artifacts:
- `maya-player-universal-alpha.apk`: Universal APK for all devices.
- `maya-player-arm64-v8a-alpha.apk`: Optimized for modern 64-bit ARM devices.
- `maya-player-armeabi-v7a-alpha.apk`: Optimized for 32-bit ARM devices.
- `maya-player-x86_64-alpha.apk`: Optimized for x86_64 emulators / devices.
