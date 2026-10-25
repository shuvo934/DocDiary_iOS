import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'native_photo_icons.dart';
import 'dashboard_services.dart';

/// Native CameraPreview layout: switch/flash, shutter, then retake/confirm.
/// iOS adds a close control because it has no Android hardware Back button.
class NativeCameraScreen extends StatefulWidget {
  const NativeCameraScreen({super.key});
  @override
  State<NativeCameraScreen> createState() => _NativeCameraScreenState();
}

class _NativeCameraScreenState extends State<NativeCameraScreen>
    with WidgetsBindingObserver {
  final _toasts = AppToastOwner();
  CameraController? _camera;
  List<CameraDescription>? _cameras;
  bool _front = false;
  bool _flash = false;
  bool _busy = true;
  bool _foreground = true;
  bool _permissionDenied = false;
  String? _error;
  String? _captured;
  bool _returned = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  Future<void> _release(CameraController? controller) async {
    try {
      await controller?.dispose();
    } on CameraException {
      // A disconnected camera may already have been released by iOS.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      // Permission prompts make iOS inactive while initialize is still pending.
      // Let that request finish; initialized devices are released on background.
      if (_camera?.value.isInitialized != true) {
        return;
      }
      ++_generation;
      final old = _camera;
      _camera = null;
      unawaited(_release(old));
    } else if (_captured == null && (_camera == null || _error != null)) {
      unawaited(_start());
    }
  }

  Future<void> _start() async {
    final generation = ++_generation;
    final previous = _camera;
    _camera = null;
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
        _permissionDenied = false;
      });
    }
    await _release(previous);
    try {
      _cameras ??= await availableCameras();
      if (!mounted || generation != _generation) {
        return;
      }
      if (_cameras!.isEmpty) {
        throw CameraException(
          'no_camera',
          'Camera is unavailable. Use a real iPhone or choose Gallery.',
        );
      }
      final desired =
          _front ? CameraLensDirection.front : CameraLensDirection.back;
      final description = _cameras!.firstWhere(
        (camera) => camera.lensDirection == desired,
        orElse: () => _cameras!.first,
      );
      _front = description.lensDirection == CameraLensDirection.front;
      final controller = CameraController(
        description,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      _camera = controller;
      await controller.initialize();
      if (!mounted || generation != _generation) {
        return;
      }
      if (!_foreground) {
        _camera = null;
        await _release(controller);
        return;
      }
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.setFlashMode(FlashMode.off);
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _flash = false;
        });
      }
    } on CameraException catch (failure) {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _permissionDenied =
              failure.code.contains('AccessDenied') ||
              failure.code.contains('Restricted');
          _error =
              _permissionDenied
                  ? 'Camera access is unavailable. Allow DocDiary camera access in iPhone Settings.'
                  : failure.description ??
                      'Camera could not be opened. Please try again.';
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _camera;
    if (_busy ||
        !_foreground ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }
    if (_front) {
      _notice('Flash is not available for front camera.');
      return;
    }
    final generation = _generation;
    try {
      final enabled = !_flash;
      await controller.setFlashMode(enabled ? FlashMode.always : FlashMode.off);
      if (mounted && generation == _generation) {
        setState(() => _flash = enabled);
      }
    } on CameraException {
      _notice('Flash is not available for this camera.');
    }
  }

  void _notice(String message) {
    if (mounted) {
      _toasts.show(context, message);
    }
  }

  Future<void> _capture() async {
    final controller = _camera;
    if (_busy ||
        !_foreground ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }
    setState(() => _busy = true);
    final generation = _generation;
    String? pendingPath;
    try {
      final file = await controller.takePicture();
      pendingPath = file.path;
      if (!mounted || generation != _generation) {
        await _delete(file.path);
        return;
      }
      final bytes = await File(file.path).readAsBytes();
      final oriented = await compute(orientDashboardCapture, (
        bytes: bytes,
        mirror: _front,
      ));
      if (!mounted || generation != _generation) {
        await _delete(file.path);
        return;
      }
      await File(file.path).writeAsBytes(oriented, flush: true);
      _captured = file.path;
      _camera = null;
      await _release(controller);
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
      }
    } on CameraException {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        _notice('Failed to capture image. Please try again.');
      }
    } on FileSystemException {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        _notice('Failed to save image. Please try again.');
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        _notice('Invalid image. Please try again.');
      }
    } finally {
      if (pendingPath != null && _captured != pendingPath) {
        await _delete(pendingPath);
      }
    }
  }

  Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // This app-owned temporary file may already have been removed.
    }
  }

  Future<void> _retake() async {
    final old = _captured;
    setState(() => _captured = null);
    if (old != null) {
      await _delete(old);
    }
    if (mounted) {
      await _start();
    }
  }

  Future<void> _settings() async {
    try {
      final opened = await launchUrl(
        Uri.parse('app-settings:'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        _notice('Open iPhone Settings and allow Camera access for DocDiary.');
      }
    } on PlatformException {
      _notice('Open iPhone Settings and allow Camera access for DocDiary.');
    }
  }

  @override
  void dispose() {
    _toasts.dispose();
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_release(_camera));
    final path = _captured;
    if (!_returned && path != null) {
      unawaited(_delete(path));
    }
    super.dispose();
  }

  Widget _icon(
    String label,
    NativePhotoGlyph glyph,
    double size,
    VoidCallback? onPressed,
  ) => IconButton(
    tooltip: label,
    padding: EdgeInsets.zero,
    constraints: BoxConstraints.tightFor(width: size, height: size),
    onPressed: onPressed,
    icon: NativePhotoIcon(glyph, size: size),
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.shortestSide;
    final sdp = width < 300 ? 1.0 : (width / 30).floor() * 30 / 300;
    final controller = _camera;
    final captured = _captured;
    return Scaffold(
      key: const Key('dashboard_camera_screen'),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (captured != null) ...[
            Positioned.fill(
              bottom: 140 * sdp + media.padding.bottom,
              child: Image.file(File(captured), fit: BoxFit.contain),
            ),
            Positioned(
              left: 38 * sdp,
              right: 38 * sdp,
              bottom: 45 * sdp + media.padding.bottom,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Retake',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints.tightFor(
                      width: 50 * sdp,
                      height: 50 * sdp,
                    ),
                    onPressed: _busy ? null : _retake,
                    icon: Image.asset(
                      'assets/images/pic_check_cancel.png',
                      width: 50 * sdp,
                      height: 50 * sdp,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Use picture',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints.tightFor(
                      width: 50 * sdp,
                      height: 50 * sdp,
                    ),
                    onPressed:
                        _busy
                            ? null
                            : () {
                              _returned = true;
                              Navigator.pop(context, captured);
                            },
                    icon: Image.asset(
                      'assets/images/pic_check_circle.png',
                      width: 50 * sdp,
                      height: 50 * sdp,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            if (controller != null &&
                controller.value.isInitialized &&
                _error == null)
              Center(child: CameraPreview(controller)),
            if (_error != null)
              Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: _permissionDenied ? _settings : _start,
                          child: Text(
                            _permissionDenied ? 'Open Settings' : 'Try again',
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 15 * sdp,
              right: 15 * sdp,
              top: math.max(media.padding.top + 8, 42 * sdp),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _icon(
                    'Switch camera',
                    NativePhotoGlyph.switchCamera,
                    24 * sdp,
                    _busy || _error != null
                        ? null
                        : () {
                          _front = !_front;
                          unawaited(_start());
                        },
                  ),
                  _icon(
                    'Close camera',
                    NativePhotoGlyph.close,
                    24 * sdp,
                    () => Navigator.pop(context),
                  ),
                  _icon(
                    'Flash',
                    _flash
                        ? NativePhotoGlyph.flashOn
                        : NativePhotoGlyph.flashOff,
                    24 * sdp,
                    _busy || _error != null ? null : _toggleFlash,
                  ),
                ],
              ),
            ),
            if (_error == null)
              Positioned(
                bottom: math.max(media.padding.bottom + 16, 48 * sdp),
                left: 0,
                right: 0,
                child: Center(
                  child: _icon(
                    'Take picture',
                    NativePhotoGlyph.shutter,
                    60 * sdp,
                    _busy ? null : _capture,
                  ),
                ),
              ),
          ],
          if (_busy)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}
