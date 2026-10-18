import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/failure.dart';
import '../auth/auth_controller.dart';
import '../auth/account_access.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import 'admin_chart_models.dart';
import 'admin_chart_repository.dart';
import 'native_admin_line_chart.dart';
import 'native_chart_date_dialog.dart';
import 'native_chart_icons.dart';

TextStyle _font(
  double size, {
  Color color = Colors.black,
  FontWeight weight = FontWeight.normal,
  String family = 'Poppins',
}) => TextStyle(
  inherit: false,
  textBaseline: TextBaseline.alphabetic,
  fontFamily: family,
  fontSize: size,
  fontWeight: weight,
  color: color,
);

class NativeAdminOverview extends StatefulWidget {
  const NativeAdminOverview({
    super.key,
    required this.auth,
    required this.profile,
    required this.repository,
    required this.sdp,
    this.refreshRevision = 0,
    this.onDashboardFailure,
    this.onDashboardReady,
  });
  final AuthController auth;
  final AccountProfile profile;
  final AdminChartRepository repository;
  final double sdp;
  final int refreshRevision;
  final ValueChanged<Object>? onDashboardFailure;
  final VoidCallback? onDashboardReady;

  @override
  State<NativeAdminOverview> createState() => _NativeAdminOverviewState();
}

class _NativeAdminOverviewState extends State<NativeAdminOverview>
    with WidgetsBindingObserver {
  late final AuthSession _session;
  AdminChartMode _mode = AdminChartMode.monthly;
  AdminChartType _type = AdminChartType.all;
  final _selections = <AdminChartKind, AdminChartSelection>{};
  final _data = <AdminChartKind, AdminChartData?>{};
  final _loading = <AdminChartKind, bool>{};
  final _errors = <AdminChartKind, String?>{};
  final _requests = <AdminChartKind, int>{};
  bool _loadingAll = true, _foreground = true;
  String? _errorAll;
  int _batch = 0;
  DialogRoute<DateTime>? _dateRoute;
  DialogRoute<void>? _errorRoute;
  NavigatorState? _navigator;

  bool get _current =>
      mounted &&
      _foreground &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;

  @override
  void initState() {
    super.initState();
    _session = widget.auth.session!;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current) {
        unawaited(_loadBoth(reset: true));
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = Navigator.of(context);
  }

  @override
  void didUpdateWidget(covariant NativeAdminOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshRevision != widget.refreshRevision ||
        oldWidget.profile.adminFilter != widget.profile.adminFilter ||
        oldWidget.profile.value('all_access_flag') !=
            widget.profile.value('all_access_flag') ||
        oldWidget.profile.value('is_pay_appoint_type_active') !=
            widget.profile.value('is_pay_appoint_type_active')) {
      _closeRoutes();
      if (_current) {
        unawaited(_loadBoth(reset: true));
      }
    }
  }

  void _invalidate() {
    _batch++;
    for (final kind in AdminChartKind.values) {
      _requests[kind] = (_requests[kind] ?? 0) + 1;
    }
  }

  void _closeRoutes() {
    final navigator = _navigator;
    final routes = <Route<dynamic>?>[_dateRoute, _errorRoute];
    _dateRoute = null;
    _errorRoute = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator != null && navigator.mounted) {
        for (final route in routes) {
          if (route != null && route.isActive) {
            navigator.removeRoute(route);
          }
        }
      }
    });
  }

  void _authChanged() {
    if (!_current) {
      _invalidate();
      _closeRoutes();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _invalidate();
    }
    // DashboardScreen revalidates the account on resume, then advances
    // refreshRevision. This avoids starting duplicate chart reloads here.
  }

  String _message(Object failure) =>
      failure is AppFailure
          ? failure.message
          : 'Server problem or Internet not connected';

  Future<void> _failure(Object failure) async {
    if (!_current) {
      return;
    }
    if (failure is AppFailure && failure.kind == FailureKind.denied) {
      widget.auth.blockAccess(
        failure is AccountAccessFailure
            ? failure
            : AccountAccessFailure(
              AccountAccessReason.mobileAccess,
              failure.message,
            ),
      );
      return;
    }
    if (_errorRoute != null) {
      return;
    }
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(
                'Error!',
                style: chartRoboto(
                  20,
                  color: Colors.black,
                  weight: FontWeight.w500,
                ),
              ),
              content: Text(
                'Error Message: ${_message(failure)}.\nPlease try again.',
                style: chartRoboto(16, color: Colors.black),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK',
                    style: chartRoboto(
                      14,
                      color: DocColors.primary,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
    _errorRoute = route;
    await _navigator!.push(route);
    if (identical(_errorRoute, route)) {
      _errorRoute = null;
    }
  }

  Future<void> _loadBoth({bool reset = false, bool resetDates = false}) async {
    if (!_current || (_loadingAll && !reset && !resetDates)) {
      return;
    }
    _invalidate();
    final batch = _batch;
    setState(() {
      if (reset) {
        _mode = AdminChartMode.monthly;
        _type = AdminChartType.all;
      }
      if (reset || resetDates || _selections.isEmpty) {
        final clock = widget.repository.now();
        for (final kind in AdminChartKind.values) {
          _selections[kind] = AdminChartSelection(_mode, clock);
        }
      }
      _loadingAll = true;
      _errorAll = null;
      for (final kind in AdminChartKind.values) {
        _data[kind] = null;
        _loading[kind] = false;
        _errors[kind] = null;
      }
    });
    bool current() => _current && batch == _batch;
    var ready = false;
    try {
      final result = await widget.repository.loadBoth(
        _session,
        widget.profile,
        _type,
        _selections[AdminChartKind.payment]!,
        isCurrent: current,
      );
      if (!current()) {
        return;
      }
      setState(() {
        _data[AdminChartKind.payment] = result.payment;
        _data[AdminChartKind.appointment] = result.appointment;
      });
      ready = true;
    } catch (failure) {
      if (!current()) {
        return;
      }
      setState(() => _errorAll = _message(failure));
      if (reset && widget.onDashboardFailure != null) {
        widget.onDashboardFailure!(failure);
      } else {
        unawaited(_failure(failure));
      }
    } finally {
      if (current()) {
        setState(() => _loadingAll = false);
        if (ready && reset) {
          widget.onDashboardReady?.call();
        }
      }
    }
  }

  Future<void> _loadOne(AdminChartKind kind) async {
    if (!_current || _loadingAll || _loading[kind] == true) {
      return;
    }
    final batch = _batch;
    final request = (_requests[kind] ?? 0) + 1;
    _requests[kind] = request;
    bool current() => _current && batch == _batch && request == _requests[kind];
    setState(() {
      _loading[kind] = true;
      _errors[kind] = null;
      _data[kind] = null;
    });
    try {
      final result = await widget.repository.loadOne(
        _session,
        widget.profile,
        kind,
        _type,
        _selections[kind]!,
        isCurrent: current,
      );
      if (current()) {
        setState(() => _data[kind] = result);
      }
    } catch (failure) {
      if (current()) {
        setState(() => _errors[kind] = _message(failure));
        unawaited(_failure(failure));
      }
    } finally {
      if (current()) {
        setState(() => _loading[kind] = false);
      }
    }
  }

  Future<void> _pickDate(AdminChartKind kind) async {
    if (!_current ||
        _loadingAll ||
        _loading[kind] == true ||
        _dateRoute != null) {
      return;
    }
    final batch = _batch;
    final route = DialogRoute<DateTime>(
      context: context,
      builder:
          (context) => NativeChartDateDialog(
            selection: _selections[kind]!,
            now: widget.repository.now(),
          ),
    );
    _dateRoute = route;
    final date = await _navigator!.push(route);
    if (identical(_dateRoute, route)) {
      _dateRoute = null;
    }
    if (!_current || batch != _batch || date == null) {
      return;
    }
    _selections[kind] = AdminChartSelection(_mode, date);
    await _loadOne(kind);
  }

  void _chooseMode(AdminChartMode mode) {
    if (_loadingAll || mode == _mode) {
      return;
    }
    _mode = mode;
    unawaited(_loadBoth(resetDates: true));
  }

  void _chooseType(AdminChartType type) {
    if (_loadingAll || type == _type) {
      return;
    }
    _type = type;
    unawaited(_loadBoth(resetDates: true));
  }

  Widget _typeButtons() => Wrap(
    spacing: 5 * widget.sdp,
    runSpacing: 4,
    children: [
      for (final type in AdminChartType.values)
        Semantics(
          button: true,
          selected: type == _type,
          child: Material(
            color: type == _type ? DocColors.greenSea : const Color(0x1A50C2C0),
            borderRadius: BorderRadius.circular(9 * widget.sdp),
            child: InkWell(
              key: Key('admin_chart_type_${type.name}'),
              borderRadius: BorderRadius.circular(9 * widget.sdp),
              onTap: () => _chooseType(type),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  8 * widget.sdp,
                  widget.sdp,
                  8 * widget.sdp,
                  0,
                ),
                child: Text(
                  type.name[0].toUpperCase() + type.name.substring(1),
                  style: _font(
                    8 * widget.sdp,
                    weight: FontWeight.w600,
                    color: type == _type ? Colors.white : DocColors.greenSea,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _modeTabs() => Padding(
    padding: const EdgeInsets.fromLTRB(3, 7, 3, 0),
    child: Row(
      children: [
        for (final mode in AdminChartMode.values)
          Expanded(
            child: Semantics(
              button: true,
              selected: mode == _mode,
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient:
                        mode == _mode
                            ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [DocColors.primary, DocColors.greenSea],
                            )
                            : null,
                  ),
                  child: InkWell(
                    key: Key('admin_chart_mode_${mode.name}'),
                    borderRadius: BorderRadius.circular(40),
                    onTap: () => _chooseMode(mode),
                    child: Center(
                      child: Text(
                        mode.name.toUpperCase(),
                        style: _font(
                          11 * widget.sdp,
                          family: 'PatuaOne',
                          color: mode == _mode ? Colors.white : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _retry(String label, Key key, VoidCallback onTap) => Center(
    child: Semantics(
      label: label,
      button: true,
      child: InkResponse(
        key: key,
        onTap: onTap,
        child: NativeChartIcon(size: 32 * widget.sdp, refresh: true),
      ),
    ),
  );

  Widget _total(
    String label,
    String value,
    Color color,
    bool right,
  ) => Expanded(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: _font(7 * widget.sdp, color: color, weight: FontWeight.w600),
          ),
          const SizedBox(width: 5),
          Text(value, style: _font(8 * widget.sdp, weight: FontWeight.w600)),
        ],
      ),
    ),
  );

  Widget _card(AdminChartKind kind) {
    final payment = kind == AdminChartKind.payment;
    final title = payment ? 'Payment' : 'Appointment';
    final data = _data[kind];
    final loading = _loading[kind] == true;
    final error = _errors[kind];
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return Padding(
      padding: EdgeInsets.fromLTRB(3, 10 * widget.sdp, 3, 5),
      child: Material(
        key: Key('admin_chart_card_${kind.name}'),
        elevation: 2,
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 280 * widget.sdp + math.max(0.0, scale - 1) * 56,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 7, 0, 5),
                      child: Text(
                        title,
                        style: _font(
                          10 * widget.sdp,
                          color: DocColors.primary,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (!loading)
                    Expanded(
                      child: InkWell(
                        key: Key('admin_chart_date_${kind.name}'),
                        onTap: () => unawaited(_pickDate(kind)),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _selections[kind]!.label,
                                  style: _font(
                                    10 * widget.sdp,
                                    color: DocColors.primary,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                NativeChartIcon(size: 16 * widget.sdp),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child:
                    loading
                        ? Center(
                          child: CircularProgressIndicator(
                            key: Key('admin_chart_loading_${kind.name}'),
                            color: DocColors.primary,
                            strokeWidth: 4,
                          ),
                        )
                        : error != null
                        ? _retry(
                          'Retry $title chart',
                          Key('admin_chart_retry_${kind.name}'),
                          () => unawaited(_loadOne(kind)),
                        )
                        : data == null
                        ? const SizedBox.shrink()
                        : Padding(
                          padding: const EdgeInsets.fromLTRB(2, 0, 2, 5),
                          child: NativeAdminLineChart(
                            data: data,
                            mode: _mode,
                            sdp: widget.sdp,
                          ),
                        ),
              ),
              if (!loading && error == null && data != null) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 50 * widget.sdp),
                  child: const Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.black,
                  ),
                ),
                Padding(
                  key: Key('admin_chart_totals_${kind.name}'),
                  padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
                  child: Row(
                    children: [
                      _total(
                        payment ? 'Total Receive: ' : 'Total Appointment: ',
                        data.primaryTotal,
                        DocColors.greenSea,
                        false,
                      ),
                      SizedBox(width: 4 * widget.sdp),
                      _total(
                        payment ? 'Total Return: ' : 'Cancel Appointment: ',
                        data.secondaryTotal,
                        const Color(0xFFFDA000),
                        true,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showTypes =
        !_loadingAll &&
        _errorAll == null &&
        widget.profile.value('is_pay_appoint_type_active') == '1';
    final heading = Text(
      'OVERVIEW',
      style: _font(
        13 * widget.sdp,
        color: const Color(0xFFFDA000),
        weight: FontWeight.w700,
      ),
    );
    return Padding(
      key: const Key('admin_overview'),
      padding: const EdgeInsets.only(top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              5 * widget.sdp,
              10 * widget.sdp,
              5 * widget.sdp,
              0,
            ),
            child:
                MediaQuery.textScalerOf(context).scale(10) > 14
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        heading,
                        if (showTypes)
                          Align(
                            alignment: Alignment.centerRight,
                            child: _typeButtons(),
                          ),
                      ],
                    )
                    : Row(
                      children: [
                        Expanded(child: heading),
                        if (showTypes) _typeButtons(),
                      ],
                    ),
          ),
          if (_loadingAll)
            const Padding(
              padding: EdgeInsets.all(80),
              child: Center(
                child: CircularProgressIndicator(
                  key: Key('admin_chart_loading_all'),
                  color: DocColors.primary,
                  strokeWidth: 4,
                ),
              ),
            )
          else ...[
            _modeTabs(),
            if (_errorAll != null)
              Padding(
                padding: const EdgeInsets.all(80),
                child: _retry(
                  'Retry overview charts',
                  const Key('admin_chart_retry_all'),
                  () => unawaited(_loadBoth()),
                ),
              )
            else ...[
              for (final kind in AdminChartKind.values) _card(kind),
            ],
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _invalidate();
    _closeRoutes();
    widget.auth.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
