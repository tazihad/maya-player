// -----------------------------------------------------------------------------
// File Name:      lib/screens/tabs/browser_tab.dart
// Description:    VLC-style folder and directory browser for local storage.
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
import '../../models/folder_model.dart';
import '../../services/video_discovery_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/folder_grid_item.dart';

class BrowserTab extends StatefulWidget {
  final VideoDiscoveryService discoveryService;
  final VoidCallback onRefresh;

  const BrowserTab({
    super.key,
    required this.discoveryService,
    required this.onRefresh,
  });

  @override
  State<BrowserTab> createState() => _BrowserTabState();
}

class _BrowserTabState extends State<BrowserTab> {
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  FolderSortOption _sortOption = FolderSortOption.nameAsc;

  List<FolderModel> get _filteredFolders {
    if (_searchQuery.trim().isEmpty) {
      return widget.discoveryService.folders;
    }
    return widget.discoveryService.folders
        .where((f) =>
            f.name.toLowerCase().contains(_searchQuery.trim().toLowerCase()) ||
            f.videos.any((v) =>
                v.title.toLowerCase().contains(_searchQuery.trim().toLowerCase())))
        .toList();
  }

  void _showSortModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Sort Folders By',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const Divider(color: AppTheme.surfaceLightDark),
              _sortTile('Folder Name (A - Z)', FolderSortOption.nameAsc),
              _sortTile('Folder Name (Z - A)', FolderSortOption.nameDesc),
              _sortTile('Most Videos', FolderSortOption.countDesc),
              _sortTile('Total Size', FolderSortOption.sizeDesc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortTile(String title, FolderSortOption option) {
    final isSelected = _sortOption == option;
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryOrange : AppTheme.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryOrange) : null,
      onTap: () {
        setState(() {
          _sortOption = option;
          widget.discoveryService.sortFolders(_sortOption);
        });
        Navigator.of(context).pop();
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final folders = _filteredFolders;

    return Column(
      children: [
        // Top Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _isSearching
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search folders...',
                          hintStyle: const TextStyle(color: AppTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _isSearching = false;
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          ),
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                        },
                      )
                    : Text(
                        '${folders.length} ${folders.length == 1 ? 'Folder' : 'Folders'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
              ),
              if (!_isSearching) ...[
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search',
                  onPressed: () => setState(() => _isSearching = true),
                ),
                IconButton(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort',
                  onPressed: _showSortModal,
                ),
              ],
            ],
          ),
        ),

        // Folders Content
        Expanded(
          child: RefreshIndicator(
            color: AppTheme.primaryOrange,
            onRefresh: () async => widget.onRefresh(),
            child: folders.isEmpty
                ? const Center(
                    child: Text(
                      'No video folders found',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.95,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: folders.length,
                    itemBuilder: (context, index) {
                      return FolderGridItem(folder: folders[index]);
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
