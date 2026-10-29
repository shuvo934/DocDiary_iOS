import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/failure.dart';
import '../../core/native_dates.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../block_time/doctor_block_time_models.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import '../dynamic_prescription/native_dynamic_rx_controls.dart';
import 'native_patient_search_layout.dart';
import 'patient_search_models.dart';
import 'patient_search_repository.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _days = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// PatAppointmentCalendar + PatientAppSchAdapter. This patient view has no write
/// controls and uses the native four-month window and status drawable assets.
class PatientAppointmentCalendarScreen extends StatefulWidget {
  const PatientAppointmentCalendarScreen({
    super.key,
    required this.auth,
    required this.repository,
    required this.patient,
  });
  final AuthController auth;
  final PatientSearchRepository repository;
  final PatientSearchRow patient;
  @override
  State<PatientAppointmentCalendarScreen> createState() => _CalendarState();
}

class _CalendarState extends State<PatientAppointmentCalendarScreen>
    with WidgetsBindingObserver {
  late final AuthSession? _session = widget.auth.session;
  final _dialogs = NativeDashboardDialogOwner();
  final _page = PageController(initialPage: 1);
  late PatientAppointmentWindow _window = PatientAppointmentWindow(
    widget.repository.now(),
  );
  int _month = 1, _operation = 0;
  bool _busy = true, _foreground = true;
  String? _error;
  List<PatientCalendarAppointment> _rows = const [];
  ModalBottomSheetRoute<void>? _sheet;
  NavigatorState? _navigator;
  bool get _current =>
      mounted &&
      _session != null &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;
  bool _alive(int op) => _current && _foreground && op == _operation;
  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) unawaited(_load());
    });
  }

  void _closeSheet() {
    final route = _sheet, navigator = _navigator;
    _sheet = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator != null &&
          navigator.mounted &&
          route != null &&
          route.isActive) {
        navigator.removeRoute(route);
      }
    });
  }

  void _authChanged() {
    if (_current) return;
    ++_operation;
    _closeSheet();
    _dialogs.close();
    if (mounted) {
      setState(() {
        _rows = const [];
        _busy = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      ++_operation;
      _closeSheet();
      _dialogs.close();
    } else if (state == AppLifecycleState.resumed && !_foreground) {
      _foreground = true;
      if (_current) unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (!_current || !_foreground) return;
    final op = ++_operation,
        window = PatientAppointmentWindow(widget.repository.now());
    final moved = window.first != _window.first;
    setState(() {
      _busy = true;
      _error = null;
      _rows = const [];
      _window = window;
    });
    try {
      final profile = await widget.auth.profiles.open(
        _session!,
        recordLogin: false,
        isCurrent: () => _alive(op),
      );
      final rows = await widget.repository.calendar(
        _session,
        profile,
        widget.patient,
        window,
        isCurrent: () => _alive(op),
      );
      if (!_alive(op)) return;
      setState(() {
        _rows = rows;
        _busy = false;
        if (moved) _month = 1;
      });
      if (moved && _page.hasClients) _page.jumpToPage(1);
    } catch (failure) {
      if (!_alive(op) || failure is ObsoleteRequest) return;
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
        _error = dashboardErrorMessage(failure);
      });
      if (!mounted) return;
      final retry = await _dialogs.show<bool>(
        context,
        AlertDialog(
          key: const Key('patient_calendar_error'),
          title: const Text('Error!'),
          content: Text(_error!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('EXIT'),
            ),
            TextButton(
              key: const Key('patient_calendar_retry'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('RETRY'),
            ),
          ],
        ),
      );
      if (!_alive(op)) return;
      if (retry == true) {
        await _load();
      } else if (retry == false && mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _day(DateTime date) async {
    if (!_current ||
        !_foreground ||
        _busy ||
        _error != null ||
        _dialogs.isOpen ||
        _sheet != null ||
        !_window.contains(date)) {
      return;
    }
    final rows = _rows.where((row) => dateOnly(row.date) == date).toList();
    if (rows.isEmpty) return;
    final navigator = Navigator.of(context);
    final route = ModalBottomSheetRoute<void>(
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      modalBarrierColor: Colors.black54,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      builder:
          (_) => _PatientAppointmentDaySheet(
            patient: widget.patient,
            date: date,
            rows: rows,
            now: widget.repository.now(),
          ),
    );
    _sheet = route;
    _navigator = navigator;
    await navigator.push(route);
    if (_sheet == route) _sheet = null;
  }

  @override
  void dispose() {
    ++_operation;
    widget.auth.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    _closeSheet();
    _dialogs.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context), month = _window.monthAt(_month);
    final media = MediaQuery.of(context);
    // Same geometry as the accepted Block Schedule/Doc Leave calendar.
    final labelHeight = math.max(30.0, media.textScaler.scale(14) * 1.35 + 4);
    final rowHeight = labelHeight + 28.5;
    final enabled = _current && _foreground && !_busy && _error == null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: !_busy,
        child: NativePatientSearchShell(
          title: 'Appointment Calendar',
          onBack: _busy ? null : () => Navigator.pop(context),
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  key: const Key('patient_calendar_scroll'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(m.d(8), 9, m.d(8), 0),
                        child: Column(
                          children: [
                            Text(
                              widget.patient.name,
                              textAlign: TextAlign.center,
                              style: m.text(
                                13,
                                color: Colors.black,
                                weight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              widget.patient.code,
                              style: m.text(10, color: patientSearchText),
                            ),
                            SizedBox(height: m.d(4)),
                            const SizedBox(
                              height: 21,
                              child: Center(
                                child: FractionallySizedBox(
                                  widthFactor: .7,
                                  child: SizedBox(
                                    height: 1.5,
                                    child: CustomPaint(
                                      painter: _PatientCalendarSeparator(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Row(
                          children: [
                            _monthButton(false, enabled),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  '${_months[month.month - 1]} ${month.year}',
                                  key: const Key('patient_calendar_month'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 18,
                                    height: 1.3,
                                    color: DocColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            _monthButton(true, enabled),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: math.max(
                          40.0,
                          media.textScaler.scale(14) * 1.4 + 12,
                        ),
                        child: Row(
                          children: [
                            for (final day in const [6, 7, 1, 2, 3, 4, 5])
                              Expanded(
                                child: Center(
                                  child: Semantics(
                                    label: _days[day - 1],
                                    excludeSemantics: true,
                                    child: Text(
                                      const [
                                        'M',
                                        'T',
                                        'W',
                                        'T',
                                        'F',
                                        'S',
                                        'S',
                                      ][day - 1],
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14,
                                        color: DocColors.greenSea,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 6 * rowHeight,
                        child: PageView.builder(
                          key: const Key('patient_calendar_pages'),
                          controller: _page,
                          itemCount: 4,
                          physics:
                              enabled
                                  ? const ClampingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                          onPageChanged:
                              (index) => setState(() => _month = index),
                          itemBuilder:
                              (_, index) => _monthGrid(
                                _window.monthAt(index),
                                labelHeight,
                                enabled,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0xccffffff),
                    child: Center(
                      child: CircularProgressIndicator(
                        key: Key('patient_calendar_loading'),
                      ),
                    ),
                  ),
                ),
              if (_error != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.white,
                    child: Center(
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthButton(bool next, bool enabled) => SizedBox(
    width: 85,
    height: 56,
    child: IconButton(
      key: Key(next ? 'patient_calendar_next' : 'patient_calendar_previous'),
      tooltip: next ? 'Next month' : 'Previous month',
      onPressed:
          enabled && (next ? _month < 3 : _month > 0)
              ? () => unawaited(
                _page.animateToPage(
                  _month + (next ? 1 : -1),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                ),
              )
              : null,
      // Exact native library defaults, also used by the accepted Block calendar.
      color: Colors.white,
      disabledColor: Colors.white,
      icon: Icon(next ? Icons.chevron_right : Icons.chevron_left, size: 24),
    ),
  );

  Widget _monthGrid(DateTime month, double labelHeight, bool enabled) {
    final cells = blockTimeMonthCells(month);
    return Column(
      children: [
        for (var week = 0; week < 6; week++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: _dateCell(
                    cells[week * 7 + col],
                    month,
                    labelHeight,
                    enabled,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _dateCell(
    DateTime day,
    DateTime month,
    double labelHeight,
    bool enabled,
  ) {
    final current = day.month == month.month && _window.contains(day);
    final rows = _rows.where((row) => row.date == day);
    final marker = patientCalendarMarker(rows, widget.repository.now());
    final today = day == dateOnly(widget.repository.now());
    final color =
        !current
            ? const Color(0x1f000000)
            : today
            ? DocColors.primary
            : day.weekday == DateTime.friday
            ? const Color(0xffc23616)
            : marker.isNotEmpty
            ? const Color(0xfffda000)
            : DocColors.muted;
    return Semantics(
      label:
          '${blockTimeDateLabel(day)}, ${_days[day.weekday - 1]}${marker.isEmpty ? '' : ', appointments available'}',
      button: current && marker.isNotEmpty,
      enabled: enabled && current && marker.isNotEmpty,
      excludeSemantics: true,
      child: InkWell(
        key: Key(
          'patient_calendar_day_${month.month}_${day.year}_${day.month}_${day.day}',
        ),
        onTap:
            enabled && current && marker.isNotEmpty
                ? () => unawaited(_day(day))
                : null,
        child: Column(
          children: [
            const SizedBox(height: 4),
            SizedBox(
              height: labelHeight,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${day.day}',
                      key: Key(
                        'patient_calendar_label_${month.month}_${day.year}_${day.month}_${day.day}',
                      ),
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 20,
              child:
                  marker.isEmpty
                      ? null
                      : Opacity(
                        opacity: current ? 1 : .12,
                        child: Image.asset(
                          'assets/images/patient_calendar_$marker.png',
                          key: Key(
                            'patient_calendar_marker_${day.year}_${day.month}_${day.day}',
                          ),
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                        ),
                      ),
            ),
            const SizedBox(height: 2),
            const SizedBox(
              height: .5,
              child: ColoredBox(
                color: Color(0x1f000000),
                child: SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientCalendarSeparator extends CustomPainter {
  const _PatientCalendarSeparator();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = patientSearchText;
    for (double x = 0; x < size.width; x += 4) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, math.min(3, size.width - x), size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PatientCalendarSeparator old) => false;
}

class _PatientAppointmentDaySheet extends StatelessWidget {
  const _PatientAppointmentDaySheet({
    required this.patient,
    required this.date,
    required this.rows,
    required this.now,
  });
  final PatientSearchRow patient;
  final DateTime date, now;
  final List<PatientCalendarAppointment> rows;
  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context);
    // The accepted Doc Leave sheet's bounded, single-scroll structure also
    // keeps the header and all records reachable on short/large-text displays.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Material(
          key: const Key('patient_calendar_day_sheet'),
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              key: const Key('patient_calendar_day_scroll'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ColoredBox(
                    color: DocColors.primary,
                    child: Padding(
                      key: const Key('patient_calendar_sheet_header'),
                      padding: const EdgeInsets.all(7),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          patient.name,
                          textAlign: TextAlign.center,
                          style: m.text(
                            16,
                            color: Colors.white,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(7, 7, 7, 0),
                    child: Text(
                      blockTimeDateLabel(date),
                      textAlign: TextAlign.center,
                      style: m.text(
                        13,
                        color: Colors.black,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(7, 0, 7, 7),
                    child: Text(
                      _days[date.weekday - 1],
                      textAlign: TextAlign.center,
                      style: m.text(
                        13,
                        color: Colors.black,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(m.d(5)),
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length; i++)
                          _appointment(rows[i], i, m, context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _appointment(
    PatientCalendarAppointment row,
    int index,
    DynamicRxMetrics m,
    BuildContext context,
  ) {
    final state = row.status(now);
    final status = switch (state) {
      PatientAppointmentStatus.completed => 'Completed',
      PatientAppointmentStatus.canceled => 'Canceled',
      PatientAppointmentStatus.upcoming => 'Upcoming',
    };
    final color = switch (state) {
      PatientAppointmentStatus.completed => DocColors.greenSea,
      PatientAppointmentStatus.canceled => const Color(0xffc23616),
      PatientAppointmentStatus.upcoming => patientSearchText,
    };
    final visit = Text(
      '( ${row.value('ad_pat_app_status')} )'.toUpperCase(),
      key: Key('patient_calendar_visit_type_$index'),
      style: m.text(9, color: patientSearchText, weight: FontWeight.w500),
    );
    final badge = Material(
      key: Key('patient_calendar_status_$index'),
      elevation: 1.5,
      color: color,
      borderRadius: BorderRadius.circular(m.d(15)),
      child: Padding(
        padding: EdgeInsets.all(m.d(4)),
        child: Text(
          status,
          style: m.text(7, color: Colors.white, weight: FontWeight.w500),
        ),
      ),
    );
    final schedule = Padding(
      padding: EdgeInsets.fromLTRB(m.d(3), m.d(3), m.d(3), m.d(6)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            row.value('schedule_time'),
            key: Key('patient_calendar_schedule_time_$index'),
            textAlign: TextAlign.center,
            style: m.text(
              12,
              color: DocColors.greenSea,
              weight: FontWeight.w700,
            ),
          ),
          Text(
            '( ${row.value('ets')} )',
            key: Key('patient_calendar_schedule_type_$index'),
            textAlign: TextAlign.center,
            style: m.text(9, color: patientSearchText, family: 'PatuaOne'),
          ),
        ],
      ),
    );
    Widget line(String label, Widget value, {bool center = false}) => Padding(
      padding: EdgeInsets.all(m.d(2)),
      child: Row(
        crossAxisAlignment:
            center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Text(
              label,
              style: m.text(
                10,
                color: DocColors.primary,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              ' : ',
              style: m.text(
                10,
                color: DocColors.primary,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(flex: 13, child: value),
        ],
      ),
    );
    final large = MediaQuery.textScalerOf(context).scale(14) > 21;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: m.d(10), horizontal: m.d(5)),
      child: Material(
        key: Key('patient_calendar_appointment_$index'),
        elevation: 1.5,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(m.d(8)),
          side: const BorderSide(color: DocColors.muted, width: 2),
        ),
        child: Padding(
          padding: EdgeInsets.all(m.d(5)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (large)
                Column(
                  children: [
                    schedule,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [visit, badge],
                    ),
                  ],
                )
              else
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(child: schedule),
                    Positioned(
                      left: m.d(3),
                      top: 0,
                      bottom: 0,
                      child: Center(child: visit),
                    ),
                    Positioned(
                      right: m.d(3),
                      top: 0,
                      bottom: 0,
                      child: Center(child: badge),
                    ),
                  ],
                ),
              line(
                'Service',
                Text(
                  row.value('pfn_fee_name'),
                  key: Key('patient_calendar_service_$index'),
                  style: m.text(
                    10,
                    color: Colors.black,
                    weight: FontWeight.w500,
                  ),
                ),
                center: true,
              ),
              line(
                'Doctor',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      row.value('doc_name'),
                      key: Key('patient_calendar_doctor_$index'),
                      style: m.text(
                        10,
                        color: Colors.black,
                        weight: FontWeight.w500,
                      ),
                    ),
                    for (final key in ['depts_name', 'deptd_name'])
                      Text(
                        '( ${row.value(key)} )',
                        key: Key('patient_calendar_${key}_$index'),
                        style: m.text(
                          9,
                          color: patientSearchText,
                          weight: FontWeight.w500,
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
