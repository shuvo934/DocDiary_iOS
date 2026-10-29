import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/failure.dart';
import '../../core/native_dates.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
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
  DateTime? _selected;
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
      _selected = null;
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
    setState(() => _selected = date);
    final navigator = Navigator.of(context);
    final route = ModalBottomSheetRoute<void>(
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
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
    final enabled = _current && _foreground && !_busy && _error == null;
    return PopScope(
      canPop: !_busy,
      child: NativePatientSearchShell(
        title: 'Appointment Calendar',
        onBack: _busy ? null : () => Navigator.pop(context),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: m.d(8)),
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
                  const Divider(
                    color: Colors.black54,
                    indent: 20,
                    endIndent: 20,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    key: const Key('patient_calendar_previous'),
                    tooltip: 'Previous month',
                    onPressed:
                        enabled && _month > 0
                            ? () => unawaited(
                              _page.previousPage(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                              ),
                            )
                            : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '${_months[month.month - 1]} ${month.year}',
                      key: const Key('patient_calendar_month'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 19,
                        color: DocColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('patient_calendar_next'),
                    tooltip: 'Next month',
                    onPressed:
                        enabled && _month < 3
                            ? () => unawaited(
                              _page.nextPage(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                              ),
                            )
                            : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                for (final day in [
                  'Sat',
                  'Sun',
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                ])
                  Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: DocColors.greenSea,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    key: const Key('patient_calendar_pages'),
                    controller: _page,
                    itemCount: 4,
                    physics:
                        enabled
                            ? const PageScrollPhysics()
                            : const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) => setState(() => _month = index),
                    itemBuilder:
                        (_, index) =>
                            _monthGrid(_window.monthAt(index), m, enabled),
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
          ],
        ),
      ),
    );
  }

  Widget _monthGrid(
    DateTime month,
    DynamicRxMetrics m,
    bool enabled,
  ) => LayoutBuilder(
    builder: (_, bounds) {
      final firstColumn = (month.weekday + 1) % 7;
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        physics: const ClampingScrollPhysics(),
        itemCount: 42,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisExtent: (bounds.maxHeight / 6).clamp(48, 100),
        ),
        itemBuilder: (_, index) {
          final day = DateTime(
                month.year,
                month.month,
                index - firstColumn + 1,
              ),
              current = day.month == month.month;
          final rows = _rows.where((row) => row.date == day);
          final marker = patientCalendarMarker(rows, widget.repository.now());
          final selected = _selected == day,
              today = day == dateOnly(widget.repository.now());
          return InkWell(
            key: Key(
              'patient_calendar_day_${month.month}_${day.year}_${day.month}_${day.day}',
            ),
            onTap:
                enabled && current && _window.contains(day)
                    ? () => unawaited(_day(day))
                    : null,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: selected ? DocColors.greenSea : null,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 15,
                        color:
                            !current
                                ? const Color(0xffdddddd)
                                : selected
                                ? DocColors.primary
                                : day.weekday == DateTime.friday
                                ? const Color(0xffc23616)
                                : marker.isNotEmpty
                                ? const Color(0xfffda000)
                                : today
                                ? DocColors.primary
                                : DocColors.muted,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 20,
                    child:
                        current && marker.isNotEmpty
                            ? Image.asset(
                              'assets/images/patient_calendar_$marker.png',
                              key: Key(
                                'patient_calendar_marker_${day.year}_${day.month}_${day.day}',
                              ),
                              width: 22,
                              height: 20,
                            )
                            : null,
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
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
    return Material(
      key: const Key('patient_calendar_day_sheet'),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              color: DocColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                patient.name,
                textAlign: TextAlign.center,
                style: m.text(16, color: Colors.white, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]}, ${date.year}',
              style: m.text(13, color: Colors.black, weight: FontWeight.w700),
            ),
            Text(
              _days[date.weekday - 1],
              style: m.text(13, color: Colors.black, weight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.all(m.d(5)),
                itemCount: rows.length,
                itemBuilder: (_, index) => _appointment(rows[index], index, m),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appointment(
    PatientCalendarAppointment row,
    int index,
    DynamicRxMetrics m,
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
    Widget line(String label, String value) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Text(
            label,
            style: m.text(
              10,
              color: DocColors.primary,
              weight: FontWeight.w600,
            ),
          ),
        ),
        Text(' : ', style: m.text(10, color: DocColors.primary)),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: m.text(10, color: Colors.black, weight: FontWeight.w500),
          ),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: m.d(10), horizontal: m.d(5)),
      child: Material(
        key: Key('patient_calendar_appointment_$index'),
        elevation: 1.5,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(m.d(8)),
          side: const BorderSide(color: DocColors.primary),
        ),
        child: Padding(
          padding: EdgeInsets.all(m.d(6)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '( ${row.value('ad_pat_app_status')} )'.toUpperCase(),
                  style: m.text(
                    9,
                    color: patientSearchText,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.value('schedule_time'),
                      style: m.text(
                        12,
                        color: DocColors.greenSea,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(m.d(4)),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(m.d(15)),
                    ),
                    child: Text(
                      status,
                      style: m.text(
                        7,
                        color: Colors.white,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '( ${row.value('ets')} )',
                style: m.text(9, color: patientSearchText, family: 'PatuaOne'),
              ),
              SizedBox(height: m.d(6)),
              line('Service', row.value('pfn_fee_name')),
              line('Doctor', row.value('doc_name')),
              for (final key in ['depts_name', 'deptd_name'])
                Padding(
                  padding: EdgeInsets.only(left: m.d(96)),
                  child: Text(
                    '( ${row.value(key)} )',
                    style: m.text(
                      9,
                      color: patientSearchText,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
