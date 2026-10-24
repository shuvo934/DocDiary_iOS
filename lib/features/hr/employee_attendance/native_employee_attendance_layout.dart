import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';
import '../native_attendance_filter_style.dart';
import 'employee_attendance_models.dart';
import 'native_employee_attendance_chart.dart';

TextStyle _text(
  double size, {
  String family = 'Poppins',
  FontWeight weight = FontWeight.w700,
  Color color = Colors.black,
}) => TextStyle(
  fontFamily: family,
  fontFamilyFallback: const ['DocDiaryBengali'],
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1.5,
);

Color employeeAttendanceStatusColor(EmployeeAttendanceRowKind kind) =>
    switch (kind) {
      EmployeeAttendanceRowKind.multiStation => const Color(0xffc0c000),
      EmployeeAttendanceRowKind.outMiss => const Color(0xff00c080),
      EmployeeAttendanceRowKind.leave => const Color(0xff8f8f8f),
      EmployeeAttendanceRowKind.offDay => const Color(0xff7fdffe),
      EmployeeAttendanceRowKind.presentLeave => const Color(0xff4080c0),
      EmployeeAttendanceRowKind.presentOffDay => const Color(0xffe0c080),
      EmployeeAttendanceRowKind.absent => const Color(0xffc000ff),
      EmployeeAttendanceRowKind.normal => Colors.white,
    };
Color employeeAttendanceStatusTextColor(EmployeeAttendanceRowKind kind) =>
    switch (kind) {
      EmployeeAttendanceRowKind.outMiss ||
      EmployeeAttendanceRowKind.leave ||
      EmployeeAttendanceRowKind.presentLeave ||
      EmployeeAttendanceRowKind.absent => Colors.white,
      _ => Colors.black,
    };

