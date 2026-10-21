import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/audio_item.dart';
import 'services/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enforce memory-safe image cache limits to prevent OOM
  PaintingBinding.instance.imageCache.maximumSize = 1000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 40 * 1024 * 1024; // 40MB cap
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
        scaffoldBackgroundColor: Colors.black, // One UI AMOLED Black
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF387AFF), // Authentic Samsung Blue from Figma Kit
          secondary: Color(0xFF34D399), // Mint Green
          surface: Color(0xFF17171A), // Authentic One UI Card Surface from Figma Kit
          surfaceContainerHighest: Color(0xFF242429),
          onPrimary: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF17171A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26), // Authentic One UI 26px Squircle
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

/// One UI Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _initApp();
  }

  Future<void> _initApp() async {
    await AudioService.initCache();
    await Future.delayed(const Duration(milliseconds: 1000));
    final hasPerm = Platform.isAndroid
        ? (await Permission.manageExternalStorage.isGranted ||
            await Permission.storage.isGranted)
        : true;

    if (mounted) {
      final targetScreen = hasPerm
          ? const HomeScreen()
          : const PermissionOnboardingScreen();
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, _, _) => targetScreen,
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFF17171A),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF387AFF).withAlpha(60), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF387AFF).withAlpha(35),
                      blurRadius: 32,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.album_rounded,
                  color: Color(0xFF387AFF),
                  size: 46,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Album Art Fixer',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Audio artwork optimizer',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF848487),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF387AFF)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One UI Permission Onboarding Screen (Exact Figma Tokens)
class PermissionOnboardingScreen extends StatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  State<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState extends State<PermissionOnboardingScreen> {
  bool _isRequesting = false;

