import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_preview_platform.dart';
import 'package:flutter/material.dart';
import 'dynamic_review_test_support.dart';

JsonMap previewFixture([String name = 'complete']) =>
    jsonDecode(
          File('test/fixtures/dynamic_preview/$name.json').readAsStringSync(),
        )
        as JsonMap;

class DynamicPreviewHarness extends DynamicReviewHarness {
  DynamicPreviewHarness() {
    transport.onGet = respond;
  }
  JsonMap response = previewFixture();
  Completer<JsonMap>? pendingPreview;
  Future<JsonMap> respond(Uri uri) async {
    if (uri.path.endsWith('/getPreviewData')) {
      return pendingPreview?.future ?? response;
    }
    return respondAppointments(uri);
  }

  List<Uri> get previewReads =>
      transport.requests
          .where((row) => row.uri.path.endsWith('/getPreviewData'))
          .map((row) => row.uri)
          .toList();
}

class FakeDynamicPreviewPlatform implements DynamicPreviewPlatform {
  bool autoReady = true, disposed = false;
  int suspends = 0;
  String html = '';
  VoidCallback? ready;
  ValueChanged<String>? fail;
  final actions = <DynamicPreviewAction>[];
  Completer<bool>? pending;
  Object? actionError;
  @override
  Widget buildView({
    required String html,
    required String documentName,
    required VoidCallback onReady,
    required ValueChanged<String> onError,
  }) {
    this.html = html;
    ready = onReady;
    fail = onError;
    return _FakePreviewSurface(owner: this, onReady: onReady);
  }

  @override
  Future<bool> perform(DynamicPreviewAction action) async {
    actions.add(action);
    if (actionError != null) throw actionError!;
    return pending?.future ?? false;
  }

  @override
  Future<void> suspend() async {
    suspends++;
  }

  @override
  void dispose() {
    disposed = true;
  }
}

class _FakePreviewSurface extends StatefulWidget {
  const _FakePreviewSurface({required this.owner, required this.onReady});
  final FakeDynamicPreviewPlatform owner;
  final VoidCallback onReady;
  @override
  State<_FakePreviewSurface> createState() => _FakePreviewSurfaceState();
}

class _FakePreviewSurfaceState extends State<_FakePreviewSurface> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.owner.autoReady) widget.onReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    const path = String.fromEnvironment('DYNAMIC_PREVIEW_HTML_PNG');
    return path.isEmpty
        ? const ColoredBox(
          key: Key('fake_preview_html'),
          color: Colors.white,
          child: Center(child: Text('Offline HTML surface')),
        )
        : Align(
          alignment: Alignment.topCenter,
          child: Image.file(File(path), fit: BoxFit.fitWidth),
        );
  }
}
