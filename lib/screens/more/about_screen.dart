// -----------------------------------------------------------------------------
// File Name:      lib/screens/more/about_screen.dart
// Description:    About screen with version, author, website and licensing info.
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
import '../../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App Logo
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryOrange, width: 2),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 54,
                  color: AppTheme.primaryOrange,
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Maya Player',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'v0.0.1-alpha.2',
                style: TextStyle(
                  color: AppTheme.primaryOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'A modern Android video player powered by mpv, featuring VLC-inspired discovery and mpvKt / Aniyomi player interface.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 32),

            // Information Cards
            _infoCard(
              icon: Icons.movie_outlined,
              title: 'Playback Engine',
              value: 'mpv (libmpv via media_kit)',
            ),
            _infoCard(
              icon: Icons.person_outline,
              title: 'Author',
              value: '@tazihad',
            ),
            _infoCard(
              icon: Icons.language,
              title: 'Website',
              value: 'https://zihad.com.bd',
            ),
            _infoCard(
              icon: Icons.article_outlined,
              title: 'License',
              value: 'MIT License (2024 @tazihad)',
            ),
            _infoCard(
              icon: Icons.code,
              title: 'Source Code',
              value: 'https://github.com/tazihad/maya-player',
            ),

            const SizedBox(height: 40),
            const Text(
              'Copyright © 2024 @tazihad. All rights reserved.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryOrange, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    value,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