  Future<void> _requestAccess() async {
    setState(() => _isRequesting = true);
    bool granted = false;

    if (Platform.isAndroid) {
      final req = await Permission.manageExternalStorage.request();
      if (req.isGranted) {
        granted = true;
      } else {
        final legacy = await Permission.storage.request();
        granted = legacy.isGranted;
      }
    } else {
      granted = true;
    }

    if (mounted) {
      setState(() => _isRequesting = false);
      if (granted) {
        _goToHome();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage access not granted. You can still explore the app.'),
            backgroundColor: Color(0xFF241818),
          ),
        );
      }
    }
  }

  void _goToHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 1),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF17171A),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF387AFF).withAlpha(50), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF387AFF).withAlpha(25),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.album_rounded,
                  color: Color(0xFF387AFF),
                  size: 42,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Storage access',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Album Art Fixer inspects audio metadata and updates incompatible covers directly on your device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF848487),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Grouped Features Card (One UI 26px Radius)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF17171A),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFF2E2E30)),
                ),
                child: Column(
                  children: [
                    _buildFeatureRow(
                      icon: Icons.folder_special_rounded,
                      iconColor: const Color(0xFF387AFF),
                      title: 'Audio file inspection',
                      desc: 'Scans FLAC, MP3, M4A, OGG, and WAV tags.',
                    ),
                    const Divider(color: Color(0xFF2E2E30), height: 26),
                    _buildFeatureRow(
                      icon: Icons.auto_fix_high_rounded,
                      iconColor: const Color(0xFF34D399),
                      title: 'Hardware DAP fix',
                      desc: 'Transcodes progressive/CMYK art to Baseline sRGB.',
                    ),
                    const Divider(color: Color(0xFF2E2E30), height: 26),
                    _buildFeatureRow(
                      icon: Icons.lock_outline_rounded,
                      iconColor: const Color(0xFF848487),
                      title: '100% offline & private',
                      desc: 'Zero network permissions. Files stay on your device.',
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),

              // One UI Rounded Pill Action Button (Samsung Blue)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isRequesting ? null : _requestAccess,
                  icon: _isRequesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.security_rounded, size: 20),
                  label: Text(
                    _isRequesting ? 'Requesting...' : 'Grant all files access',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF387AFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _goToHome,
                child: const Text(
                  'Not now / explore app',
                  style: TextStyle(color: Color(0xFF848487), fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(25),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(fontSize: 12, color: Color(0xFF848487)),
              ),
            ],
          ),
        ),
      ],
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
  String _statusMessage = 'Choose music directory or SD card to begin.';
  double _progress = 0.0;
  String _currentFile = '';
  String _searchQuery = '';
  bool _showSettings = false;

  // Settings
  int _targetDimension = 1000;
  bool _createBackups = true;
  bool _exportFolderCover = true;
  String _selectedFilter = 'All';

  Future<bool> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;
    final req = await Permission.manageExternalStorage.request();
    if (req.isGranted) return true;
    final legacy = await Permission.storage.request();
    return legacy.isGranted;
  }

  Future<void> _pickDirectory() async {
    final hasPerm = await _ensureStoragePermission();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to read & update album artwork.'),
            backgroundColor: Color(0xFF241818),
          ),
        );
      }
      return;
    }

    final result = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Music Directory or SD Card',
    );

    if (result != null && mounted) {
      setState(() {
        _selectedDirectory = result;
        _items.clear();
        _statusMessage = 'Folder selected. Tap "Scan library" below.';
        _progress = 0.0;
        _currentFile = '';
      });
    }
  }

  Future<void> _runProcess({required bool isConvertMode}) async {
    if (_selectedDirectory == null) {
      await _pickDirectory();
      return;
    }

    setState(() {
      _isBusy = true;
      _isCancelled = false;
      _progress = 0.0;
      _statusMessage = isConvertMode
          ? 'Converting selected covers to Baseline sRGB...'
          : 'Scanning tracks & binary JPEG markers...';
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

    const chunkSize = 16;
    for (int i = 0; i < total; i += chunkSize) {
      if (!mounted || _isCancelled) break;
      final end = (i + chunkSize < total) ? i + chunkSize : total;
      final chunk = files.sublist(i, end);

      if (!isConvertMode) {
        final chunkResults = await Future.wait(
          chunk.map((f) => AudioService.inspectAudioFile(f)),
        );
        scannedItems.addAll(chunkResults);
      } else {
        await Future.wait(
          chunk.map((file) async {
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
          }),
        );
      }

      if (mounted) {
        setState(() {
          _currentFile = chunk.last.path.split(Platform.pathSeparator).last;
          _progress = end / total;
          if (!isConvertMode && (i == 0 || i % 64 == 0 || end == total)) {
            _items = List.from(scannedItems);
          }
        });
      }
    }

    await AudioService.saveCache();

    if (mounted) {
      setState(() {
        _isBusy = false;
        if (!isConvertMode) {
          _items = scannedItems;
          final needsFixCount = _items.where((i) => i.needsFix).length;
          _statusMessage = _isCancelled
              ? 'Scan cancelled.'
              : 'Scan complete: ${_items.length} tracks ($needsFixCount need fix).';
        } else {
          _statusMessage = _isCancelled
              ? 'Conversion cancelled.'
              : 'Done! Successfully fixed $convertedCount tracks.';
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
        backgroundColor: const Color(0xFF17171A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: const Text('Restore all backups?'),
        content: Text(
          'This will revert all ${backedUp.length} tracks to their original uncompressed artwork.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF387AFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: const Text('Restore all'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isBusy = true;
      _statusMessage = 'Restoring original backups...';
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
    final needsFixCount = _items.where((i) => i.needsFix && !i.isConverted).length;
    final compliantCount = _items.where((i) => i.compliance == ArtworkCompliance.baselineJpeg && !i.needsFix).length;
    final fixedCount = _items.where((i) => i.isConverted).length;
    final selectedCount = _items.where((i) => i.isSelected && i.needsFix && !i.isConverted).length;
    final backupCount = _items.where((i) => i.hasBackup).length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Authentic One UI Large Expansive Header (Figma 36px 700 Bold Title)
            SliverAppBar(
              expandedHeight: 148.0,
              pinned: true,
              backgroundColor: Colors.black,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: false,
                titlePadding: const EdgeInsets.fromLTRB(20, 0, 16, 14),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF387AFF).withAlpha(40),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.album_rounded,
                        color: Color(0xFF387AFF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Album Art Fixer',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (backupCount > 0)
                  IconButton(
                    icon: const Icon(Icons.history_rounded, color: Color(0xFF387AFF), size: 22),
                    tooltip: 'Restore backups ($backupCount)',
                    onPressed: _isBusy ? null : _restoreAllBackups,
                  ),
                IconButton(
                  icon: Icon(
                    _showSettings ? Icons.tune_rounded : Icons.tune_outlined,
                    color: _showSettings ? const Color(0xFF387AFF) : const Color(0xFF848487),
                    size: 22,
                  ),
                  tooltip: 'Settings',
                  onPressed: () => setState(() => _showSettings = !_showSettings),
                ),
                const SizedBox(width: 8),
              ],
            ),

            // One UI Content Area
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtitle / Status Overview (Sentence case, #848487)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        _items.isNotEmpty
                            ? '${_items.length} tracks • $needsFixCount need fix'
                            : 'Select music directory to inspect artwork',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF848487)),
                      ),
                    ),

                    // One UI Folder Card (26px radius, #17171A surface, #2E2E30 border)
                    InkWell(
                      onTap: _isBusy ? null : _pickDirectory,
                      borderRadius: BorderRadius.circular(26),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17171A),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: const Color(0xFF2E2E30)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF242429),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.folder_open_rounded,
                                color: Color(0xFF387AFF),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedDirectory != null ? 'Music directory' : 'Choose music folder',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedDirectory ?? 'Browse storage or SD card',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _selectedDirectory != null ? const Color(0xFF848487) : Colors.white38,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF242429),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF2E2E30)),
                              ),
                              child: Text(
                                _selectedDirectory != null ? 'Change' : 'Browse',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expandable One UI Settings Card
                    if (_showSettings) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17171A),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: const Color(0xFF2E2E30)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CONVERSION SETTINGS',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF848487), letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Max dimension', style: TextStyle(fontSize: 14, color: Colors.white)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF242429),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF2E2E30)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _targetDimension,
                                      dropdownColor: const Color(0xFF242429),
                                      items: const [
                                        DropdownMenuItem(value: 600, child: Text('600×600 px', style: TextStyle(fontSize: 13))),
                                        DropdownMenuItem(value: 800, child: Text('800×800 px (Best)', style: TextStyle(fontSize: 13))),
                                        DropdownMenuItem(value: 1000, child: Text('1000×1000 px', style: TextStyle(fontSize: 13))),
                                        DropdownMenuItem(value: 0, child: Text('Original size', style: TextStyle(fontSize: 13))),
                                      ],
                                      onChanged: _isBusy ? null : (v) => setState(() => _targetDimension = v ?? 1000),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Color(0xFF2E2E30), height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Create backup files', style: TextStyle(fontSize: 14, color: Colors.white)),
                                    Text('Keep .albumartfixer-backup file', style: TextStyle(fontSize: 11, color: Color(0xFF848487))),
                                  ],
                                ),
                                Switch(
                                  value: _createBackups,
                                  activeThumbColor: const Color(0xFF387AFF),
                                  onChanged: _isBusy ? null : (v) => setState(() => _createBackups = v),
                                ),
                              ],
                            ),
                            const Divider(color: Color(0xFF2E2E30), height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Export cover.jpg', style: TextStyle(fontSize: 14, color: Colors.white)),
                                    Text('Save in song folder for DAP browsing', style: TextStyle(fontSize: 11, color: Color(0xFF848487))),
                                  ],
                                ),
                                Switch(
                                  value: _exportFolderCover,
                                  activeThumbColor: const Color(0xFF34D399),
                                  onChanged: _isBusy ? null : (v) => setState(() => _exportFolderCover = v),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Progress Indicator
                    if (_isBusy || _progress > 0) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _isBusy ? _progress : 1.0,
                          backgroundColor: const Color(0xFF1C1C1E),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF387AFF)),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _currentFile.isNotEmpty ? _currentFile : _statusMessage,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF848487), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          Text(
                            '${(_progress * 100).toInt()}%',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF387AFF)),
                          ),
                        ],
                      ),
                    ],

                    // Quick Issue Alert Banner
                    if (!_isBusy && _items.isNotEmpty && needsFixCount > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF241818),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFFF5E57).withAlpha(100)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFFFF5E57), size: 22),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$needsFixCount tracks have incompatible art',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                  ),
                                  const Text('Ready to convert to standard Baseline JPEG', style: TextStyle(fontSize: 11, color: Colors.white60)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _selectAll(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF387AFF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Select all', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Search Pill & Filter Capsules (when library is loaded)
                    if (_items.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF17171A),
                          borderRadius: BorderRadius.circular(23),
                          border: Border.all(color: const Color(0xFF2E2E30)),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search songs, artist, or album...',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF848487)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF848487)),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF848487)),
                                    onPressed: () => setState(() => _searchQuery = ''),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildOneUiFilterPill('All', _items.length),
                            _buildOneUiFilterPill('Needs Fix', needsFixCount, badgeColor: const Color(0xFFFF5E57)),
                            _buildOneUiFilterPill('Compliant', compliantCount, badgeColor: const Color(0xFF34D399)),
                            _buildOneUiFilterPill('Fixed', fixedCount, badgeColor: const Color(0xFF34D399)),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _selectAll(false),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                backgroundColor: const Color(0xFF17171A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Deselect', style: TextStyle(fontSize: 12, color: Color(0xFF848487))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),

            // Track List / Empty State
            if (_items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Color(0xFF17171A),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isBusy ? Icons.hourglass_top_rounded : Icons.library_music_rounded,
                            size: 46,
                            color: const Color(0xFF387AFF),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _selectedDirectory != null ? 'Ready to scan' : 'No folder selected',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF848487), fontSize: 13),
                        ),
                        const SizedBox(height: 22),
                        if (_selectedDirectory == null)
                          ElevatedButton.icon(
                            onPressed: _pickDirectory,
                            icon: const Icon(Icons.folder_open_rounded, size: 18),
                            label: const Text('Select music folder'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF387AFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _filteredItems[index];
                      return _buildTrackCard(item);
                    },
                    childCount: _filteredItems.length,
                  ),
                ),
              ),
          ],
        ),
      ),

      // One UI Bottom Pill Action Bar (Samsung Blue 52dp)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: Color(0xFF1C1C1E))),
        ),
        child: Row(
          children: [
            if (_items.isNotEmpty || _isBusy) ...[
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isBusy
                        ? () => setState(() => _isCancelled = true)
                        : (_selectedDirectory == null
                              ? null
                              : () => _runProcess(isConvertMode: false)),
                    icon: Icon(
                      _isBusy ? Icons.stop_circle_outlined : Icons.refresh_rounded,
                      size: 18,
                    ),
                    label: Text(_isBusy ? 'Cancel' : 'Rescan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF2E2E30)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],

            Expanded(
              flex: 3,
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isBusy
                      ? null
                      : (_selectedDirectory == null
                            ? _pickDirectory
                            : (_items.isEmpty
                                  ? () => _runProcess(isConvertMode: false)
                                  : (selectedCount > 0 ? () => _runProcess(isConvertMode: true) : null))),
                  icon: Icon(
                    _selectedDirectory == null
                        ? Icons.folder_open_rounded
                        : (_items.isEmpty ? Icons.search_rounded : Icons.auto_fix_high_rounded),
                    size: 18,
                  ),
                  label: Text(
                    _selectedDirectory == null
                        ? 'Select folder'
                        : (_items.isEmpty
                              ? 'Scan library'
                              : (selectedCount > 0 ? 'Fix ($selectedCount)' : 'Select tracks')),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF387AFF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF242429),
                    disabledForegroundColor: const Color(0xFF848487),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOneUiFilterPill(String title, int count, {Color? badgeColor}) {
    final isSelected = _selectedFilter == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = title),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFF17171A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2E2E30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.black : Colors.white70,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.black
                    : (badgeColor?.withAlpha(40) ?? const Color(0xFF242429)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : (badgeColor ?? Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackCard(AudioItem item) {
    Color badgeColor;
    String badgeText;

    if (item.isConverted) {
      badgeColor = const Color(0xFF34D399);
      badgeText = 'FIXED BASELINE';
    } else {
      switch (item.compliance) {
        case ArtworkCompliance.baselineJpeg:
          if (item.needsFix) {
            badgeColor = const Color(0xFFFFA502);
            badgeText = 'OVERSIZED';
          } else {
            badgeColor = const Color(0xFF34D399);
            badgeText = 'BASELINE OK';
          }
          break;
        case ArtworkCompliance.progressiveJpeg:
          badgeColor = const Color(0xFFFF5E57);
          badgeText = 'PROGRESSIVE';
          break;
        case ArtworkCompliance.cmykJpeg:
          badgeColor = const Color(0xFFFF4757);
          badgeText = 'CMYK';
          break;
        case ArtworkCompliance.png:
          badgeColor = const Color(0xFF387AFF);
          badgeText = 'PNG';
          break;
        case ArtworkCompliance.extendedJpeg:
          badgeColor = const Color(0xFFFF7043);
          badgeText = 'EXTENDED';
          break;
        case ArtworkCompliance.noArtwork:
          badgeColor = const Color(0xFF757575);
          badgeText = 'NO COVER';
          break;
        default:
          badgeColor = const Color(0xFFE040FB);
          badgeText = 'NON-STANDARD';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF17171A),
        borderRadius: BorderRadius.circular(22),
        border: item.isSelected && item.needsFix
            ? Border.all(color: const Color(0xFF387AFF).withAlpha(140), width: 1.2)
            : Border.all(color: const Color(0xFF2E2E30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (item.needsFix && !item.isConverted)
            Checkbox(
              value: item.isSelected,
              activeColor: const Color(0xFF387AFF),
              checkColor: Colors.white,
              onChanged: _isBusy
                  ? null
                  : (val) => setState(() => item.isSelected = val ?? false),
            )
          else
            const SizedBox(width: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 52,
              height: 52,
              color: const Color(0xFF242429),
              child: item.thumbnailBytes != null
                  ? Image.memory(
                      item.thumbnailBytes!,
                      fit: BoxFit.cover,
                      cacheWidth: 96,
                      cacheHeight: 96,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white24,
                        size: 24,
                      ),
                    )
                  : const Icon(
                      Icons.music_note_rounded,
                      color: Colors.white24,
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title ?? item.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.artist ?? 'Unknown artist'} • ${item.extension.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF848487),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: badgeColor.withAlpha(120), width: 0.8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.artworkWidth != null
                            ? '${item.artworkWidth}×${item.artworkHeight} px'
                            : item.statusDescription,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white38,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (item.hasBackup)
            IconButton(
              icon: const Icon(Icons.restore_rounded, size: 20, color: Color(0xFF387AFF)),
              tooltip: 'Restore original artwork',
              onPressed: _isBusy
                  ? null
                  : () async {
                      final ok = await AudioService.restoreBackup(item);
                      if (mounted) {
                        setState(() {
                          _statusMessage = ok
                              ? 'Restored ${item.fileName}'
                              : 'Failed to restore';
                        });
                      }
                    },
            )
          else if (item.isConverted)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 20),
            ),
        ],
      ),
    );
  }
}
