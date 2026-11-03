import 'package:flutter/material.dart';
import '../../core/app_toast.dart';

/// Feedback for a blocked system Back on an Accounts-owned loading dialog.
class AccountsLoadingBoundary extends StatefulWidget {
  const AccountsLoadingBoundary({
    super.key,
    required this.busy,
    required this.child,
  });
  final bool busy;
  final Widget child;
  @override
  State<AccountsLoadingBoundary> createState() => _LoadingBoundaryState();
}

class _LoadingBoundaryState extends State<AccountsLoadingBoundary> {
  final _toasts = AppToastOwner();
  @override
  void didUpdateWidget(covariant AccountsLoadingBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy && !widget.busy) _toasts.clear();
  }

  @override
  void dispose() {
    _toasts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.busy,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && widget.busy) {
        _toasts.show(context, 'Please wait while loading');
      }
    },
    child: widget.child,
  );
}