class NativeEmployeeAttendanceLayout extends StatelessWidget {
  const NativeEmployeeAttendanceLayout({
    super.key,
    required this.month,
    required this.onBack,
    required this.onBranch,
    required this.onDivision,
    required this.onDepartment,
    required this.onDesignation,
    required this.onEmployee,
    required this.onMonth,
    this.catalog,
    this.report,
    this.waiting = false,
    this.enabled = true,
    this.message,
  });
  final EmployeeAttendanceMonth month;
  final EmployeeAttendanceCatalog? catalog;
  final EmployeeAttendanceReport? report;
  final VoidCallback onBack, onMonth;
  final ValueChanged<EmployeeAttendanceChoice> onBranch,
      onDivision,
      onDepartment,
      onDesignation;
  final ValueChanged<EmployeeAttendanceEmployee> onEmployee;
  final bool waiting, enabled;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context),
        width = MediaQuery.sizeOf(context).shortestSide;
    final sdp = width < 300 ? 1.0 : (width / 30).floor() * 30 / 300;
    final active = enabled && !waiting && message == null, data = catalog;
    Widget field(
      String name,
      List<EmployeeAttendanceChoice> choices,
      EmployeeAttendanceChoice? selected,
      bool allowed,
      ValueChanged<EmployeeAttendanceChoice> changed,
    ) => _EmployeeField(
      name: name,
      choices: choices,
      selected: selected?.name ?? '',
      enabled: active && allowed,
      changed: changed,
      sdp: sdp,
    );
    final controls = ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8 * sdp, 9 * sdp, 8 * sdp, 6 * sdp),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: field(
                    'Division',
                    data?.divisions ?? [],
                    data?.division,
                    data != null,
                    onDivision,
                  ),
                ),
                SizedBox(width: 8 * sdp),
                Expanded(
                  child: field(
                    'Department',
                    data?.departments ?? [],
                    data?.department,
                    data?.division != null,
                    onDepartment,
                  ),
                ),
              ],
            ),
            SizedBox(height: 7 * sdp),
            Row(
              children: [
                Expanded(
                  child: field(
                    'Designation',
                    data?.designations ?? [],
                    data?.designation,
                    data?.department != null,
                    onDesignation,
                  ),
                ),
                SizedBox(width: 8 * sdp),
                Expanded(
                  child: field(
                    'Employee',
                    data?.employees ?? [],
                    data?.employee,
                    data?.designation != null,
                    (value) {
                      if (value is EmployeeAttendanceEmployee) {
                        onEmployee(value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final pinned =
        media.size.height - media.padding.vertical > 520 &&
        media.textScaler.scale(14) <= 21;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: DocColors.primary,
        body: Column(
          children: [
            ColoredBox(
              color: DocColors.primary,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 11 * sdp,
                    vertical: 5 * sdp,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('employee_attendance_back'),
                        tooltip: 'Back',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 44,
                        ),
                        onPressed: waiting ? null : onBack,
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          size: 19 * sdp,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12 * sdp),
                      Expanded(
                        child: Text(
                          'Emp Wise Attendance',
                          key: const Key('employee_attendance_title'),
                          style: _text(13 * sdp, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: math.max(75, width * .28),
                        ),
                        child: _EmployeeMenu(
                          name: 'branch',
                          choices: data?.branches ?? [],
                          enabled:
                              active && (data?.branches.isNotEmpty ?? false),
                          changed: onBranch,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/hospital_icon.png',
                                  width: 16 * sdp,
                                  height: 18 * sdp,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4 * sdp),
                                Flexible(
                                  child: Text(
                                    data?.branch.name ?? 'None',
                                    style: _text(
                                      8 * sdp,
                                      family: 'Archivo',
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Material(
                key: const Key('employee_content_card'),
                color: Colors.white,
                elevation: 3,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                clipBehavior: Clip.antiAlias,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Stack(
                      children: [
                        if (!waiting)
                          CustomScrollView(
                            key: const Key('employee_attendance_scroll'),
                            slivers: [
                              if (pinned)
                                PinnedHeaderSliver(child: controls)
                              else
                                SliverToBoxAdapter(child: controls),
                              if (message != null)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Text(
                                      message!,
                                      textAlign: TextAlign.center,
                                      style: _text(14, weight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                              if (message == null &&
                                  data?.employee != null &&
                                  report != null) ...[
                                SliverToBoxAdapter(
                                  child: _EmployeeHeader(
                                    employee: data!.employee!,
                                    sdp: sdp,
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: Card(
                                    key: const Key('employee_chart_card'),
                                    margin: EdgeInsets.fromLTRB(
                                      3,
                                      10 * sdp,
                                      3,
                                      5,
                                    ),
                                    elevation: 2,
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        8 * sdp,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              key: const Key('employee_month'),
                                              onPressed:
                                                  active ? onMonth : null,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      month.label,
                                                      style: _text(
                                                        10 * sdp,
                                                        weight: FontWeight.w600,
                                                        color:
                                                            DocColors.primary,
                                                      ),
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.arrow_drop_down,
                                                    size: 16 * sdp,
                                                    color: DocColors.primary,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          NativeEmployeeAttendanceChart(
                                            attendance: report!.chart,
                                            sdp: sdp,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: _EmployeeReport(
                                    report: report!,
                                    sdp: sdp,
                                  ),
                                ),
                              ],
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 10),
                              ),
                            ],
                          ),
                        if (waiting)
                          const Positioned.fill(
                            child: ColoredBox(
                              color: Colors.white,
                              child: Center(
                                child: CircularProgressIndicator(
                                  key: Key('employee_loading'),
                                  color: DocColors.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeHeader extends StatelessWidget {
  const _EmployeeHeader({required this.employee, required this.sdp});
  final EmployeeAttendanceEmployee employee;
  final double sdp;
  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('employee_identity'),
    padding: EdgeInsets.fromLTRB(6 * sdp, 4 * sdp, 6 * sdp, 0),
    child: Column(
      children: [
        Text(
          employee.name,
          textAlign: TextAlign.center,
          style: _text(11 * sdp, color: DocColors.greenSea),
        ),
        Text(
          '(${employee.code})',
          textAlign: TextAlign.center,
          style: _text(
            9 * sdp,
            weight: FontWeight.w600,
            color: const Color(0xff6c6e6f),
          ),
        ),
        Text(
          employee.title,
          textAlign: TextAlign.center,
          style: _text(10 * sdp, color: const Color(0xff6c6e6f)),
        ),
        Text(
          employee.branchName,
          textAlign: TextAlign.center,
          style: _text(10 * sdp, color: const Color(0xff6c6e6f)),
        ),
      ],
    ),
  );
}

class _EmployeeField extends StatelessWidget {
  const _EmployeeField({
    required this.name,
    required this.choices,
    required this.selected,
    required this.enabled,
    required this.changed,
    required this.sdp,
  });
  final String name, selected;
  final List<EmployeeAttendanceChoice> choices;
  final bool enabled;
  final ValueChanged<EmployeeAttendanceChoice> changed;
  final double sdp;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 1,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: _EmployeeMenu(
      name: name.toLowerCase(),
      choices: choices,
      enabled: enabled && choices.isNotEmpty,
      changed: changed,
      child: InputDecorator(
        isEmpty: selected.isEmpty,
        decoration: nativeAttendanceFilterDecoration(
          label: name,
          enabled: enabled,
          sdp: sdp,
        ),
        child: Text(
          selected,
          style: _text(9 * sdp, family: 'OpenSans', weight: FontWeight.w400),
        ),
      ),
    ),
  );
}

/// Own this module's menus as well as its dialogs during logout/background/disposal.
class _EmployeeMenu extends StatefulWidget {
  const _EmployeeMenu({
    required this.name,
    required this.choices,
    required this.enabled,
    required this.changed,
    required this.child,
  });
  final String name;
  final List<EmployeeAttendanceChoice> choices;
  final bool enabled;
  final ValueChanged<EmployeeAttendanceChoice> changed;
  final Widget child;
  @override
  State<_EmployeeMenu> createState() => _EmployeeMenuState();
}

class _EmployeeMenuState extends State<_EmployeeMenu> {
  ModalRoute<Object?>? _route;
  NavigatorState? _navigator;
  void _close() {
    final route = _route, navigator = _navigator;
    _route = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route != null &&
          route.isActive &&
          navigator != null &&
          navigator.mounted) {
        navigator.removeRoute(route);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _EmployeeMenu old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) _close();
  }

  @override
  Widget build(BuildContext context) =>
      PopupMenuButton<EmployeeAttendanceChoice>(
        key: Key('employee_${widget.name}'),
        enabled: widget.enabled,
        tooltip: 'Select ${widget.name}',
        padding: EdgeInsets.zero,
        onSelected: (value) {
          _route = null;
          if (mounted && widget.enabled) widget.changed(value);
        },
        onCanceled: () => _route = null,
        itemBuilder:
            (_) => [
              for (var i = 0; i < widget.choices.length; i++)
                PopupMenuItem(
                  value: widget.choices[i],
                  key: Key('employee_${widget.name}_option_$i'),
                  child: Builder(
                    builder: (context) {
                      _route = ModalRoute.of(context);
                      _navigator = Navigator.of(context);
                      if (!mounted || !widget.enabled) _close();
                      return Text(
                        widget.choices[i].name,
                        style: _text(
                          12,
                          family: 'OpenSans',
                          weight: FontWeight.w400,
                        ),
                      );
                    },
                  ),
                ),
            ],
        child: widget.child,
      );
  @override
  void dispose() {
    _close();
    super.dispose();
  }
}

class _EmployeeReport extends StatelessWidget {
  const _EmployeeReport({required this.report, required this.sdp});
  final EmployeeAttendanceReport report;
  final double sdp;
  static const headings = [
    'Date',
    'Status',
    'Shift',
    'Punch Location',
    'In Time',
    'Out Time',
  ];
  TableRow _row(
    List<String> values, {
    EmployeeAttendanceRow? row,
    bool header = false,
  }) => TableRow(
    children: [
      for (var i = 0; i < values.length; i++)
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color:
                  header
                      ? DocColors.primary
                      : i == 1 && row != null
                      ? employeeAttendanceStatusColor(row.kind)
                      : values[i] == headings[i]
                      ? const Color(0xffced6e0)
                      : Colors.white,
              border: Border(
                right:
                    i < 5
                        ? BorderSide(
                          color: header ? Colors.white : Colors.black,
                          width: 1,
                        )
                        : BorderSide.none,
                bottom: BorderSide(
                  color: header ? Colors.black : Color(0xffced6e0),
                  width: 1,
                ),
              ),
            ),
            child: Text(
              values[i],
              textAlign: TextAlign.center,
              style: _text(
                (header ? 8 : 7) * sdp,
                color:
                    header
                        ? Colors.white
                        : i == 1 && row != null
                        ? employeeAttendanceStatusTextColor(row.kind)
                        : i == 4 && row != null
                        ? Colors.black
                        : i == 5 && row != null
                        ? Colors.black
                        : Colors.black54,
              ),
            ),
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.fromLTRB(3, 4 * sdp, 3, 8 * sdp),
    elevation: 2,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8 * sdp)),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4 * sdp),
            child: Text(
              'Attendance Report',
              style: _text(
                12 * sdp,
                family: 'Archivo',
                weight: FontWeight.w700,
                color: const Color(0xffcf6a87),
              ),
            ),
          ),
          Divider(color: Colors.black54, thickness: 2),
          Padding(
            padding: EdgeInsets.only(bottom: 4 * sdp),
            child: Text(
              report.month.rangeLabel,
              key: const Key('employee_range'),
              textAlign: TextAlign.center,
              style: _text(
                11 * sdp,
                weight: FontWeight.bold,
                color: DocColors.primary,
              ),
            ),
          ),
          if (report.rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No Data Found',
                key: const Key('employee_no_data'),
                style: _text(
                  12 * sdp,
                  weight: FontWeight.w600,
                  color: const Color(0xff6c6e6f),
                ),
              ),
            )
          else
            Table(
              key: const Key('employee_report_table'),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FlexColumnWidth(21),
                1: FlexColumnWidth(17),
                2: FlexColumnWidth(17),
                3: FlexColumnWidth(20),
                4: FlexColumnWidth(20),
                5: FlexColumnWidth(20),
              },
              children: [
                _row(headings, header: true),
                for (final row in report.rows)
                  _row([
                    row.date,
                    row.statusLabel,
                    row.shift,
                    row.location,
                    row.inTime,
                    row.outTime,
                  ], row: row),
              ],
            ),
          const SizedBox(height: 4),
          Divider(color: Colors.black54, thickness: 4),
          const SizedBox(height: 4),
          _summary(),
        ],
      ),
    ),
  );
  Widget _summary() {
    final s = report.summary, v = s.values;
    final cells = [
      [
        'Calender Days',
        '${report.month.days}',
        'Total Working Days',
        s.workingDays,
      ],
      ['Present Days', v[0], 'Absent Days', v[1]],
      ['Weekend', v[2], 'Work on Weekend', v[3]],
      ['Holidays', v[4], 'Work on Holidays', v[5]],
      ['Leave Days', v[6], 'Work on Leave Days', v[7]],
    ];
    return Table(
      key: const Key('employee_summary'),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FlexColumnWidth(4),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(4),
        3: FlexColumnWidth(1),
      },
      border: TableBorder.all(color: Colors.black54, width: 1),
      children: [
        for (final row in cells)
          TableRow(
            children: [
              for (var i = 0; i < row.length; i++)
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: Text(
                    row[i],
                    textAlign: i.isOdd ? TextAlign.center : TextAlign.left,
                    style: _text(
                      9 * sdp,
                      weight: i.isOdd ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
