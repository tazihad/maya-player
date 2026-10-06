# Maya Player (Android) 🎬

A modern, fast Android video player built with **Flutter** and powered by **mpv** (`media_kit`), featuring **VLC-like automatic video discovery and folder grouping**.

---

## ✨ Features

- **mpv Engine Core**: High-performance video playback with hardware acceleration support powered by `libmpv` (`media_kit`).
- **mpvKt & Aniyomi Inspired Player**:
  - Sleek top bar with title, back button, audio track switcher, subtitle selector, and hardware decoding (HW/SW) indicator.
  - Interactive gesture HUDs: brightness & volume pill indicators with percentage.
  - Horizontal drag scrub preview with target timestamp & seek offset.
  - Double-tap quick seek (+/-10s) with animated ripple feedback.
  - Long-press 2x fast-forward playback speed boost.
  - Aspect ratio cycling (Fit, Fill/Crop, Stretch, 16:9, 4:3).
  - Lock mode to prevent unintended touches.
- **VLC-Style 5-Tab Navigation**:
  - **Home**: Continue watching carousel, quick actions, playback history preview, and statistics.
  - **Videos**: Grid/list view of all media with search, sorting, and metadata.
  - **Browser**: VLC-style file/directory browser to inspect specific folders and storage paths.
  - **Playlists**: Manage playlists (Favorites, Watch Later, and Custom playlists).
  - **More**: Access network Streams, Playback History, Settings, and About Maya Player.
- **Material 3 Theming**: Consistent Material You / M3 styling with dynamic color accents.
- **Automated CI/CD**: Pre-configured GitHub Actions workflow to build split & universal APKs and publish releases.

---

## 📁 Project Structure

```
maya-player/
├── .github/
│   └── workflows/
│       └── release.yml          # GitHub Actions CD workflow to build & release APKs
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
│   │   ├── storage_service.dart # History, Playlists, Streams, and Settings storage
│   │   └── video_discovery_service.dart # MediaStore scanner & sorting
│   ├── screens/
│   │   ├── main_navigation_screen.dart # VLC-style 5-tab navigation shell
│   │   ├── folder_detail_screen.dart # Videos within a selected folder
│   │   ├── player_screen.dart   # mpvKt & Aniyomi styled MPV video player
│   │   ├── tabs/
│   │   │   ├── home_tab.dart    # Home dashboard & continue watching
│   │   │   ├── videos_tab.dart  # All videos catalog
│   │   │   ├── browser_tab.dart # Directory / folder browser
│   │   │   ├── playlists_tab.dart # Playlists & favorites
│   │   │   └── more_tab.dart    # VLC-style More options
│   │   └── more/
│   │       ├── streams_screen.dart # Network streams
│   │       ├── history_screen.dart # Playback history
│   │       ├── settings_screen.dart # Video, audio, interface settings
│   │       └── about_screen.dart # App & engine info
│   ├── widgets/
│   │   ├── folder_grid_item.dart
│   │   ├── video_list_item.dart
│   │   └── video_thumbnail_widget.dart
│   ├── theme/
│   │   └── app_theme.dart       # Material 3 dark & light theme styling
│   └── main.dart                # App entrypoint with MPV initialization
├── pubspec.yaml
└── README.md
```

---

## 🚀 Automated Builds & Releases (GitHub Actions)

This project is built and released in the cloud via **GitHub Actions (`CD`)**.

### How to trigger a release:
1. **Push a Git Tag**:
   ```bash
   git tag v0.0.1-alpha.2
   git push origin v0.0.1-alpha.2
   ```
2. **Manual Trigger (workflow_dispatch)**:
   - Go to your repository on GitHub.
   - Click on the **Actions** tab -> **CD**.
   - Click **Run workflow** and optionally specify a release tag name.

### Generated APK Artifacts:
- `maya-player-universal-0.0.1-alpha.2.apk`: Universal APK for all devices.
- `maya-player-arm64-v8a-0.0.1-alpha.2.apk`: Optimized for modern 64-bit ARM devices.
- `maya-player-armeabi-v7a-0.0.1-alpha.2.apk`: Optimized for 32-bit ARM devices.
- `maya-player-x86_64-0.0.1-alpha.2.apk`: Optimized for x86_64 emulators / devices.
- `SHA256SUMS.txt`: Checksums for all release assets.
