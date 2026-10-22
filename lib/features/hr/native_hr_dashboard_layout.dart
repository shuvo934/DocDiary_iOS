import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import 'hr_dashboard_models.dart';
import 'hr_dashboard_navigation.dart';
import 'native_hr_attendance_chart.dart';
import 'native_hr_movement_icon.dart';

TextStyle hrText(
  double size, {
  String family = 'Poppins',
  FontWeight weight = FontWeight.normal,
  Color color = Colors.black,
}) => TextStyle(
  fontFamily: family,
  fontFamilyFallback: const ['DocDiaryBengali'],
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1.5,
);

class NativeHrDashboardLayout extends StatelessWidget {
  const NativeHrDashboardLayout({
    super.key,
    required this.scaffoldKey,
    required this.onBack,
    required this.onDestination,
    required this.onAttendancePeriod,
    required this.onLeavePeriod,
    required this.onPayrollMonth,
    required this.onRetry,
    required this.attendancePeriod,
    required this.leavePeriod,
    required this.attendanceRange,
    required this.leaveRange,
    required this.payrollMonth,
    required this.failures,
    this.counts,
    this.attendance,
    this.leave,
    this.payroll,
    this.busy,
    this.waiting = false,
    this.message,
    this.enabled = true,
    this.valueFontSize = 12,
  });
  final GlobalKey<ScaffoldState> scaffoldKey;
  final VoidCallback onBack, onPayrollMonth;
  final ValueChanged<HrDestination> onDestination;
  final ValueChanged<HrAttendancePeriod> onAttendancePeriod;
  final ValueChanged<HrLeavePeriod> onLeavePeriod;
  final ValueChanged<HrSection> onRetry;
  final HrAttendancePeriod attendancePeriod;
  final HrLeavePeriod leavePeriod;
  final HrDateRange attendanceRange, leaveRange;
  final HrPayrollMonth payrollMonth;
  final HrCounts? counts;
  final HrAttendance? attendance;
  final HrWeeklyLeave? leave;
  final HrPayroll? payroll;
  final HrSection? busy;
  final Set<HrSection> failures;
  final bool waiting, enabled;
  final String? message;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.shortestSide;
    final sdp = width < 300 ? 1.0 : (width / 30).floor() * 30 / 300;
    final interactive = enabled && !waiting && busy == null && message == null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: scaffoldKey,
        endDrawerEnableOpenDragGesture: interactive,
        backgroundColor: DocColors.primary,
        endDrawer: Drawer(
          backgroundColor: DocColors.primary,
          width: math.min(320, media.size.width * .86),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                ColoredBox(
                  color: DocColors.primary,
                  child: Padding(
                    padding: EdgeInsets.all(12 * sdp),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Image.asset(
                            'assets/images/hr_icon.png',
                            width: 20 * sdp,
                            height: 20 * sdp,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12 * sdp),
                        Expanded(
                          child: Text(
                            'HR Menu',
                            style: hrText(
                              14 * sdp,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('hr_drawer_close'),
                          tooltip: 'Close menu',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minHeight: 44,
                            minWidth: 36,
                          ),
                          color: Colors.white,
                          onPressed:
                              () => scaffoldKey.currentState?.closeEndDrawer(),
                          icon: const Icon(Icons.keyboard_double_arrow_right),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    color: Colors.white,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        for (final item in HrDestination.values)
                          ListTile(
                            key: Key('hr_menu_${item.name}'),
                            enabled: interactive,
                            leading: Image.asset(
                              'assets/images/${item.artwork}',
                              width: 24,
                              height: 24,
                              color: DocColors.greenSea,
                            ),
                            title: Text(
                              item.label,
                              style: hrText(
                                10 * sdp,
                                weight: FontWeight.w600,
                                color: const Color(0xff6c6e6f),
                              ),
                            ),
                            onTap:
                                interactive
                                    ? () {
                                      scaffoldKey.currentState
                                          ?.closeEndDrawer();
                                      onDestination(item);
                                    }
                                    : null,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20 * sdp,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 19 * sdp,
                        child: IconButton(
                          key: const Key('hr_back'),
                          tooltip: 'Back',
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: EdgeInsets.zero,
                          onPressed: waiting || busy != null ? null : onBack,
                          color: Colors.white,
                          disabledColor: Colors.white,
                          icon: Icon(Icons.arrow_back_ios, size: 19 * sdp),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'HR Dashboard',
                          key: const Key('hr_title'),
                          style: hrText(
                            14 * sdp,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 19 * sdp,
                        child: IconButton(
                          key: const Key('hr_menu'),
                          tooltip: 'HR Menu',
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: EdgeInsets.zero,
                          onPressed:
                              interactive
                                  ? () =>
                                      scaffoldKey.currentState?.openEndDrawer()
                                  : null,
                          color: Colors.white,
                          disabledColor: Colors.white,
                          icon: Icon(Icons.menu, size: 19 * sdp),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  child: ColoredBox(
                    color: Colors.white,
                    child: SafeArea(
                      top: false,
                      child:
                          waiting
                              ? const Center(
                                child: CircularProgressIndicator(
                                  key: Key('hr_loading'),
                                  color: DocColors.primary,
                                ),
                              )
                              : message != null
                              ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    message!,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                              : AbsorbPointer(
                                absorbing: !interactive,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: SingleChildScrollView(
                                    key: const Key('hr_scroll'),
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.only(
                                            top: 5 * sdp,
                                          ),
                                          child: IntrinsicHeight(
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Expanded(
                                                  child: _count(
                                                    'DEPARTMENTS',
                                                    counts?.departments ?? '0',
                                                    sdp,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: _count(
                                                    'EMPLOYEES',
                                                    counts?.employees ?? '0',
                                                    sdp,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        _section(
                                          HrSection.attendance,
                                          'ATTENDANCE',
                                          sdp,
                                          Column(
                                            children: [
                                              _tabs(
                                                HrAttendancePeriod.values
                                                    .map((e) => e.label)
                                                    .toList(),
                                                attendancePeriod.index,
                                                (index) => onAttendancePeriod(
                                                  HrAttendancePeriod
                                                      .values[index],
                                                ),
                                                'hr_att',
                                                sdp,
                                              ),
                                              _range(
                                                attendanceRange.label,
                                                sdp,
                                              ),
                                              Padding(
                                                padding: EdgeInsets.fromLTRB(
                                                  3,
                                                  10 * sdp,
                                                  3,
                                                  5,
                                                ),
                                                child: Card(
                                                  margin: EdgeInsets.zero,
                                                  elevation: 2,
                                                  color: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                      minHeight: 200 * sdp,
                                                    ),
                                                    child: Padding(
                                                      padding: EdgeInsets.all(
                                                        4 * sdp,
                                                      ),
                                                      child:
                                                          attendance == null
                                                              ? const SizedBox.shrink()
                                                              : NativeHrAttendanceChart(
                                                                attendance:
                                                                    attendance!,
                                                                valueFontSize:
                                                                    valueFontSize,
                                                                onOpenAttendance:
                                                                    () => onDestination(
                                                                      HrDestination
                                                                          .dailyAttendance,
                                                                    ),
                                                              ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _section(
                                          HrSection.leave,
                                          'LEAVE',
                                          sdp,
                                          Column(
                                            children: [
                                              _tabs(
                                                HrLeavePeriod.values
                                                    .map((e) => e.label)
                                                    .toList(),
                                                leavePeriod.index,
                                                (index) => onLeavePeriod(
                                                  HrLeavePeriod.values[index],
                                                ),
                                                'hr_leave',
                                                sdp,
                                              ),
                                              _range(leaveRange.label, sdp),
                                              _leaveTable(context, sdp),
                                            ],
                                          ),
                                        ),
                                        _section(
                                          HrSection.payroll,
                                          '',
                                          sdp,
                                          _payroll(sdp),
                                        ),
                                        const SizedBox(height: 10),
                                      ],
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
        ),
      ),
    );
  }

  Widget _count(String label, String value, double sdp) => Padding(
    padding: const EdgeInsets.all(5),
    child: Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8 * sdp),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: .5,
                child: Image.asset(
                  'assets/images/background_png_dot.png',
                  fit: BoxFit.fill,
                  color: DocColors.clouds,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
            Container(
              width: double.infinity,
              constraints: BoxConstraints(minHeight: 75 * sdp),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8 * sdp),
                border: Border.all(color: DocColors.greenSea),
              ),
              padding: const EdgeInsets.all(7),
              child: Column(
                children: [
                  SizedBox(height: 5 * sdp),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: hrText(10 * sdp, weight: FontWeight.w700),
                  ),
                  Text(
                    value,
                    textAlign: TextAlign.center,
                    style: hrText(
                      25 * sdp,
                      family: 'Baloo',
                      color: DocColors.greenSea,
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

  Widget _section(HrSection section, String title, double sdp, Widget child) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 10 * sdp, left: 5 * sdp),
                child: Text(
                  title,
                  style: hrText(
                    13 * sdp,
                    weight: FontWeight.w700,
                    color: const Color(0xfffda000),
                  ),
                ),
              ),
            if (busy == section)
              SizedBox(
                height: 180 * sdp,
                child: Center(
                  child: CircularProgressIndicator(
                    key: Key('hr_${section.name}_loading'),
                    color: DocColors.primary,
                  ),
                ),
              )
            else if (failures.contains(section))
              SizedBox(
                height: 180 * sdp,
                child: Center(
                  child: IconButton(
                    key: Key('hr_${section.name}_refresh'),
                    tooltip: 'Refresh ${section.name}',
                    iconSize: 32 * sdp,
                    color: DocColors.greenSea,
                    onPressed: () => onRetry(section),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              )
            else
              child,
          ],
        ),
      );

  Widget _tabs(
    List<String> labels,
    int selected,
    ValueChanged<int> changed,
    String prefix,
    double sdp,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(3, 7, 3, 0),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient:
                      index == selected
                          ? const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [DocColors.greenSea, DocColors.primary],
                          )
                          : null,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(40),
                  child: InkWell(
                    key: Key('${prefix}_$index'),
                    borderRadius: BorderRadius.circular(40),
                    onTap: () => changed(index),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 8,
                          ),
                          child: Text(
                            labels[index],
                            textAlign: TextAlign.center,
                            style: hrText(
                              9 * sdp,
                              family: 'PatuaOne',
                              weight: FontWeight.bold,
                              color:
                                  index == selected
                                      ? Colors.white
                                      : Colors.black54,
                            ),
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
    ),
  );

  Widget _range(String label, double sdp) => Padding(
    padding: EdgeInsets.only(left: 6 * sdp, top: 10 * sdp),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: hrText(
          12 * sdp,
          family: 'Archivo',
          weight: FontWeight.w700,
          color: const Color(0xff6c6e6f),
        ),
      ),
    ),
  );

  Widget _leaveTable(BuildContext context, double sdp) => Padding(
    padding: EdgeInsets.fromLTRB(3, 10 * sdp, 3, 5),
    child: Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8 * sdp),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8 * sdp),
        child: Column(
          children: [
            LayoutBuilder(
              builder:
                  (context, box) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    key: const Key('hr_leave_horizontal'),
                    child: SizedBox(
                      width: math.max(
                        box.maxWidth,
                        280 *
                            sdp *
                            MediaQuery.textScalerOf(context).scale(10) /
                            10,
                      ),
                      child: Column(
                        children: [
                          _tableRow([
                            _cell(
                              'EMP NAME',
                              const Color(0xffc44569),
                              hrText(
                                11 * sdp,
                                family: 'PatuaOne',
                                color: Colors.white,
                              ),
                            ),
                            for (var i = 0; i < 7; i++)
                              Container(
                                color: const Color(0xff596275),
                                padding: EdgeInsets.all(3 * sdp),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      const [
                                        'SAT',
                                        'SUN',
                                        'MON',
                                        'TUE',
                                        'WED',
                                        'THU',
                                        'FRI',
                                      ][i],
                                      textAlign: TextAlign.center,
                                      style: hrText(
                                        10 * sdp,
                                        family: 'PatuaOne',
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '${hrMonths[leaveRange.days[i].month - 1].substring(0, 3)} ${leaveRange.days[i].day.toString().padLeft(2, '0')}',
                                      textAlign: TextAlign.center,
                                      style: hrText(
                                        7 * sdp,
                                        family: 'Archivo',
                                        weight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ]),
                          for (
                            var row = 0;
                            row < (leave?.employees.length ?? 0);
                            row++
                          )
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 2 * sdp),
                              child: _tableRow([
                                _cell(
                                  leave!.employees[row].name,
                                  const Color(0xffcf6a87),
                                  hrText(
                                    9 * sdp,
                                    family: 'OpenSans',
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                for (var i = 0; i < 7; i++)
                                  _cell(
                                    leave!.employees[row].cells[i],
                                    leave!.employees[row].cells[i].isEmpty
                                        ? Colors.white
                                        : const Color(0xffb2bec3),
                                    hrText(
                                      7 * sdp,
                                      family: 'OpenSans',
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    key: Key('hr_leave_${row}_$i'),
                                  ),
                              ]),
                            ),
                        ],
                      ),
                    ),
                  ),
            ),
            if (leave?.hasDateRows == false)
              Padding(
                padding: const EdgeInsets.all(5),
                child: Text(
                  'No one in Leave in this selected week',
                  key: const Key('hr_no_leave'),
                  textAlign: TextAlign.center,
                  style: hrText(12, weight: FontWeight.w500),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(4 * sdp),
              child: Material(
                color: Colors.white,
                elevation: 2 * sdp,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8 * sdp),
                  side: const BorderSide(color: DocColors.greenSea),
                ),
                child: InkWell(
                  key: const Key('hr_leave_more'),
                  borderRadius: BorderRadius.circular(8 * sdp),
                  onTap: () => onDestination(HrDestination.leaveRecord),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Center(
                      child: Text(
                        'SHOW MORE -->',
                        style: hrText(
                          9 * sdp,
                          weight: FontWeight.w700,
                          color: DocColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _tableRow(List<Widget> cells) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cells.length; i++)
          Expanded(
            flex: i == 0 ? 20 : 11,
            child: Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 0 : 1,
                right: i == 7 ? 0 : 1,
              ),
              child: cells[i],
            ),
          ),
      ],
    ),
  );
  Widget _cell(String label, Color color, TextStyle style, {Key? key}) =>
      Container(
        key: key,
        color: color,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4),
        child: Text(label, textAlign: TextAlign.center, style: style),
      );

  Widget _payroll(double sdp) {
    final values = [
      '${payroll?.hours ?? '0'} h',
      if (payroll != null) ...[
        nativeHrMoney(payroll!.salary),
        nativeHrMoney(payroll!.refundable),
        nativeHrMoney(payroll!.allowance),
        nativeHrMoney(payroll!.deduction),
        nativeHrMoney(payroll!.net),
      ] else
        ...List.filled(5, '৳ 0'),
    ];
    const labels = [
      'Working Hours',
      'Salary Generated',
      'Refundable',
      'Total Allowance',
      'Deduction',
      'Net Salary',
    ];
    const colors = [
      Color(0xff47c198),
      Color(0xff4a6de5),
      Color(0xffffc048),
      Color(0xff7f8fa6),
      Color(0xffcc66be),
      Color(0xffff7979),
    ];
    Widget card(int i) => Container(
      constraints: const BoxConstraints(minHeight: 100),
      margin: EdgeInsets.fromLTRB(
        i.isEven ? 4 * sdp : 2.5,
        4 * sdp,
        i.isOdd ? 4 * sdp : 2.5,
        4 * sdp,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 2 * sdp,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8 * sdp),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                ),
                child: const Center(child: NativeHrMovementIcon()),
              ),
              SizedBox(width: 4 * sdp),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 4 * sdp),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labels[i],
                        style: hrText(
                          14,
                          family: 'Archivo',
                          weight: FontWeight.w700,
                          color: const Color(0xffaaaaaa),
                        ),
                      ),
                      SizedBox(height: 4 * sdp),
                      Text(
                        values[i],
                        key: Key('hr_payroll_$i'),
                        style: hrText(
                          12 * sdp,
                          family: 'Roboto',
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: 10 * sdp,
            left: 5 * sdp,
            right: 4 * sdp,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'PAYROLL',
                style: hrText(
                  13 * sdp,
                  weight: FontWeight.w700,
                  color: const Color(0xfffda000),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    InkWell(
                      key: const Key('hr_payroll_month'),
                      onTap: onPayrollMonth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                payrollMonth.label,
                                style: hrText(
                                  10 * sdp,
                                  weight: FontWeight.w500,
                                  color: DocColors.primary,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 16 * sdp,
                              color: const Color(0xffcf6a87),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'WD: ${payroll?.workingDays ?? '0'}',
                      style: hrText(
                        10 * sdp,
                        weight: FontWeight.w500,
                        color: DocColors.greenSea,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < 6; i += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: card(i)),
                Expanded(child: card(i + 1)),
              ],
            ),
          ),
      ],
    );
  }
}
