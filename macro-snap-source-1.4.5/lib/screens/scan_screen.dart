import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme.dart';
import '../services/scan_gate.dart';
import '../widgets/gradient_button.dart';
import 'result_screen.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadScans();
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  Future<void> _capture() async {
    if (!await ScanGate.canScan()) {
      if (mounted) _showLimitDialog();
      return;
    }
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final xfile = await _controller!.takePicture();
      await ScanGate.incrementScan();
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/food_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await xfile.saveTo(tempFile.path);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(imagePath: tempFile.path),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e'), backgroundColor: MacroSnapTheme.rose),
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
      await ScanGate.incrementScan();
      final bytes = await image.readAsBytes();
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/food_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(imagePath: tempFile.path),
          ),
        );
      }
    }
  }

  void _showLimitDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MacroSnapTheme.amber.withOpacity( 0.1),
              ),
              child: const Icon(Icons.flash_on_rounded,
                  color: MacroSnapTheme.amber, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Free scans used up',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text('You get 3 free AI scans per month.\nGo Pro for unlimited scans.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B), height: 1.4)),
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
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canUse = _scansLeft > 0;

    if (_cameraError) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
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
              const Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 64),
              const SizedBox(height: 16),
              Text('Camera unavailable',
                  style: TextStyle(color: Colors.white.withOpacity( 0.6), fontSize: 18)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Choose from Gallery'),
                style: FilledButton.styleFrom(backgroundColor: MacroSnapTheme.emerald),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: MacroSnapTheme.emerald),
              SizedBox(height: 16),
              Text('Starting camera...', style: TextStyle(color: Colors.white38)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        children: [
          // Live camera preview
          if (_controller != null && _controller!.value.isInitialized)
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            ),

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
                    Colors.black.withOpacity( 0.7),
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
                        color: (canUse ? MacroSnapTheme.emerald : MacroSnapTheme.rose).withOpacity( 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (canUse ? MacroSnapTheme.emerald : MacroSnapTheme.rose).withOpacity( 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flash_on_rounded, size: 14,
                              color: canUse ? MacroSnapTheme.emerald : MacroSnapTheme.rose),
                          const SizedBox(width: 4),
                          Text(
                            _scansLeft >= 99 ? 'Unlimited' : '$_scansLeft left',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: canUse ? MacroSnapTheme.emerald : MacroSnapTheme.rose,
                            ),
                          ),
                        ],
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
                          color: Colors.white.withOpacity( 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity( 0.2)),
                        ),
                        child: Icon(Icons.photo_library_rounded,
                            color: Colors.white.withOpacity( 0.8), size: 24),
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
                              colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight],
                            ),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 28),
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
        ],
      ),
    );
  }
}

