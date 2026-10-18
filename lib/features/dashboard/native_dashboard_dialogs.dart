import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/failure.dart';
import 'native_dashboard_icons.dart';

enum DashboardErrorChoice { logOut, exit, retry }

String dashboardFailureDetail(Object failure) {
  final value = failure is AppFailure ? failure.message : failure.toString();
  final detail = value.trim();
  return detail.isEmpty || detail == 'null'
      ? 'Server problem or Internet not connected'
      : detail.replaceFirst(RegExp(r'\.+$'), '');
}

String dashboardErrorMessage(Object failure, {bool choices = false}) =>
    'Error Message: ${dashboardFailureDetail(failure)}.\nPlease try again.'
    '${choices ? '\nYou can exit from the app OR retry to connect into the server OR log out from this account.' : ''}';

TextStyle dashboardDialogText(
  double size, {
  Color color = Colors.black,
  FontWeight weight = FontWeight.normal,
  String family = 'Roboto',
}) => TextStyle(
  inherit: false,
  textBaseline: TextBaseline.alphabetic,
  fontFamily: family,
  fontSize: size,
  fontWeight: weight,
  color: color,
);

/// Own only this screen's routes, so logout/switch/disposal cannot leave an old
/// dialog above Login or run a stale Retry callback against another account.
class NativeDashboardDialogOwner {
  NavigatorState? _navigator;
  final _routes = <Route<dynamic>>{};
  bool _disposed = false;
  bool get isOpen => _routes.isNotEmpty;

  Future<T?> show<T>(
    BuildContext context,
    Widget child, {
    bool dismissible = false,
  }) async {
    if (_disposed || isOpen || !context.mounted) {
      return null;
    }
    final navigator = Navigator.of(context);
    _navigator = navigator;
    final route = DialogRoute<T>(
      context: context,
      barrierDismissible: dismissible,
      builder: (_) => PopScope(canPop: dismissible, child: child),
    );
    _routes.add(route);
    try {
      return await navigator.push(route);
    } finally {
      _routes.remove(route);
    }
  }

  Future<T?> push<T>(BuildContext context, Widget child) async {
    if (_disposed || isOpen || !context.mounted) {
      return null;
    }
    final navigator = Navigator.of(context);
    _navigator = navigator;
    final route = MaterialPageRoute<T>(builder: (_) => child);
    _routes.add(route);
    try {
      return await navigator.push(route);
    } finally {
      _routes.remove(route);
    }
  }

  void close() {
    final navigator = _navigator;
    final routes = _routes.toList();
    _routes.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator == null || !navigator.mounted) {
        return;
      }
      for (final route in routes) {
        if (route.isActive) {
          navigator.removeRoute(route);
        }
      }
    });
  }

  void dispose() {
    _disposed = true;
    close();
  }
}

class NativeDashboardMessageDialog extends StatelessWidget {
  const NativeDashboardMessageDialog({
    super.key,
    required this.title,
    required this.message,
    this.button = 'OK',
  });
  final String title, message, button;

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('dashboard_message_dialog'),
    title: Text(title, style: dashboardDialogText(20, weight: FontWeight.w500)),
    content: SingleChildScrollView(
      child: Text(message, style: dashboardDialogText(16)),
    ),
    actions: [
      TextButton(
        key: const Key('dashboard_message_ok'),
        onPressed: () => Navigator.pop(context, true),
        child: Text(
          button,
          style: dashboardDialogText(
            14,
            color: DocColors.primary,
            weight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

class NativeDashboardConfirmDialog extends StatelessWidget {
  const NativeDashboardConfirmDialog({
    super.key,
    required this.title,
    required this.message,
  });
  final String title, message;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title, style: dashboardDialogText(20, weight: FontWeight.w500)),
    content: Text(message, style: dashboardDialogText(16)),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(
          'No',
          style: dashboardDialogText(14, color: DocColors.primary),
        ),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(
          'Yes',
          style: dashboardDialogText(14, color: DocColors.primary),
        ),
      ),
    ],
  );
}

class NativeDashboardErrorDialog extends StatelessWidget {
  const NativeDashboardErrorDialog({super.key, required this.failure});
  final Object failure;

  Widget _button(
    BuildContext context,
    DashboardErrorChoice choice,
    double sdp,
  ) => SizedBox(
    height: 48,
    child: ElevatedButton(
      key: Key('dashboard_error_${choice.name}'),
      style: ElevatedButton.styleFrom(
        backgroundColor: DocColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        minimumSize: Size.zero,
        padding: EdgeInsets.symmetric(horizontal: 8 * sdp),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8 * sdp),
        ),
      ),
      onPressed: () => Navigator.pop(context, choice),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (choice == DashboardErrorChoice.logOut) ...[
              NativeDashboardIcon(
                NativeDashboardGlyph.logout,
                size: 13 * sdp,
                color: Colors.white,
              ),
              const SizedBox(width: 2),
            ],
            Text(
              switch (choice) {
                DashboardErrorChoice.logOut => 'LOG OUT',
                DashboardErrorChoice.exit => 'EXIT',
                DashboardErrorChoice.retry => 'RETRY',
              },
              style: dashboardDialogText(
                9 * sdp,
                family: 'Lato',
                color: Colors.white,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).shortestSide;
    final sdp = width < 300 ? 1.0 : (width / 30).floor() * 30 / 300;
    final stackButtons = MediaQuery.textScalerOf(context).scale(14) > 21;
    return Dialog(
      key: const Key('dashboard_error_dialog'),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width:
            math
                .min(MediaQuery.sizeOf(context).width * .95 - 32, 560)
                .toDouble(),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.all(10 * sdp),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/doc_diary_default.png',
                      width: 24,
                      height: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, right: 6),
                        child: Text(
                          'WARNING!',
                          style: dashboardDialogText(
                            13 * sdp,
                            family: 'Poppins',
                            color: DocColors.greenSea,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 1,
                child: ColoredBox(color: DocColors.primary),
              ),
              Padding(
                padding: EdgeInsets.all(8 * sdp),
                child: Text(
                  dashboardErrorMessage(failure, choices: true),
                  style: dashboardDialogText(
                    14,
                    family: 'Poppins',
                    color: const Color(0xFF6C6E6F),
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 12 * sdp, bottom: 4 * sdp),
                child:
                    stackButtons
                        ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final choice in DashboardErrorChoice.values)
                              Padding(
                                padding: EdgeInsets.all(8 * sdp),
                                child: _button(context, choice, sdp),
                              ),
                          ],
                        )
                        : Row(
                          children: [
                            for (final choice in DashboardErrorChoice.values)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.all(8 * sdp),
                                  child: _button(context, choice, sdp),
                                ),
                              ),
                          ],
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS has no supported API to close a root app programmatically. Retain the
/// native EXIT choice and session, and tell the user how to leave via iOS.
const nativeDashboardExitHelp = NativeDashboardMessageDialog(
  title: 'Exit!',
  message:
      'Use the Home gesture or Home button to leave DocDiary. '
      'Any saved sign-in will be kept.',
);
