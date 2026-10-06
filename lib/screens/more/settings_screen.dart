// -----------------------------------------------------------------------------
// File Name:      lib/screens/more/settings_screen.dart
// Description:    Settings screen for Video, Screen Orientation, Audio and Interface.
// Author:         @tazihad
// Website:        https://zihad.com.bd
// License:        MIT License
// -----------------------------------------------------------------------------

// MIT License
//
// Copyright (c) 2024 @tazihad
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListenableBuilder(
        listenable: _storage,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // SECTION: VIDEO
              _buildSectionHeader('Video Options'),
              SwitchListTile(
                secondary: const Icon(Icons.memory_outlined, color: AppTheme.primaryOrange),
                title: const Text('Hardware Decoding (HW)'),
                subtitle: const Text('Use hardware acceleration for smoother playback and battery saving'),
                value: _storage.hardwareDecoding,
                activeColor: AppTheme.primaryOrange,
                onChanged: (val) {
                  _storage.updateSettings(hardwareDecoding: val);
                },
              ),
              ListTile(
                leading: const Icon(Icons.aspect_ratio_outlined, color: AppTheme.primaryOrange),
                title: const Text('Default Aspect Ratio'),
                subtitle: Text(_getAspectRatioLabel(_storage.defaultAspectRatio)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showAspectRatioDialog,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.music_note_outlined, color: AppTheme.primaryOrange),
                title: const Text('Background Playback'),
                subtitle: const Text('Continue playing audio when app is minimized or screen off'),
                value: _storage.backgroundPlayback,
                activeColor: AppTheme.primaryOrange,
                onChanged: (val) {
                  _storage.updateSettings(backgroundPlayback: val);
                },
              ),
              const Divider(color: AppTheme.surfaceLightDark),

              // SECTION: SCREEN ORIENTATION
              _buildSectionHeader('Screen Orientation'),
              ListTile(
                leading: const Icon(Icons.screen_rotation_outlined, color: AppTheme.primaryOrange),
                title: const Text('Video Screen Orientation'),
                subtitle: Text(_getOrientationLabel(_storage.screenOrientation)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showOrientationDialog,
              ),
              const Divider(color: AppTheme.surfaceLightDark),

              // SECTION: AUDIO
              _buildSectionHeader('Audio Options'),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_outlined, color: AppTheme.primaryOrange),
                title: const Text('Audio Boost (up to 150%)'),
                subtitle: const Text('Allows boosting volume beyond 100% for quiet videos'),
                value: _storage.audioBoost,
                activeColor: AppTheme.primaryOrange,
                onChanged: (val) {
                  _storage.updateSettings(audioBoost: val);
                },
              ),
              const Divider(color: AppTheme.surfaceLightDark),

              // SECTION: INTERFACE & GESTURES
              _buildSectionHeader('Interface & Gestures'),
              SwitchListTile(
                secondary: const Icon(Icons.swipe_outlined, color: AppTheme.primaryOrange),
                title: const Text('Gesture Controls'),
                subtitle: const Text('Enable swipe gestures for brightness, volume, and seeking'),
                value: _storage.gestureControlsEnabled,
                activeColor: AppTheme.primaryOrange,
                onChanged: (val) {
                  _storage.updateSettings(gestureControlsEnabled: val);
                },
              ),
              ListTile(
                leading: const Icon(Icons.touch_app_outlined, color: AppTheme.primaryOrange),
                title: const Text('Double-tap Seek Interval'),
                subtitle: Text('${_storage.doubleTapSeekSeconds} seconds'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showDoubleTapDialog,
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined, color: AppTheme.primaryOrange),
                title: const Text('App Theme'),
                subtitle: Text(_getThemeLabel(_storage.themeMode)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showThemeDialog,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.accentOrange,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  String _getAspectRatioLabel(String value) {
    switch (value) {
      case 'cover':
        return 'Crop / Zoom to Fill';
      case 'fill':
        return 'Stretch to Screen';
      default:
        return 'Fit to Screen (Best)';
    }
  }

  void _showAspectRatioDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Default Aspect Ratio'),
        children: [
          _dialogOption('Fit to Screen (Best)', 'contain', _storage.defaultAspectRatio, (val) {
            _storage.updateSettings(defaultAspectRatio: val);
            Navigator.of(context).pop();
          }),
          _dialogOption('Crop / Zoom to Fill', 'cover', _storage.defaultAspectRatio, (val) {
            _storage.updateSettings(defaultAspectRatio: val);
            Navigator.of(context).pop();
          }),
          _dialogOption('Stretch to Screen', 'fill', _storage.defaultAspectRatio, (val) {
            _storage.updateSettings(defaultAspectRatio: val);
            Navigator.of(context).pop();
          }),
        ],
      ),
    );
  }

  String _getOrientationLabel(String value) {
    switch (value) {
      case 'portrait':
        return 'Portrait (Vertical)';
      case 'sensor_landscape':
        return 'Sensor Landscape (Auto)';
      default:
        return 'Automatic (Follow System)';
    }
  }

  void _showOrientationDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Screen Orientation'),
        children: [
          _dialogOption('Automatic (Follow System)', 'auto', _storage.screenOrientation, (val) {
            _storage.updateSettings(screenOrientation: val);
            Navigator.of(context).pop();
          }),
          _dialogOption('Sensor Landscape (Default)', 'sensor_landscape', _storage.screenOrientation, (val) {
            _storage.updateSettings(screenOrientation: val);
            Navigator.of(context).pop();
          }),
          _dialogOption('Portrait (Vertical)', 'portrait', _storage.screenOrientation, (val) {
            _storage.updateSettings(screenOrientation: val);
            Navigator.of(context).pop();
          }),
        ],
      ),
    );
  }

  void _showDoubleTapDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Double-tap Seek Interval'),
        children: [5, 10, 15, 30].map((seconds) {
          final isSelected = _storage.doubleTapSeekSeconds == seconds;
          return SimpleDialogOption(
            onPressed: () {
              _storage.updateSettings(doubleTapSeekSeconds: seconds);
              Navigator.of(context).pop();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$seconds seconds', style: TextStyle(
                  color: isSelected ? AppTheme.primaryOrange : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                )),
                if (isSelected) const Icon(Icons.check, color: AppTheme.primaryOrange, size: 20),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getThemeLabel(String value) {
    switch (value) {
      case 'light':
        return 'Light Theme';
      case 'system':
        return 'Follow System';
      default:
        return 'Dark Theme (OLED)';
    }
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('App Theme'),
        children: [
          _dialogOption('Dark Theme (OLED)', 'dark', _storage.themeMode, (val) {
            _storage.updateSettings(themeMode: val);
            Navigator.of(context).pop();
          }),
          _dialogOption('Light Theme', 'light', _storage.themeMode, (val) {
            _storage.updateSettings(themeMode: val);
            Navigator.of(context).pop();
          }),
          _dialogOption('Follow System', 'system', _storage.themeMode, (val) {
            _storage.updateSettings(themeMode: val);
            Navigator.of(context).pop();
          }),
        ],
      ),
    );
  }

  Widget _dialogOption(String label, String value, String currentValue, ValueChanged<String> onSelect) {
    final isSelected = value == currentValue;
    return SimpleDialogOption(
      onPressed: () => onSelect(value),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            color: isSelected ? AppTheme.primaryOrange : AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          )),
          if (isSelected) const Icon(Icons.check, color: AppTheme.primaryOrange, size: 20),
        ],
      ),
    );
  }
}
