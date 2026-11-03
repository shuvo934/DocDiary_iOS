import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/failure.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../dashboard/dashboard_navigation.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import 'accounts_dashboard_models.dart';
import 'accounts_dashboard_navigation.dart';
import 'accounts_dashboard_repository.dart';
import 'native_accounts_dashboard_layout.dart';
import 'voucher_transaction/voucher_transaction_screen.dart';
import 'voucher_transaction/voucher_repository.dart';
import 'voucher_approval/voucher_approval_models.dart';
import 'voucher_approval/voucher_approval_repository.dart';
import 'voucher_approval/voucher_approval_screen.dart';

class AccountsDashboardScreen extends StatefulWidget {
  const AccountsDashboardScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.destinationBuilder,
  });
  final AuthController auth;
  final AccountsDashboardRepository repository;
  final DashboardDestinationBuilder? destinationBuilder;
  @override
  State<AccountsDashboardScreen> createState() => _AccountsState();
}

class _AccountsState extends State<AccountsDashboardScreen>
    with WidgetsBindingObserver {
  late final AuthSession _session;
  final _scaffold = GlobalKey<ScaffoldState>();
  final _scroll = ScrollController();
  final _dialogs = NativeDashboardDialogOwner();
  AccountsDashboardData? _data;
  AccountsPeriod _period = AccountsPeriod.today;
  late AccountsRange _range;
  bool _invalid = false,
      _foreground = true,
      _busy = true,
      _childAway = false,
      _denied = false,
      _fromTab = false;
  String? _error;
  int _operation = 0;
  bool get _current =>
      mounted &&
      !_invalid &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;
  bool _alive(int op) => _current && _foreground && op == _operation;
  bool get _ready =>
      _current &&
      _foreground &&
      !_busy &&
      !_childAway &&
      !_denied &&
      _data != null &&
      !_dialogs.isOpen;
  @override
  void initState() {
    super.initState();
    _range = AccountsRange.forPeriod(_period, widget.repository.now());
    final session = widget.auth.session;
    if (session == null ||
        widget.auth.profile == null ||
        session.account.role != AccountRole.admin) {
      _invalid = true;
      _denied = true;
      _busy = false;
      return;
    }
    _session = session;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) unawaited(_load(reset: true));
    });
  }

  void _authChanged() {
    if (_current) return;
    ++_operation;
    _dialogs.close();
    _scaffold.currentState?.closeEndDrawer();
    if (mounted) {
      setState(() {
        _data = null;
        _busy = true;
        _error = null;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ([
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ].contains(state)) {
      _foreground = false;
      ++_operation;
      if (!_childAway) _dialogs.close();
      _scaffold.currentState?.closeEndDrawer();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && !_foreground) {
      _foreground = true;
      if (_current && !_childAway) unawaited(_load(reset: true));
    }
  }

  Future<AccountProfile> _fresh(int op) async {
    final profile = await widget.auth.profiles.open(
      _session,
      recordLogin: false,
      isCurrent: () => _alive(op),
    );
    widget.repository.guard(_session, profile, () => _alive(op));
    return profile;
  }

  Future<void> _load({bool reset = false}) async {
    if (!_current || !_foreground || _childAway || _dialogs.isOpen) return;
    final op = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
      _denied = false;
      _data = null;
      if (reset) {
        _period = AccountsPeriod.today;
        _fromTab = false;
        _range = AccountsRange.forPeriod(_period, widget.repository.now());
      }
    });
    try {
      final profile = await _fresh(op);
      final data = await widget.repository.load(
        _session,
        profile,
        _range,
        isCurrent: () => _alive(op),
      );
      if (!_alive(op)) return;
      setState(() {
        _data = data;
        _busy = false;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (failure) {
      if (!mounted || !_alive(op) || failure is ObsoleteRequest) return;
      await _failed(failure, op);
    }
  }

  Future<void> _failed(Object failure, int op) async {
    if (failure is AccountsModuleUnavailable) {
      setState(() {
        _denied = true;
        _busy = false;
        _data = null;
        _error = null;
      });
      return;
    }
    if (failure is AppFailure && failure.kind == FailureKind.denied) {
      widget.auth.blockAccess(
        failure is AccountAccessFailure
            ? failure
            : const AccountAccessFailure.mobileAccess(),
      );
      return;
    }
    setState(() {
      _busy = false;
      _data = null;
      _error = 'The Accounts Dashboard could not be loaded.';
    });
    final retry = await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: const Key('accounts_error'),
        title: Text('Error!', style: dashboardDialogText(20)),
        content: SingleChildScrollView(
          child: Text(
            dashboardErrorMessage(failure),
            style: dashboardDialogText(16),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('accounts_error_exit'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Exit'),
          ),
          TextButton(
            key: const Key('accounts_error_retry'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    if (!_alive(op)) return;
    if (retry == true) {
      await _load();
    } else {
      await _back();
    }
  }

  Future<void> _changePeriod(AccountsPeriod period) async {
    if (!_ready || _period == period) return;
    setState(() {
      _period = period;
      _fromTab = true;
      _range = AccountsRange.forPeriod(period, widget.repository.now());
    });
    await _load();
  }

  Future<void> _open(
    AccountsDestination destination, {
    bool chart = false,
  }) async {
    if (!_ready ||
        !accountsDestinations(_session.center.baseUri).contains(destination)) {
      return;
    }
    final op = ++_operation;
    setState(() => _busy = true);
    try {
      await _fresh(op);
      if (!mounted || !_alive(op)) return;
      setState(() => _busy = false);
      final route = destination.route(
        chartRange: chart && _fromTab ? _range : null,
        now: widget.repository.now(),
      );
      final page =
          widget.destinationBuilder?.call(context, route) ??
          (destination == AccountsDestination.voucherTransaction
              ? VoucherTransactionScreen(
                auth: widget.auth,
                repository: VoucherRepository(
                  widget.auth.profiles.transport,
                  now: widget.auth.profiles.now,
                ),
                firstDate: route.extras['FIRST_DATE'] ?? '',
                lastDate: route.extras['LAST_DATE'] ?? '',
              )
              : const [
                AccountsDestination.creditApproval,
                AccountsDestination.debitApproval,
                AccountsDestination.journalApproval,
              ].contains(destination)
              ? VoucherApprovalScreen(
                auth: widget.auth,
                repository: VoucherApprovalRepository(
                  widget.auth.profiles.transport,
                  now: widget.auth.profiles.now,
                ),
                kind: switch (destination) {
                  AccountsDestination.creditApproval =>
                    VoucherApprovalKind.credit,
                  AccountsDestination.debitApproval =>
                    VoucherApprovalKind.debit,
                  _ => VoucherApprovalKind.journal,
                },
              )
              : null);
      if (page == null) {
        await _dialogs.show<void>(
          context,
          AlertDialog(
            key: const Key('accounts_unavailable'),
            title: Text(destination.label, style: dashboardDialogText(20)),
            content: Text(
              'This feature is currently unavailable.',
              style: dashboardDialogText(16),
            ),
            actions: [
              TextButton(
                key: const Key('accounts_unavailable_close'),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        if (mounted) setState(() {});
        return;
      }
      _childAway = true;
      try {
        await _dialogs.push<void>(context, page);
      } finally {
        _childAway = false;
        if (_current && _foreground) await _load(reset: true);
      }
    } catch (failure) {
      if (!mounted || !_alive(op) || failure is ObsoleteRequest) return;
      await _failed(failure, op);
    }
  }

  Future<void> _back() async {
    if (!mounted || _busy || _dialogs.isOpen) return;
    if (_scaffold.currentState?.isEndDrawerOpen ?? false) {
      _scaffold.currentState?.closeEndDrawer();
      return;
    }
    await Navigator.maybePop(context);
  }

  @override
  void dispose() {
    ++_operation;
    if (!_invalid) {
      widget.auth.removeListener(_authChanged);
      WidgetsBinding.instance.removeObserver(this);
    }
    _dialogs.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: NativeAccountsDashboardLayout(
      scaffoldKey: _scaffold,
      scrollController: _scroll,
      onBack: () => unawaited(_back()),
      onDestination: (d) => unawaited(_open(d)),
      onVoucher:
          () => unawaited(
            _open(AccountsDestination.voucherTransaction, chart: true),
          ),
      onIncomeExpense:
          () =>
              unawaited(_open(AccountsDestination.incomeExpense, chart: true)),
      onPeriod: (p) => unawaited(_changePeriod(p)),
      onRetry: () => unawaited(_load()),
      period: _period,
      range: _range,
      data: _data,
      waiting: !_invalid && (!_current || !_foreground || _busy),
      enabled: _ready,
      centerApi: _invalid ? null : _session.center.baseUri,
      message:
          _denied
              ? 'Accounts Dashboard access is not available for this account.'
              : _error,
    ),
  );
}
