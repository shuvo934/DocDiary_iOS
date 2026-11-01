import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract interface class ReportPdfPlatform {
  Widget buildView({
    required Uint8List bytes,
    required String documentName,
    required ValueChanged<int> onLoaded,
    required ValueChanged<String> onError,
  });
  Future<int> page(int index);
  Future<void> zoom(bool zoomIn);
  Future<bool> save();
  Future<void> suspend();
  void dispose();
}

class IosReportPdfPlatform implements ReportPdfPlatform {
  MethodChannel? _channel;
  bool _disposed = false;
  int _generation = 0;
  @override
  Widget buildView({
    required Uint8List bytes,
    required String documentName,
    required ValueChanged<int> onLoaded,
    required ValueChanged<String> onError,
  }) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return const Center(
        child: Text('Report PDF preview is available in the iOS app.'),
      );
    }
    return UiKitView(
      key: ObjectKey(bytes),
      viewType: 'docdiary/report_pdf',
      onPlatformViewCreated: (id) async {
        if (_disposed) return;
        final generation = ++_generation,
            channel = MethodChannel('docdiary/report_pdf/$id');
        _channel = channel;
        try {
          final count = await channel
              .invokeMethod<int>('load', {
                'bytes': bytes,
                'documentName': documentName,
              })
              .timeout(const Duration(seconds: 25));
          if (_disposed || generation != _generation) return;
          if (count == null || count < 1 || count > 2000) {
            onError('The report PDF contains no readable pages.');
          } else {
            onLoaded(count);
          }
        } catch (_) {
          if (!_disposed && generation == _generation) {
            onError('The report PDF could not be opened. Please try again.');
          }
        }
      },
    );
  }

  MethodChannel get _active {
    if (_disposed || _channel == null) {
      throw PlatformException(
        code: 'unavailable',
        message: 'The report PDF is not ready.',
      );
    }
    return _channel!;
  }

  @override
  Future<int> page(int index) async =>
      await _active
          .invokeMethod<int>('page', {'index': index})
          .timeout(const Duration(seconds: 20)) ??
      index;
  @override
  Future<bool> save() async =>
      await _active.invokeMethod<bool>('save') ?? false;
  @override
  Future<void> zoom(bool zoomIn) async => await _active
      .invokeMethod<void>('zoom', {'factor': zoomIn ? 1.25 : .8})
      .timeout(const Duration(seconds: 20));
  @override
  Future<void> suspend() async {
    ++_generation;
    final channel = _channel;
    _channel = null;
    try {
      await channel?.invokeMethod<void>('suspend');
    } catch (_) {
      /* View already removed. */
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(
        channel.invokeMethod<void>('dispose').catchError((Object _) {}),
      );
    }
  }
}
