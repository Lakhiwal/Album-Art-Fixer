import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/audio_item.dart';
import 'services/audio_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlbumArtFixerApp());
}

class AlbumArtFixerApp extends StatelessWidget {
  const AlbumArtFixerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Album Art Fixer',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFB74D), // Warm Amber
          secondary: Color(0xFF64FFDA), // Mint Cyan
          surface: Color(0xFF171B24),
          surfaceContainerHighest: Color(0xFF222836),
          onPrimary: Colors.black,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF171B24),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF272F3E), width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F1117),
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedDirectory;
  List<AudioItem> _items = [];
  bool _isBusy = false;
  bool _isCancelled = false;
  String _statusMessage = 'Choose your music folder or SD card to begin.';
  double _progress = 0.0;
  String _currentFile = '';
  String _searchQuery = '';

  // Settings
  int _targetDimension = 1000;
  bool _createBackups = true;
  bool _exportFolderCover = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isRestricted ||
          !await Permission.manageExternalStorage.isGranted) {
        await Permission.manageExternalStorage.request();
      }
      await Permission.audio.request();
      await Permission.storage.request();
    }
  }

  Future<void> _pickDirectory() async {
    await _requestPermissions();

    final result = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Music Directory or SD Card',
    );

    if (result != null && mounted) {
      setState(() {
        _selectedDirectory = result;
        _items.clear();
        _statusMessage =
            'Folder selected. Tap "Scan Library" to inspect artwork.';
        _progress = 0.0;
        _currentFile = '';
      });
    }
  }

  Future<void> _runProcess({required bool isConvertMode}) async {
    if (_selectedDirectory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a folder first')),
      );
      return;
    }

    setState(() {
      _isBusy = true;
      _isCancelled = false;
      _statusMessage = isConvertMode
          ? 'Converting artwork to Baseline JPEG…'
          : 'Scanning audio library…';
      _progress = 0.0;
      _currentFile = '';
      if (!isConvertMode) {
        _items.clear();
      }
    });

    final files = AudioService.listAudioFiles(_selectedDirectory!);

    if (files.isEmpty) {
      setState(() {
        _isBusy = false;
        _statusMessage = 'No supported audio files found in selected folder.';
      });
      return;
    }

    final total = files.length;
    final scannedItems = <AudioItem>[];
    int convertedCount = 0;

    for (int i = 0; i < total; i++) {
      if (!mounted || _isCancelled) break;
      final file = files[i];

      setState(() {
        _currentFile = file.path.split(Platform.pathSeparator).last;
        _progress = (i + 1) / total;
      });

      if (!isConvertMode) {
        // Scan mode
        final item = await AudioService.inspectAudioFile(file);
        scannedItems.add(item);
      } else {
        // Convert mode: only process selected items
        AudioItem? item;
        final existingIndex = _items.indexWhere((it) => it.path == file.path);
        if (existingIndex >= 0) {
          item = _items[existingIndex];
        } else {
          item = await AudioService.inspectAudioFile(file);
          scannedItems.add(item);
        }

        if (item.isSelected && item.needsFix) {
          await AudioService.fixAudioItem(
            item,
            maxDimension: _targetDimension,
            createBackup: _createBackups,
            exportFolderCover: _exportFolderCover,
          );
          if (item.isConverted) convertedCount++;
        }
      }
    }

    if (mounted) {
      setState(() {
        _isBusy = false;
        if (!isConvertMode) {
          _items = scannedItems;
          final needsFixCount = _items.where((i) => i.needsFix).length;
          _statusMessage = _isCancelled
              ? 'Scan cancelled by user.'
              : 'Scan complete: ${_items.length} files scanned ($needsFixCount need HiBy fix).';
        } else {
          _statusMessage = _isCancelled
              ? 'Conversion cancelled.'
              : 'Done! Successfully fixed $convertedCount tracks for HiBy R1.';
        }
      });
    }
  }

  Future<void> _restoreAllBackups() async {
    final backedUp = _items.where((i) => i.hasBackup).toList();
    if (backedUp.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2230),
        title: const Text('Restore All Backups?'),
        content: Text(
          'This will revert all ${backedUp.length} tracks to their original uncompressed artwork.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64FFDA),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isBusy = true;
      _statusMessage = 'Restoring original files from backup…';
    });

    int restoredCount = 0;
    for (final item in backedUp) {
      final ok = await AudioService.restoreBackup(item);
      if (ok) restoredCount++;
    }

    if (mounted) {
      setState(() {
        _isBusy = false;
        _statusMessage = 'Restored $restoredCount files to original artwork.';
      });
    }
  }

  void _selectAll(bool select) {
    setState(() {
      for (final item in _items) {
        if (select) {
          item.isSelected = item.needsFix;
        } else {
          item.isSelected = false;
        }
      }
    });
  }

  List<AudioItem> get _filteredItems {
    List<AudioItem> list;
    switch (_selectedFilter) {
      case 'Needs Fix':
        list = _items.where((i) => i.needsFix && !i.isConverted).toList();
        break;
      case 'Compliant':
        list = _items
            .where(
              (i) =>
                  i.compliance == ArtworkCompliance.baselineJpeg && !i.needsFix,
            )
            .toList();
        break;
      case 'Fixed':
        list = _items.where((i) => i.isConverted).toList();
        break;
      default:
        list = _items;
    }

    if (_searchQuery.trim().isEmpty) return list;

    final q = _searchQuery.toLowerCase();
    return list.where((i) {
      final name = i.fileName.toLowerCase();
      final title = (i.title ?? '').toLowerCase();
      final artist = (i.artist ?? '').toLowerCase();
      final album = (i.album ?? '').toLowerCase();
      return name.contains(q) ||
          title.contains(q) ||
          artist.contains(q) ||
          album.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final needsFixCount = _items
        .where((i) => i.needsFix && !i.isConverted)
        .length;
    final compliantCount = _items
        .where(
          (i) => i.compliance == ArtworkCompliance.baselineJpeg && !i.needsFix,
        )
        .length;
    final fixedCount = _items.where((i) => i.isConverted).length;
    final selectedCount = _items
        .where((i) => i.isSelected && i.needsFix && !i.isConverted)
        .length;
    final backupCount = _items.where((i) => i.hasBackup).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB74D).withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.album_rounded,
                color: Color(0xFFFFB74D),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Album Art Fixer',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF222836),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF333C4F)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.audiotrack_rounded,
                  color: Color(0xFF64FFDA),
                  size: 14,
                ),
                SizedBox(width: 4),
                Text(
                  'HiBy R1 / DAP Ready',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64FFDA),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Config & Action Section
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF141822),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Directory Picker Card
                InkWell(
                  onTap: _isBusy ? null : _pickDirectory,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C2230),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2E384D)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.folder_open_rounded,
                          color: Color(0xFFFFB74D),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedDirectory != null
                                    ? 'Music Folder Selected'
                                    : 'Choose Music Folder / SD Card',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedDirectory ??
                                    'Tap to select SD card or music directory',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _selectedDirectory != null
                                      ? Colors.white
                                      : Colors.white38,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isBusy ? null : _pickDirectory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2A344A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _selectedDirectory != null ? 'Change' : 'Browse',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Settings Row: Max Dimension, Backup, Folder Cover
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2230),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2E384D)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _targetDimension,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1C2230),
                            items: const [
                              DropdownMenuItem(
                                value: 600,
                                child: Text('Max 600x600 px'),
                              ),
                              DropdownMenuItem(
                                value: 800,
                                child: Text('Max 800x800 px (HiBy Best)'),
                              ),
                              DropdownMenuItem(
                                value: 1000,
                                child: Text('Max 1000x1000 px'),
                              ),
                              DropdownMenuItem(
                                value: 0,
                                child: Text('Keep Original Size'),
                              ),
                            ],
                            onChanged: _isBusy
                                ? null
                                : (v) => setState(
                                    () => _targetDimension = v ?? 1000,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Backup Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2230),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2E384D)),
                      ),
                      child: Tooltip(
                        message:
                            'Save .original_artwork backup before modifying',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Backup',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            Switch(
                              value: _createBackups,
                              activeThumbColor: const Color(0xFFFFB74D),
                              onChanged: _isBusy
                                  ? null
                                  : (val) =>
                                        setState(() => _createBackups = val),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Folder cover.jpg Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2230),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2E384D)),
                      ),
                      child: Tooltip(
                        message: 'Export cover.jpg into album folder for DAP directory browsing',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'cover.jpg',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            Switch(
                              value: _exportFolderCover,
                              activeThumbColor: const Color(0xFF64FFDA),
                              onChanged: _isBusy
                                  ? null
                                  : (val) => setState(
                                      () => _exportFolderCover = val,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Action Buttons (Scan, Fix, or Cancel)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isBusy
                            ? () => setState(() => _isCancelled = true)
                            : (_selectedDirectory == null
                                  ? null
                                  : () => _runProcess(isConvertMode: false)),
                        icon: Icon(
                          _isBusy
                              ? Icons.stop_circle_outlined
                              : Icons.search_rounded,
                        ),
                        label: Text(_isBusy ? 'Cancel' : 'Scan Library'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _isBusy
                              ? Colors.redAccent
                              : const Color(0xFF64FFDA),
                          side: BorderSide(
                            color: _isBusy
                                ? Colors.redAccent
                                : const Color(0xFF64FFDA),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isBusy ||
                                _selectedDirectory == null ||
                                selectedCount == 0
                            ? null
                            : () => _runProcess(isConvertMode: true),
                        icon: const Icon(Icons.auto_fix_high_rounded),
                        label: Text(
                          selectedCount > 0
                              ? 'Fix Selected ($selectedCount)'
                              : 'Fix Album Art',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB74D),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Restore Backups Banner
                if (backupCount > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF64FFDA).withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF64FFDA).withAlpha(80),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          color: Color(0xFF64FFDA),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$backupCount original backups available to restore',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64FFDA),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _isBusy ? null : _restoreAllBackups,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF64FFDA),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            'Restore All',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Live Progress Indicator
                if (_isBusy) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      backgroundColor: const Color(0xFF242C3D),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFFFB74D),
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentFile,
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Stats Counters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildStatBadge('Total', '${_items.length}', Colors.white),
                const SizedBox(width: 8),
                _buildStatBadge(
                  'Needs Fix',
                  '$needsFixCount',
                  const Color(0xFFFF7043),
                  isSelected: _selectedFilter == 'Needs Fix',
                  onTap: () => setState(() => _selectedFilter = 'Needs Fix'),
                ),
                const SizedBox(width: 8),
                _buildStatBadge(
                  'Compliant',
                  '$compliantCount',
                  const Color(0xFF66BB6A),
                  isSelected: _selectedFilter == 'Compliant',
                  onTap: () => setState(() => _selectedFilter = 'Compliant'),
                ),
                const SizedBox(width: 8),
                _buildStatBadge(
                  'Fixed',
                  '$fixedCount',
                  const Color(0xFF64FFDA),
                  isSelected: _selectedFilter == 'Fixed',
                  onTap: () => setState(() => _selectedFilter = 'Fixed'),
                ),
              ],
            ),
          ),

          // Search Bar & Selection Toolbar
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search songs, artists, or albums…',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: Colors.white38,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFF171B24),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2E384D)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2E384D)),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _isBusy ? null : () => _selectAll(true),
                        icon: const Icon(Icons.select_all_rounded, size: 18),
                        label: Text(
                          'Select Problem Tracks ($needsFixCount)',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFFB74D),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _isBusy ? null : () => _selectAll(false),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white54,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'Deselect All',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const Divider(height: 1, color: Color(0xFF222836)),

          // Items List
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _items.isEmpty
                              ? Icons.music_note_rounded
                              : Icons.filter_alt_off_rounded,
                          size: 56,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _items.isEmpty
                              ? 'No audio files scanned yet'
                              : 'No tracks matching current filter/search',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                        ),
                        if (_selectedFilter != 'All' ||
                            _searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => setState(() {
                              _selectedFilter = 'All';
                              _searchQuery = '';
                            }),
                            child: const Text('Reset Filter & Search'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return _buildTrackCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(
    String label,
    String value,
    Color color, {
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap ?? () => setState(() => _selectedFilter = 'All'),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(50) : const Color(0xFF171B24),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : const Color(0xFF272F3E),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackCard(AudioItem item) {
    Color badgeColor;
    String badgeText;

    if (item.isConverted) {
      badgeColor = const Color(0xFF64FFDA);
      badgeText = 'Fixed (Baseline)';
    } else {
      switch (item.compliance) {
        case ArtworkCompliance.baselineJpeg:
          if (item.needsFix) {
            badgeColor = const Color(0xFFFFB74D);
            badgeText = 'Oversized Baseline';
          } else {
            badgeColor = const Color(0xFF66BB6A);
            badgeText = 'Baseline JPEG';
          }
          break;
        case ArtworkCompliance.progressiveJpeg:
          badgeColor = const Color(0xFFFF5252);
          badgeText = 'Progressive (HiBy Incompatible)';
          break;
        case ArtworkCompliance.extendedJpeg:
          badgeColor = const Color(0xFFFF5252);
          badgeText = 'Extended JPEG';
          break;
        case ArtworkCompliance.cmykJpeg:
          badgeColor = const Color(0xFFFF5252);
          badgeText = 'CMYK (Inverts Colors)';
          break;
        case ArtworkCompliance.png:
          badgeColor = const Color(0xFFFF9800);
          badgeText = 'PNG Cover (Needs JPG)';
          break;
        case ArtworkCompliance.noArtwork:
          badgeColor = Colors.grey;
          badgeText = 'No Artwork';
          break;
        case ArtworkCompliance.error:
          badgeColor = Colors.redAccent;
          badgeText = 'Error';
          break;
        default:
          badgeColor = Colors.orangeAccent;
          badgeText = 'Unsupported Format';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: item.isSelected,
              activeColor: const Color(0xFFFFB74D),
              checkColor: Colors.black,
              onChanged: _isBusy
                  ? null
                  : (val) {
                      setState(() {
                        item.isSelected = val ?? false;
                      });
                    },
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: item.thumbnailBytes != null
                    ? Image.memory(
                        item.thumbnailBytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.broken_image,
                              size: 28,
                              color: Colors.white24,
                            ),
                      )
                    : Container(
                        color: const Color(0xFF222836),
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white24,
                        ),
                      ),
              ),
            ),
          ],
        ),
        title: Text(
          item.title ?? item.fileName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.artist ?? 'Unknown Artist'} • ${item.extension.toUpperCase()}',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: badgeColor.withAlpha(100)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
                if (item.artworkWidth != null &&
                    item.artworkHeight != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${item.artworkWidth}x${item.artworkHeight}',
                    style: const TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                ],
              ],
            ),
            if (item.conversionResult != null) ...[
              const SizedBox(height: 2),
              Text(
                item.conversionResult!,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64FFDA)),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.hasBackup)
              IconButton(
                icon: const Icon(
                  Icons.history_rounded,
                  color: Color(0xFF64FFDA),
                ),
                tooltip: 'Restore original artwork from backup',
                onPressed: _isBusy
                    ? null
                    : () async {
                        setState(() => _isBusy = true);
                        await AudioService.restoreBackup(item);
                        if (mounted) setState(() => _isBusy = false);
                      },
              ),
            if (item.needsFix && !item.isConverted)
              IconButton(
                icon: const Icon(
                  Icons.build_circle_outlined,
                  color: Color(0xFFFFB74D),
                ),
                tooltip: 'Fix this single track',
                onPressed: _isBusy
                    ? null
                    : () async {
                        setState(() => _isBusy = true);
                        await AudioService.fixAudioItem(
                          item,
                          maxDimension: _targetDimension,
                          createBackup: _createBackups,
                          exportFolderCover: _exportFolderCover,
                        );
                        if (mounted) setState(() => _isBusy = false);
                      },
              )
            else if (item.isConverted)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF64FFDA),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
