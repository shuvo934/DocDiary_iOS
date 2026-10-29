import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dynamic_preview_pdf_layout.dart';

enum DynamicPreviewAction { download, print, share }

/// The HTML renderer and system document actions have one owner per preview.
abstract class DynamicPreviewPlatform {
  Widget buildView({
    required String html,
    required String documentName,
    required VoidCallback onReady,
    required ValueChanged<String> onError,
  });
  Future<bool> perform(DynamicPreviewAction action);
  Future<void> suspend();
  void dispose();
}

class IosDynamicPreviewPlatform implements DynamicPreviewPlatform {
  MethodChannel? _channel;
  bool _disposed = false;
  int _generation = 0;

  @override
  Widget buildView({
    required String html,
    required String documentName,
    required VoidCallback onReady,
    required ValueChanged<String> onError,
  }) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          onError('Prescription preview is available in the iOS app.');
        }
      });
      return const SizedBox.shrink();
    }
    return UiKitView(
      key: ValueKey(html),
      viewType: 'docdiary/dynamic_preview',
      layoutDirection: TextDirection.ltr,
      onPlatformViewCreated: (id) async {
        final generation = ++_generation;
        final old = _channel;
        old?.setMethodCallHandler(null);
        if (old != null) {
          unawaited(
            old.invokeMethod<void>('dispose').catchError((Object _) {}),
          );
        }
        final channel = MethodChannel('docdiary/dynamic_preview/$id');
        _channel = channel;
        channel.setMethodCallHandler((call) async {
          if (_disposed || generation != _generation) return;
          if (call.method == 'ready') onReady();
          if (call.method == 'error') {
            onError(
              call.arguments?.toString() ??
                  'Prescription layout could not be prepared.',
            );
          }
        });
        try {
          await channel.invokeMethod<void>('load', {
            'html': html,
            'documentName': documentName,
          });
        } catch (error) {
          if (!_disposed && generation == _generation) {
            onError(
              error is PlatformException
                  ? error.message ??
                      'Prescription layout could not be prepared.'
                  : 'Prescription preview could not start. Stop and run the iOS app again.',
            );
          }
        }
      },
    );
  }

  @override
  Future<bool> perform(DynamicPreviewAction action) async {
    final channel = _channel;
    if (_disposed || channel == null) {
      throw StateError('Prescription preview is not ready.');
    }
    final measured = await channel.invokeMapMethod<String, Object?>('measure');
    if (_disposed || !identical(_channel, channel)) return false;
    final layout = DynamicPreviewPdfLayout.fromData(
      measured ?? <String, Object?>{},
    );
    return await channel.invokeMethod<bool>(action.name, layout.toPlatform()) ??
        false;
  }

  @override
  Future<void> suspend() async {
    try {
      await _channel?.invokeMethod<void>('suspend');
    } catch (_) {
      /* The view may already be removed. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    final channel = _channel;
    _channel = null;
    channel?.setMethodCallHandler(null);
    if (channel != null) {
      unawaited(
        channel.invokeMethod<void>('dispose').catchError((Object _) {}),
      );
    }
  }
}
