import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_store_update.dart';

enum AppUpdateStage {
  checking,
  ready,
  required,
  openingStore,
  failed,
  cancelled,
}

class AppUpdateController extends ChangeNotifier {
  AppUpdateController({
    required this.checker,
    this.enabled = true,
    Future<bool> Function(Uri)? openStore,
    this.checkTimeout = const Duration(seconds: 6),
  }) : openStore = openStore ?? _openStore;
  final AppUpdateChecker checker;
  final Future<bool> Function(Uri) openStore;
  final bool enabled;
  final Duration checkTimeout;
  AppUpdateStage stage = AppUpdateStage.checking;
  AppUpdateOffer? offer;
  Object? checkFailure;
  bool _disposed = false;
  bool _storeRequested = false;
  bool _leftForStore = false;
  int _operation = 0;
  int revision = 0;

  bool get allowsStartup => stage == AppUpdateStage.ready;
  bool _current(int operation) => !_disposed && operation == _operation;

  static Future<bool> _openStore(Uri uri) async =>
      await launchUrl(uri, mode: LaunchMode.externalApplication);

  void _state(AppUpdateStage next) {
    if (_disposed) {
      return;
    }
    stage = next;
    revision++;
    notifyListeners();
  }

  Future<void> check({bool returningFromStore = false}) async {
    if (_disposed) {
      return;
    }
    final operation = ++_operation;
    _storeRequested = false;
    _leftForStore = false;
    _state(AppUpdateStage.checking);
    if (!enabled) {
      _state(AppUpdateStage.ready);
      return;
    }
    try {
      final available = await checker.check().timeout(checkTimeout);
      if (!_current(operation)) {
        return;
      }
      offer = available;
      checkFailure = null;
      _state(
        available == null
            ? AppUpdateStage.ready
            : returningFromStore
            ? AppUpdateStage.failed
            : AppUpdateStage.required,
      );
    } catch (failure) {
      if (!_current(operation)) {
        return;
      }
      checkFailure = failure;
      // MainActivity's initial onFailure proceeds; once an update is confirmed,
      // a failed return/Retry check cannot silently dismiss the known gate.
      _state(offer == null ? AppUpdateStage.ready : AppUpdateStage.failed);
    }
  }

  Future<void> update() async {
    if (_disposed || stage != AppUpdateStage.required || offer == null) {
      return;
    }
    final operation = ++_operation;
    _storeRequested = true;
    _leftForStore = false;
    _state(AppUpdateStage.openingStore);
    try {
      final opened = await openStore(
        offer!.storeUrl,
      ).timeout(const Duration(seconds: 10));
      if (!_current(operation)) {
        return;
      }
      if (!opened) {
        _storeRequested = false;
        _state(AppUpdateStage.failed);
      } else if (!_leftForStore) {
        // Some launchers return before iOS deactivates. Keep the prompt visible
        // and keep the return observer armed; opening the store is not success.
        _state(AppUpdateStage.required);
      }
    } catch (failure) {
      if (_current(operation)) {
        checkFailure = failure;
        _storeRequested = false;
        _state(AppUpdateStage.failed);
      }
    }
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || !_storeRequested) {
      return;
    }
    if (state != AppLifecycleState.resumed) {
      _leftForStore = true;
    } else if (_leftForStore) {
      unawaited(check(returningFromStore: true));
    }
  }

  void cancelUpdate() {
    if (stage == AppUpdateStage.required) {
      _storeRequested = false;
      _state(AppUpdateStage.failed);
    }
  }

  void cancelFailure() {
    if (stage == AppUpdateStage.failed) {
      _storeRequested = false;
      _state(AppUpdateStage.cancelled);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_operation;
    super.dispose();
  }
}
