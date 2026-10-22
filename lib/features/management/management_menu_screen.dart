import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/failure.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../dashboard/dashboard_navigation.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import '../hr/hr_dashboard_repository.dart';
import '../hr/hr_dashboard_screen.dart';
import '../reports/native_report_manager_layout.dart';
import '../reports/report_manager_menu.dart';
import 'management_access.dart';
import 'native_management_portal_layout.dart';

enum ManagementEntry { portal, reports }

/// Owns role-aware menus; destination modules remain independently replaceable.
class ManagementMenuScreen extends StatefulWidget {
  const ManagementMenuScreen({
    super.key,
    required this.auth,
    required this.entry,
    this.destinationBuilder,
  });
  final AuthController auth;
  final ManagementEntry entry;
  final DashboardDestinationBuilder? destinationBuilder;

  @override
  State<ManagementMenuScreen> createState() => _ManagementMenuScreenState();
}

class _ManagementMenuScreenState extends State<ManagementMenuScreen>
    with WidgetsBindingObserver {
  late final AuthSession _session;
  AccountProfile? _profile;
  Object? _failure;
  final _dialogs = NativeDashboardDialogOwner();
  bool _invalid = false,
      _loading = true,
      _foreground = true,
      _childAway = false;
  int _operation = 0;

  bool get _current =>
      mounted &&
      !_invalid &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;
  bool _alive(int operation) =>
      _current && _foreground && operation == _operation;
  ManagementAccess? get _access =>
      _profile == null ? null : ManagementAccess(_profile!);
  bool get _allowed =>
      _access != null &&
      (!_profile!.isDoctor ||
          widget.entry == ManagementEntry.reports && _access!.canOpenReports);
  bool get _reports =>
      widget.entry == ManagementEntry.reports ||
      !(_access?.usesPortal ?? false);
  bool get _ready =>
      _current &&
      _foreground &&
      !_loading &&
      _failure == null &&
      _allowed &&
      !_dialogs.isOpen;

  @override
  void initState() {
    super.initState();
    final session = widget.auth.session;
    if (session == null || widget.auth.profile == null) {
      _invalid = true;
      _loading = false;
      return;
    }
    _session = session;
    _profile = widget.auth.profile;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) unawaited(_load());
    });
  }

  void _authChanged() {
    if (!_current) {
      ++_operation;
      _dialogs.close();
      if (mounted) {
        setState(() {
          _profile = null;
          _loading = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      _foreground = false;
      ++_operation;
      if (!_childAway) _dialogs.close();
      if (mounted) setState(() {});
    } else if (!_foreground) {
      _foreground = true;
      if (_current && !_childAway) unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (!_current || !_foreground || _childAway) return;
    final operation = ++_operation;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final profile = await widget.auth.profiles.open(
        _session,
        recordLogin: false,
        isCurrent: () => _alive(operation),
      );
      final returnedId = profile.value(
        profile.isDoctor ? 'doc_code' : 'usr_id',
      );
      if ((returnedId.isNotEmpty && returnedId != _session.account.identity) ||
          (profile.isDoctor &&
              widget.auth.profile?.doctorId != profile.doctorId)) {
        throw const AppFailure(
          'The server returned information for a different account. Please try again.',
          kind: FailureKind.invalidData,
        );
      }
      if (!_alive(operation)) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (failure) {
      if (!mounted || !_alive(operation) || failure is ObsoleteRequest) return;
      if (failure is AppFailure && failure.kind == FailureKind.denied) {
        widget.auth.blockAccess(
          failure is AccountAccessFailure
              ? failure
              : const AccountAccessFailure.mobileAccess(),
        );
        return;
      }
      setState(() {
        _failure = failure;
        _loading = false;
      });
      final retry = await _dialogs.show<bool>(
        context,
        AlertDialog(
          key: const Key('management_error'),
          title: Text(
            'Error!',
            style: dashboardDialogText(20, weight: FontWeight.w500),
          ),
          content: SingleChildScrollView(
            child: Text(
              dashboardErrorMessage(failure),
              style: dashboardDialogText(16),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('management_error_exit'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Exit'),
            ),
            TextButton(
              key: const Key('management_error_retry'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
      if (!_alive(operation)) return;
      if (retry == true) {
        await _load();
      } else {
        await _back();
      }
    }
  }

  Future<void> _back() async {
    if (mounted && !_loading && !_dialogs.isOpen) {
      await Navigator.maybePop(context);
    }
  }

  Future<void> _open(ManagementDestination destination) async {
    if (!_ready || _reports || !_access!.allows(destination)) return;
    final module = switch (destination) {
      ManagementDestination.humanResources => DashboardModule.humanResources,
      ManagementDestination.accounts => DashboardModule.accounts,
      ManagementDestination.analytics => DashboardModule.analytics,
      ManagementDestination.reports => DashboardModule.reports,
    };
    final page =
        widget.destinationBuilder?.call(context, DashboardRoute(module)) ??
        (destination == ManagementDestination.humanResources
            ? HrDashboardScreen(
              auth: widget.auth,
              repository: HrDashboardRepository(
                widget.auth.profiles.transport,
                now: widget.auth.profiles.now,
              ),
              destinationBuilder: widget.destinationBuilder,
            )
            : destination == ManagementDestination.reports
            ? ManagementMenuScreen(
              auth: widget.auth,
              entry: ManagementEntry.reports,
              destinationBuilder: widget.destinationBuilder,
            )
            : null);
    await _openPage(page, destination.label);
  }

  Future<void> _report(ReportManagerItem item) async {
    if (!_ready ||
        !_reports ||
        !_access!.canOpenReports ||
        !nativeReportManagerItems(_session.center.baseUri).contains(item)) {
      return;
    }
    final page = widget.destinationBuilder?.call(
      context,
      DashboardRoute(
        DashboardModule.reportParameters,
        extras: {'R_TYPE': item.nativeType},
      ),
    );
    await _openPage(page, item.title);
  }

  Future<void> _openPage(Widget? page, String label) async {
    if (!_ready) return;
    if (page == null) {
      await _dialogs.show<void>(
        context,
        AlertDialog(
          key: const Key('management_unavailable'),
          title: Text(label),
          content: const Text('This feature is currently unavailable.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
        dismissible: true,
      );
      return;
    }
    _childAway = true;
    try {
      await _dialogs.push<void>(context, page);
    } finally {
      _childAway = false;
      if (_current && _foreground) await _load();
    }
  }

  @override
  void dispose() {
    ++_operation;
    if (!_invalid) {
      WidgetsBinding.instance.removeObserver(this);
      widget.auth.removeListener(_authChanged);
    }
    _dialogs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = !_invalid && (!_current || !_foreground || _loading);
    final title =
        widget.entry == ManagementEntry.reports
            ? 'Report Manager'
            : _access?.title ?? 'Management Portal';
    return PopScope(
      canPop: !_loading,
      child:
          !waiting && _failure == null && _allowed && _reports
              ? NativeReportManagerLayout(
                centerApi: _session.center.baseUri,
                onBack: () => unawaited(_back()),
                onReport: (item) => unawaited(_report(item)),
              )
              : NativeManagementPortalLayout(
                title: title,
                destinations:
                    !waiting && _failure == null && _allowed
                        ? _access!.destinations
                        : const [],
                loading: waiting,
                message:
                    !waiting && _failure == null && !_allowed
                        ? 'Access is not available for this account.'
                        : null,
                onBack: () => unawaited(_back()),
                onDestination: (destination) => unawaited(_open(destination)),
              ),
    );
  }
}
