import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Owns native toast feedback for one screen, including its lifetime.
class AppToastOwner with WidgetsBindingObserver {
  AppToastOwner() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final _native = _NativeToastQueue();
  bool _disposed = false;

  void show(BuildContext context, String message) {
    if (_disposed || !context.mounted || message.trim().isEmpty) {
      return;
    }
    final route = ModalRoute.of(context);
    _native.show(this, message, () {
      final state = WidgetsBinding.instance.lifecycleState;
      return !_disposed &&
          (state == null || state == AppLifecycleState.resumed) &&
          (route?.isCurrent ?? true);
    });
  }

  void clear() => _native.clear(this);

  static void clearAll() => _native.clearAll();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      clear();
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    clear();
  }
}

/// Native toasts belong to the window, so clear them on route changes too.
class AppToastNavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      AppToastOwner.clearAll();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      AppToastOwner.clearAll();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      AppToastOwner.clearAll();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      AppToastOwner.clearAll();
}

class _NativeToastQueue {
  Future<void>? _pending;
  Object? _owner;
  int _revision = 0;

  Future<void> _enqueue(Future<void> Function() action) async {
    final previous = _pending;
    final finished = Completer<void>();
    final tail = finished.future;
    _pending = tail;
    try {
      if (previous != null) {
        await previous;
      }
      await action();
    } on PlatformException {
      // Feedback failure must not turn a successful save into an API retry.
    } on MissingPluginException {
      // A native plugin may be unavailable in a non-mobile test host.
    } finally {
      if (identical(_pending, tail)) {
        _pending = null;
      }
      finished.complete();
    }
  }

  void show(Object owner, String message, bool Function() current) {
    if (!current()) {
      return;
    }
    final revision = ++_revision;
    _owner = owner;
    unawaited(
      _enqueue(() async {
        if (revision != _revision || !current()) {
          return;
        }
        await Fluttertoast.cancel();
        if (revision != _revision || !current()) {
          return;
        }
        await Fluttertoast.showToast(
          msg: message,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 2,
          backgroundColor: const Color(0xcc000000),
          textColor: Colors.white,
          fontSize: 14,
        );
      }),
    );
  }

  void clear(Object owner) {
    if (identical(owner, _owner)) {
      clearAll();
    }
  }

  void clearAll() {
    if (_owner == null) {
      return;
    }
    ++_revision;
    _owner = null;
    unawaited(
      _enqueue(() async {
        await Fluttertoast.cancel();
      }),
    );
  }
}
