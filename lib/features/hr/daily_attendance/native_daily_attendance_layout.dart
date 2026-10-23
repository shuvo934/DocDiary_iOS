import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';
import 'daily_attendance_models.dart';

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

Color dailyAttendanceStatusColor(String status) => switch (status) {
  'Out Miss' => const Color(0xffc23616),
  'In Leave' => const Color(0xff8f8f8f),
  'Off Day' => const Color(0xff80e0ff),
  'Present on Leave Day' => const Color(0xff4080c0),
  'Present on Off Day' => const Color(0xffe0c080),
  'Absent' => const Color(0xffc000ff),
  'Present' => const Color(0xff00c080),
  _ => const Color(0xffced6e0),
};

class NativeDailyAttendanceLayout extends StatelessWidget {
  const NativeDailyAttendanceLayout({
    super.key,
    required this.calendar,
    required this.selectedDate,
    required this.branchName,
    required this.filter,
    required this.onBack,
    required this.onBranch,
    required this.onDivision,
    required this.onDepartment,
    required this.onEmployee,
    required this.onDate,
    required this.onRow,
    this.data,
    this.waiting = false,
    this.enabled = true,
    this.message,
  });
  final AttendanceCalendar calendar;
  final DateTime selectedDate;
  final String branchName;
  final AttendanceFilter filter;
  final DailyAttendanceData? data;
  final VoidCallback onBack;
  final ValueChanged<AttendanceChoice> onBranch,
      onDivision,
      onDepartment,
      onEmployee;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<DailyAttendanceRow> onRow;
  final bool waiting, enabled;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).shortestSide;
    final sdp = width < 300 ? 1.0 : (width / 30).floor() * 30 / 300;
    final active = enabled && !waiting && message == null;
    final current = data;
    final rows =
        current == null ? <DailyAttendanceRow>[] : filter.rows(current);
    String selectedName(List<AttendanceChoice> choices, String id) =>
        id.isEmpty
            ? ''
            : choices.where((item) => item.id == id).firstOrNull?.name ?? '';
    final divisions = current?.divisions ?? const <AttendanceChoice>[];
    final departments =
        current == null ? <AttendanceChoice>[] : filter.departments(current);
    final employees =
        current == null ? <AttendanceChoice>[] : filter.employees(current);
    Widget field(
      String name,
      List<AttendanceChoice> choices,
      String value,
      bool allowed,
      ValueChanged<AttendanceChoice> changed,
    ) => _AttendanceField(
      name: name,
      choices: choices,
      selected: selectedName(choices, value),
      enabled: active && allowed,
      changed: changed,
      sdp: sdp,
    );
    final controls = ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8 * sdp, 7 * sdp, 8 * sdp, 4 * sdp),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: field(
                        'Division',
                        divisions,
                        filter.division,
                        true,
                        onDivision,
                      ),
                    ),
                    SizedBox(width: 8 * sdp),
                    Expanded(
                      child: field(
                        'Department',
                        departments,
                        filter.department,
                        filter.departmentEnabled,
                        onDepartment,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 7 * sdp),
                Row(
                  children: [
                    Expanded(
                      flex: 8,
                      child: field(
                        'Employee',
                        employees,
                        filter.employee,
                        filter.employeeEnabled,
                        onEmployee,
                      ),
                    ),
                    SizedBox(width: 6 * sdp),
                    Expanded(
                      flex: 2,
                      child: Container(
                        key: const Key('daily_employee_count'),
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          border: Border.all(color: DocColors.greenSea),
                          borderRadius: BorderRadius.circular(8 * sdp),
                        ),
                        child: Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 2,
                            children: [
                              Icon(
                                Icons.person,
                                size: 17 * sdp,
                                color: DocColors.primary,
                              ),
                              Text(
                                '${current == null ? 0 : filter.employeeCount(current)}',
                                style: _text(8 * sdp, family: 'OpenSans'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8 * sdp),
                Row(
                  children: [
                    _MonthArrow(
                      previous: true,
                      enabled: active && calendar.canMove(selectedDate, -1),
                      onTap: () => onDate(calendar.moveMonth(selectedDate, -1)),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Text(
                          attendanceMonthLabel(selectedDate),
                          key: const Key('daily_selected_month'),
                          textAlign: TextAlign.center,
                          style: _text(12 * sdp, color: DocColors.greenSea),
                        ),
                      ),
                    ),
                    _MonthArrow(
                      previous: false,
                      enabled: active && calendar.canMove(selectedDate, 1),
                      onTap: () => onDate(calendar.moveMonth(selectedDate, 1)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _AttendanceDateStrip(
            calendar: calendar,
            selected: selectedDate,
            enabled: active,
            onDate: onDate,
          ),
          if (message == null) _AttendanceTableCard(sdp: sdp),
        ],
      ),
    );
    final pinned =
        MediaQuery.sizeOf(context).height >= 600 &&
        MediaQuery.textScalerOf(context).scale(12) <= 18;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: DocColors.clouds,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 11 * sdp,
                  vertical: 5 * sdp,
                ),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('daily_attendance_back'),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 44,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: 'Back',
                      onPressed: waiting ? null : onBack,
                      icon: Icon(Icons.arrow_back_ios, size: 20 * sdp),
                    ),
                    SizedBox(width: 12 * sdp),
                    Expanded(
                      child: Text(
                        'Daily Attendance',
                        key: const Key('daily_attendance_title'),
                        style: _text(13 * sdp),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: math.max(80, width * .28),
                      ),
                      child: PopupMenuButton<AttendanceChoice>(
                        key: const Key('daily_branch'),
                        tooltip: 'Select branch',
                        enabled:
                            active && (current?.branches.isNotEmpty ?? false),
                        onSelected: onBranch,
                        itemBuilder:
                            (_) => [
                              for (final item
                                  in current?.branches ?? <AttendanceChoice>[])
                                PopupMenuItem(
                                  value: item,
                                  height: 48,
                                  child: Text(
                                    item.name,
                                    style: _text(12, family: 'Archivo'),
                                  ),
                                ),
                            ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/hospital_icon.png',
                                width: 16 * sdp,
                                height: 18 * sdp,
                                color: DocColors.greenSea,
                              ),
                              SizedBox(width: 4 * sdp),
                              Flexible(
                                child: Text(
                                  branchName,
                                  style: _text(
                                    8 * sdp,
                                    family: 'Archivo',
                                    color: DocColors.greenSea,
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
              const Divider(height: 1, thickness: 1, color: DocColors.greenSea),
              Expanded(
                child: ColoredBox(
                  color: Colors.white,
                  child: Stack(
                    children: [
                      CustomScrollView(
                        key: const Key('daily_attendance_scroll'),
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
                            )
                          else ...[
                            if (!waiting && current != null && rows.isEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.all(8 * sdp),
                                  child: Text(
                                    'Attendance Data Not Found',
                                    key: const Key('daily_no_data'),
                                    textAlign: TextAlign.center,
                                    style: _text(
                                      12 * sdp,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              )
                            else
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _AttendanceTableCard(
                                    key: ValueKey('daily_row_$index'),
                                    sdp: sdp,
                                    row: rows[index],
                                    onTap:
                                        active
                                            ? () => onRow(rows[index])
                                            : null,
                                  ),
                                  childCount: rows.length,
                                ),
                              ),
                          ],
                          const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        ],
                      ),
                      if (waiting)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.white,
                            child: Center(
                              child: CircularProgressIndicator(
                                key: const Key('daily_loading'),
                                color: DocColors.primary,
                              ),
                            ),
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
  }
}

class _AttendanceField extends StatelessWidget {
  const _AttendanceField({
    required this.name,
    required this.choices,
    required this.selected,
    required this.enabled,
    required this.changed,
    required this.sdp,
  });
  final String name, selected;
  final List<AttendanceChoice> choices;
  final bool enabled;
  final ValueChanged<AttendanceChoice> changed;
  final double sdp;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 1,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: PopupMenuButton<AttendanceChoice>(
      key: Key('daily_${name.toLowerCase()}'),
      enabled: enabled && choices.isNotEmpty,
      tooltip: 'Select $name',
      onSelected: changed,
      padding: EdgeInsets.zero,
      itemBuilder:
          (_) => [
            for (var index = 0; index < choices.length; index++)
              PopupMenuItem(
                value: choices[index],
                key: Key('daily_${name.toLowerCase()}_option_$index'),
                child: Text(
                  choices[index].name,
                  style: _text(12, family: 'OpenSans', weight: FontWeight.w400),
                ),
              ),
          ],
      child: InputDecorator(
        isEmpty: selected.isEmpty,
        decoration: InputDecoration(
          labelText: name,
          enabled: enabled,
          labelStyle: _text(
            10 * sdp,
            family: 'OpenSans',
            weight: FontWeight.w400,
            color: enabled ? const Color(0xff6c6e6f) : DocColors.muted,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          filled: true,
          fillColor: enabled ? Colors.white : const Color(0xfff5f5f5),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: DocColors.primary),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: DocColors.primary),
          ),
        ),
        child: Text(
          selected,
          style: _text(9 * sdp, family: 'OpenSans', weight: FontWeight.w400),
        ),
      ),
    ),
  );
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.previous,
    required this.enabled,
    required this.onTap,
  });
  final bool previous, enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: 44,
    child: Center(
      child: Material(
        color: enabled ? DocColors.primary : const Color(0xffb2bec3),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          key: Key(previous ? 'daily_previous_month' : 'daily_next_month'),
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 48,
            height: 25,
            child: Icon(
              previous ? Icons.keyboard_arrow_left : Icons.keyboard_arrow_right,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    ),
  );
}

class _AttendanceDateStrip extends StatefulWidget {
  const _AttendanceDateStrip({
    required this.calendar,
    required this.selected,
    required this.enabled,
    required this.onDate,
  });
  final AttendanceCalendar calendar;
  final DateTime selected;
  final bool enabled;
  final ValueChanged<DateTime> onDate;
  @override
  State<_AttendanceDateStrip> createState() => _AttendanceDateStripState();
}

class _AttendanceDateStripState extends State<_AttendanceDateStrip> {
  final _scroll = ScrollController();
  double _extent = 0;
  bool _aligning = false;
  bool _needsAlignment = true;
  @override
  void didUpdateWidget(covariant _AttendanceDateStrip old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected ||
        old.calendar.first != widget.calendar.first) {
      _needsAlignment = true;
    }
  }

  void _align() {
    if (_aligning) return;
    _aligning = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(
          (widget.calendar.indexOf(widget.selected) * _extent).clamp(
            0.0,
            _scroll.position.maxScrollExtent,
          ),
        );
      }
      _aligning = false;
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final extent = box.maxWidth / 5;
      if (_needsAlignment || extent != _extent) {
        _extent = extent;
        _needsAlignment = false;
        _align();
      }
      final scale = MediaQuery.textScalerOf(context);
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      double textHeight(String label) {
        final painter = TextPainter(
          text: TextSpan(
            text: label,
            style: _text(12, family: 'Roboto', weight: FontWeight.w400),
          ),
          textScaler: scale,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: math.max(1, extent - 8));
        final height = painter.height;
        painter.dispose();
        return height;
      }

      final dateHeight =
          textHeight('31') + weekdays.map(textHeight).reduce(math.max) + 16;
      return Material(
        elevation: 2,
        color: Colors.white,
        child: SizedBox(
          height: math.max(64, dateHeight),
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (_) {
              if (widget.enabled &&
                  !_aligning &&
                  _scroll.hasClients &&
                  _extent > 0) {
                final index = (_scroll.offset / _extent).round().clamp(
                  0,
                  widget.calendar.dayCount - 1,
                );
                final date = widget.calendar.at(index);
                if (date != widget.selected) widget.onDate(date);
              }
              return false;
            },
            child: ListView.builder(
              key: const Key('daily_dates'),
              controller: _scroll,
              physics:
                  widget.enabled
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemExtent: extent,
              padding: EdgeInsets.symmetric(horizontal: extent * 2),
              itemCount: widget.calendar.dayCount,
              itemBuilder: (context, index) {
                final date = widget.calendar.at(index);
                final selected = date == widget.selected;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    child: Material(
                      color: selected ? DocColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        key: Key(
                          'daily_date_${date.year}_${date.month}_${date.day}',
                        ),
                        onTap:
                            widget.enabled ? () => widget.onDate(date) : null,
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: extent,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${date.day}',
                                style: _text(
                                  12,
                                  family: 'Roboto',
                                  weight: FontWeight.w600,
                                  color:
                                      selected ? Colors.white : DocColors.muted,
                                ),
                              ),
                              Text(
                                const [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                  'Sun',
                                ][date.weekday - 1],
                                style: _text(
                                  12,
                                  family: 'Roboto',
                                  weight: FontWeight.w400,
                                  color:
                                      selected ? Colors.white : DocColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}

class _AttendanceTableCard extends StatelessWidget {
  const _AttendanceTableCard({
    super.key,
    required this.sdp,
    this.row,
    this.onTap,
  });
  final double sdp;
  final DailyAttendanceRow? row;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final item = row;
    final header = item == null;
    const secondary = Color(0xff6c6e6f);
    Widget text(
      String value,
      double size, {
      Color color = Colors.black,
      bool left = false,
    }) => Text(
      value,
      textAlign: left ? TextAlign.left : TextAlign.center,
      style: _text(size * sdp, color: color),
    );
    Widget cell(int flex, List<Widget> children, {bool left = false}) =>
        Expanded(
          flex: flex,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 4 * sdp,
              vertical: 2 * sdp,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  left ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: children,
            ),
          ),
        );
    return Card(
      margin: EdgeInsets.fromLTRB(
        4 * sdp,
        (header ? 8 : 5) * sdp,
        4 * sdp,
        4 * sdp,
      ),
      elevation: 3,
      color: header ? const Color(0xff596275) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8 * sdp),
        side: const BorderSide(color: DocColors.muted, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8 * sdp),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children:
                header
                    ? [
                      cell(35, [
                        text('EMP  NAME', 9, color: Colors.white, left: true),
                      ], left: true),
                      cell(17, [text('SHIFT', 9, color: Colors.white)]),
                      cell(16, [text('IN TIME', 9, color: Colors.white)]),
                      cell(16, [text('OUT TIME', 9, color: Colors.white)]),
                      cell(16, [text('STATUS', 9, color: Colors.white)]),
                    ]
                    : [
                      cell(35, [
                        text(
                          item.employee.name,
                          9,
                          color: DocColors.greenSea,
                          left: true,
                        ),
                        text(
                          item.employee.title,
                          8,
                          color: secondary,
                          left: true,
                        ),
                        if (item.location.isNotEmpty)
                          text(
                            '(${item.location})',
                            7,
                            color: secondary,
                            left: true,
                          ),
                      ], left: true),
                      cell(17, [
                        text(item.shift, 8, color: const Color(0xffcf6a87)),
                      ]),
                      cell(16, [
                        text(item.inTime, 8),
                        if (item.lateStatus.isNotEmpty)
                          text('(Late)', 7, color: secondary),
                      ]),
                      cell(16, [
                        text(item.outTime, 8),
                        if (item.earlyStatus.isNotEmpty)
                          text('(Early)', 7, color: secondary),
                      ]),
                      cell(16, [
                        text(
                          item.status,
                          8,
                          color: dailyAttendanceStatusColor(item.status),
                        ),
                      ]),
                    ],
          ),
        ),
      ),
    );
  }
}
