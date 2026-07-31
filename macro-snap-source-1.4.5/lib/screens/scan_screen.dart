import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme.dart';
import '../services/scan_gate.dart';
import '../services/meal_store.dart';
import '../widgets/animations.dart';
import '../widgets/gradient_button.dart';
import 'result_screen.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _initialized = false;
  bool _cameraError = false;
  int _scansLeft = 3;
  String? _capturedImagePath;
  Timer? _previewTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadScans();
    _initCamera();
    // Refresh scan count when data changes (e.g. after subscribing)
    MealStore.instance.changeNotifier.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    _loadScans();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    MealStore.instance.changeNotifier.removeListener(_onDataChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.resumed) {
      _controller?.resumePreview();
    } else if (state == AppLifecycleState.paused) {
      _controller?.pausePreview();
    }
  }

  Future<void> _loadScans() async {
    final remaining = await ScanGate.getScansRemaining();
    if (mounted) setState(() => _scansLeft = remaining);
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) setState(() => _cameraError = true);
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = true);
        return;
      }
      final controller = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (mounted) {
        setState(() {
          _controller = controller;
          _initialized = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cameraError = true);
    }
  }

  void _navigateToResult(String path) {
    if (!mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => ResultScreen(imagePath: path),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  void _showPreview(String path) {
    setState(() => _capturedImagePath = path);
    // Auto-navigate after a brief preview so Hero can animate
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _capturedImagePath = null);
        _navigateToResult(path);
      }
    });
  }

  Future<void> _capture() async {
    if (!await ScanGate.canScan()) {
      if (mounted) _showLimitDialog();
      return;
    }
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final xfile = await _controller!.takePicture();
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/food_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await xfile.saveTo(tempFile.path);
      // Scan is only counted AFTER successful AI analysis (in ResultScreen),
      // so failed analyses don't consume the free limit.
      if (mounted) {
        _showPreview(tempFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e'), backgroundColor: MacroSnapTheme.neonPink),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (!await ScanGate.canScan()) {
      if (mounted) _showLimitDialog();
      return;
    }
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 70);
    if (image != null && mounted) {
      final bytes = await image.readAsBytes();
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/food_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);
      // Scan is only counted AFTER successful AI analysis (in ResultScreen),
      // so failed analyses don't consume the free limit.
      if (mounted) {
        _showPreview(tempFile.path);
      }
    }
  }

  void _showLimitDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? MacroSnapTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MacroSnapTheme.neonOrange.withValues(alpha:  0.1),
              ),
              child: const Icon(Icons.flash_on_rounded,
                  color: MacroSnapTheme.neonOrange, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Free scans used up',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
            const SizedBox(height: 8),
            Text('You get 3 free AI scans per month.\nGo Pro for unlimited scans.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14,
                    color: MacroSnapTheme.textSecondary(context), height: 1.4)),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Go Pro - \u20B929/mo',
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
              },
              height: 48,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Maybe later',
                  style: TextStyle(fontSize: 14,
                      color: MacroSnapTheme.textTertiary(context))),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canUse = _scansLeft > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_cameraError) {
      return Scaffold(
        backgroundColor: isDark ? MacroSnapTheme.surfaceDark : MacroSnapTheme.surfaceLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent, elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8), size: 64),
              const SizedBox(height: 16),
              Text('Camera unavailable',
                  style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : const Color(0xFF475569),
                      fontSize: 18)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Choose from Gallery'),
                style: FilledButton.styleFrom(backgroundColor: MacroSnapTheme.neonGreen, foregroundColor: Colors.black),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Scaffold(
        backgroundColor: isDark ? MacroSnapTheme.surfaceDark : MacroSnapTheme.surfaceLight,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: MacroSnapTheme.neonGreen),
              const SizedBox(height: 16),
              Text('Starting camera...',
                  style: TextStyle(
                      color: isDark ? Colors.white38 : const Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MacroSnapTheme.surfaceDark,
      body: Stack(
        children: [
          // Live camera preview — OverflowBox allows camera to exceed
          // screen bounds to maintain native aspect ratio, ClipRect crops overflow
          if (_controller != null && _controller!.value.isInitialized)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenAspect = constraints.maxWidth / constraints.maxHeight;
                  final cameraAspect = _controller!.value.aspectRatio;
                  return ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.center,
                      maxHeight: screenAspect > cameraAspect
                          ? constraints.maxWidth / cameraAspect
                          : constraints.maxHeight,
                      maxWidth: screenAspect > cameraAspect
                          ? constraints.maxWidth
                          : constraints.maxHeight * cameraAspect,
                      child: CameraPreview(_controller!),
                    ),
                  );
                },
              ),
            ),

          // ─── Captured Image Preview (Hero source) ─────────
          if (_capturedImagePath != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _previewTimer?.cancel();
                  if (mounted) {
                    final path = _capturedImagePath!;
                    setState(() => _capturedImagePath = null);
                    _navigateToResult(path);
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'food_image_$_capturedImagePath',
                      child: Image.file(
                        File(_capturedImagePath!),
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Dark overlay + hint text
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 40,
                      left: 0, right: 0,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome_rounded, color: MacroSnapTheme.neonGreen, size: 18),
                                SizedBox(width: 8),
                                Text('Analyzing your meal...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Tap anywhere to continue',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ─── Camera overlays (hidden during preview) ───────
          if (_capturedImagePath == null) ...[

          // Dark gradient overlay at bottom for button visibility
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha:  0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (canUse ? MacroSnapTheme.neonGreen : MacroSnapTheme.neonPink).withValues(alpha:  0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (canUse ? MacroSnapTheme.neonGreen : MacroSnapTheme.neonPink).withValues(alpha:  0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flash_on_rounded, size: 14,
                              color: canUse ? MacroSnapTheme.neonGreen : MacroSnapTheme.neonPink),
                          const SizedBox(width: 4),
                          Text(
                            _scansLeft >= 99 ? 'Unlimited' : '$_scansLeft left',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: canUse ? MacroSnapTheme.neonGreen : MacroSnapTheme.neonPink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Settings button
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          habitFlowRoute(const SettingsScreen())),
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha:  0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.settings_rounded,
                            color: Colors.white60, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom action bar
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                child: Row(
                  children: [
                    // Gallery button
                    GestureDetector(
                      onTap: _pickFromGallery,
                      child: Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha:  0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha:  0.2)),
                        ),
                        child: Icon(Icons.photo_library_rounded,
                            color: Colors.white.withValues(alpha:  0.8), size: 24),
                      ),
                    ),
                    const Spacer(),
                    // Capture button
                    GestureDetector(
                      onTap: _capture,
                      child: Container(
                        width: 76, height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [MacroSnapTheme.neonGreen, Color(0xFF00CC52)],
                            ),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.black, size: 28),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Spacer for symmetry
                    const SizedBox(width: 52),
                  ],
                ),
              ),
            ),
          ),

          ], // end if _capturedImagePath == null
        ],
      ),
    );
  }
}

