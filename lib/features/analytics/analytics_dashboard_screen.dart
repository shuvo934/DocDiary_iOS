import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/app_toast.dart';
import '../../core/failure.dart';
import '../../core/native_dates.dart';
import '../accounts/voucher_transaction/native_voucher_controls.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import 'analytics_models.dart';
import 'analytics_repository.dart';
import 'native_analytics_layout.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({
    super.key,
    required this.auth,
    required this.repository,
  });

  final AuthController auth;
  final AnalyticsRepository repository;

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboardScreen>
    with WidgetsBindingObserver {
  late final AuthSession? _session = widget.auth.session;
  late Map<AnalyticsSection, AnalyticsRange> _ranges;
  final _dialogs = NativeDashboardDialogOwner();
  final _toasts = AppToastOwner();
  final _scroll = ScrollController();
  final _failed = <AnalyticsSection>{};

  AnalyticsLogin? _mobile, _portal;
  AnalyticsAppointments? _appointments;
  AnalyticsPayments? _payments;
  AnalyticsCardSelection? _selection;
  List<AnalyticsReason> _reasons = const [];
  AnalyticsSection? _loadingSection;
  bool _loadingDetails = false;
  bool _busy = false;
  bool _foreground = true;
  bool _unavailable = false;
  String? _message;
  int _operation = 0;

  AnalyticsRepository get _repository => widget.repository;
  bool get _current =>
      mounted &&
      _session?.account.role == AccountRole.admin &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;
  bool _alive(int operation) =>
      _current && _foreground && operation == _operation;
  bool get _ready =>
      _current && _foreground && !_busy && !_dialogs.isOpen && !_unavailable;

  void _resetDates() {
    final today = AnalyticsRange.today(_repository.now());
    _ranges = {for (final section in AnalyticsSection.values) section: today};
  }

  @override
  void initState() {
    super.initState();
    _resetDates();
    _unavailable = !_current;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_ready) unawaited(_load());
    });
  }

  void _authChanged() {
    if (_current) return;
    ++_operation;
    _dialogs.close();
    _toasts.clear();
    if (mounted) {
      setState(() {
        _unavailable = true;
        _busy = false;
        _mobile = _portal = null;
        _appointments = null;
        _payments = null;
        _clearSelection();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (!_foreground) return;
      _foreground = false;
      ++_operation;
      _dialogs.close();
      _toasts.clear();
      setState(() {
        _mobile = _portal = null;
        _appointments = null;
        _payments = null;
        _busy = false;
        _clearSelection();
      });
    } else if (state == AppLifecycleState.resumed && !_foreground) {
      _foreground = true;
      _resetDates();
      if (_ready) unawaited(_load());
    }
  }

  void _clearSelection() {
    _selection = null;
    _reasons = const [];
  }

  Future<void> _perform(
    Future<void> Function(AccountProfile, bool Function()) read, {
    required Future<void> Function() retry,
    AnalyticsSection? section,
    bool details = false,
  }) async {
    if (!_ready) return;
    final operation = ++_operation;
    bool alive() => _alive(operation);
    setState(() {
      _busy = true;
      _loadingDetails = details;
      _loadingSection = section;
      _message = null;
      if (section == null && !details) _mobile = null;
    });
    try {
      final profile = await widget.auth.profiles.open(
        _session!,
        recordLogin: false,
        isCurrent: alive,
      );
      _repository.guard(_session, profile, alive);
      await read(profile, alive);
    } catch (error) {
      if (!mounted || !alive() || error is ObsoleteRequest) return;
      if (error is AppFailure && error.kind == FailureKind.denied) {
        widget.auth.blockAccess(
          error is AccountAccessFailure
              ? error
              : const AccountAccessFailure.mobileAccess(),
        );
        return;
      }
      if (error is AnalyticsUnavailable) {
        setState(() {
          _unavailable = true;
          _mobile = _portal = null;
          _appointments = null;
          _payments = null;
          _clearSelection();
        });
        return;
      }
      final initial = _mobile == null;
      setState(() {
        _busy = false;
        _loadingDetails = false;
        _loadingSection = null;
        if (section != null) _failed.add(section);
        if (details) _clearSelection();
        if (initial) _message = dashboardErrorMessage(error);
      });
      var answered = false;
      void answer(BuildContext dialogContext, bool value) {
        if (!answered && alive() && _dialogs.isOpen) {
          answered = true;
          Navigator.pop(dialogContext, value);
        }
      }

      final again = await _dialogs.show<bool>(
        context,
        Builder(
          builder:
              (dialogContext) => AlertDialog(
                key: const Key('analytics_error'),
                title: const Text('Error!'),
                content: SingleChildScrollView(
                  child: Text(dashboardErrorMessage(error)),
                ),
                actions: [
                  TextButton(
                    key: const Key('analytics_error_close'),
                    onPressed: () => answer(dialogContext, false),
                    child: Text(initial ? 'Exit' : 'Cancel'),
                  ),
                  TextButton(
                    key: const Key('analytics_error_retry'),
                    onPressed: () => answer(dialogContext, true),
                    child: const Text('Retry'),
                  ),
                ],
              ),
        ),
      );
      if (!mounted || !alive()) return;
      if (again == true) {
        await retry();
      } else if (initial) {
        await Navigator.maybePop(context);
      }
    } finally {
      if (alive()) {
        setState(() {
          _busy = false;
          _loadingDetails = false;
          _loadingSection = null;
        });
      }
    }
  }

  Future<void> _load([AnalyticsSection? section]) => _perform(
    (profile, alive) async {
      final portalEnabled = _repository.portalEnabled(profile);
      final all =
          section == null ||
          _mobile == null ||
          portalEnabled != (_portal != null);
      if (all && _mobile != null) {
        setState(() {
          _mobile = null;
          _loadingSection = null;
          _clearSelection();
        });
      }
      final session = _session!;
      var mobile = _mobile;
      var portal = _portal;
      var appointments = _appointments;
      var payments = _payments;
      if (all || section == AnalyticsSection.mobile) {
        mobile = await _repository.login(
          session,
          profile,
          _ranges[AnalyticsSection.mobile]!,
          portal: false,
          isCurrent: alive,
        );
      }
      if (portalEnabled) {
        if (all || section == AnalyticsSection.portal) {
          portal = await _repository.login(
            session,
            profile,
            _ranges[AnalyticsSection.portal]!,
            portal: true,
            isCurrent: alive,
          );
        }
        if (all || section == AnalyticsSection.appointments) {
          appointments = await _repository.appointments(
            session,
            profile,
            _ranges[AnalyticsSection.appointments]!,
            isCurrent: alive,
          );
        }
        if (all || section == AnalyticsSection.payments) {
          payments = await _repository.payments(
            session,
            profile,
            _ranges[AnalyticsSection.payments]!,
            isCurrent: alive,
          );
        }
      }
      if (!alive()) return;
      setState(() {
        _mobile = mobile;
        _portal = portalEnabled ? portal : null;
        _appointments = portalEnabled ? appointments : null;
        _payments = portalEnabled ? payments : null;
        if (all) {
          _failed.clear();
        } else {
          _failed.remove(section);
        }
        if (all || section == AnalyticsSection.payments) _clearSelection();
      });
    },
    section: section,
    retry: () => _load(section),
  );

  Future<void> _pick(AnalyticsSection section) async {
    if (!_ready) return;
    final operation = _operation;
    final range = _ranges[section]!;
    final today = dateOnly(_repository.now());
    final initial = range.allowed(today) ? range : AnalyticsRange.today(today);
    final theme = Theme.of(context);
    final picked = await _dialogs.push<DateTimeRange>(
      context,
      Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: DocColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
          textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
          datePickerTheme: theme.datePickerTheme.copyWith(
            rangePickerBackgroundColor: Colors.white,
            rangePickerHeaderBackgroundColor: DocColors.primary,
            rangePickerHeaderForegroundColor: Colors.white,
          ),
        ),
        child: DateRangePickerDialog(
          key: const Key('analytics_date_picker'),
          helpText: 'SELECT BEGIN & END DATE',
          saveText: 'SAVE',
          firstDate: DateTime(1900),
          lastDate: DateTime(2100, 12, 31),
          currentDate: today,
          initialDateRange: DateTimeRange(
            start: initial.first,
            end: initial.last,
          ),
          selectableDayPredicate: (day, _, __) => !day.isAfter(today),
        ),
      ),
    );
    if (!_alive(operation) || !_ready || picked == null) return;
    final next = AnalyticsRange(picked.start, picked.end);
    if (!next.allowed(_repository.now())) return;
    setState(() {
      _ranges[section] = next;
      if (section == AnalyticsSection.payments) _clearSelection();
    });
    await _load(section);
  }

  void _select(AnalyticsCardSelection? selection) {
    if (!_ready) return;
    if (selection == null ||
        selection == _selection ||
        selection.status == AnalyticsCardStatus.completed) {
      setState(_clearSelection);
      return;
    }
    if (_payments?.cards.contains(selection.card) != true ||
        selection.card.name.isEmpty ||
        selection.card.count(selection.status) <= 0) {
      return;
    }
    unawaited(_loadReasons(selection));
  }

  Future<void> _loadReasons(AnalyticsCardSelection selection) async {
    if (!_ready) return;
    setState(() {
      _selection = selection;
      _reasons = const [];
    });
    await _perform(
      (profile, alive) async {
        if (!_repository.portalEnabled(profile)) {
          setState(() {
            _portal = null;
            _appointments = null;
            _payments = null;
            _clearSelection();
          });
          return;
        }
        final reasons = await _repository.reasons(
          _session!,
          profile,
          _ranges[AnalyticsSection.payments]!,
          selection,
          isCurrent: alive,
        );
        if (!mounted || !alive()) return;
        setState(() => _reasons = reasons);
        if (reasons.isEmpty) {
          _toasts.show(context, 'No Data Found');
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (alive() && _scroll.hasClients) {
              unawaited(
                _scroll.animateTo(
                  _scroll.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                ),
              );
            }
          });
        }
      },
      details: true,
      retry: () => _loadReasons(selection),
    );
  }

  Widget _section(AnalyticsSection section, String title, Widget content) {
    final loading = _busy && _loadingSection == section;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnalyticsHeading(
          title,
          topPadding:
              section == AnalyticsSection.mobile ||
                      section == AnalyticsSection.portal
                  ? 5
                  : null,
        ),
        AnalyticsDateField(
          key: Key('analytics_range_${section.name}'),
          range: _ranges[section]!,
          onTap: _ready ? () => unawaited(_pick(section)) : null,
        ),
        if (loading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: CircularProgressIndicator(
                key: Key('analytics_loading_${section.name}'),
              ),
            ),
          )
        else if (_failed.contains(section))
          Center(
            child: IconButton(
              key: Key('analytics_refresh_${section.name}'),
              tooltip: 'Refresh $title',
              color: DocColors.primary,
              onPressed: _ready ? () => unawaited(_load(section)) : null,
              icon: const Icon(Icons.refresh),
            ),
          )
        else
          content,
      ],
    );
  }

  Widget _content(AnalyticsLogin mobile) => IgnorePointer(
    ignoring: _busy,
    child: SingleChildScrollView(
      key: const Key('analytics_scroll'),
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AnalyticsHeading('MOBILE APPS', main: true),
          _section(
            AnalyticsSection.mobile,
            'LOGIN STATUS',
            AnalyticsLoginContent(mobile),
          ),
          if (_portal case final portal?) ...[
            const SizedBox(height: 13),
            const AnalyticsHeading('ONLINE PATIENT PORTAL', main: true),
            _section(
              AnalyticsSection.portal,
              'LOGIN STATUS',
              AnalyticsLoginContent(portal),
            ),
          ],
          if (_appointments case final appointments?)
            _section(
              AnalyticsSection.appointments,
              'ONLINE APPOINTMENT STATUS',
              AnalyticsAppointmentContent(appointments),
            ),
          if (_payments case final payments?)
            _section(
              AnalyticsSection.payments,
              'ONLINE PAYMENT STATUS',
              AnalyticsPaymentContent(
                data: payments,
                selected: _selection,
                reasons: _reasons,
                loading: _loadingDetails,
                onSelect: _select,
              ),
            ),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    ++_operation;
    widget.auth.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    _dialogs.dispose();
    _toasts.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = _mobile;
    return NativeVoucherShell(
      title: 'Analytics Dashboard',
      backKey: 'analytics_back',
      onBack: _busy ? null : () => unawaited(Navigator.maybePop(context)),
      child:
          _unavailable
              ? const Center(
                child: Text(
                  'Analytics Dashboard is not available for this account.',
                ),
              )
              : mobile != null
              ? _content(mobile)
              : _message != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_message!, textAlign: TextAlign.center),
                ),
              )
              : const Center(
                child: CircularProgressIndicator(key: Key('analytics_loading')),
              ),
    );
  }
}
