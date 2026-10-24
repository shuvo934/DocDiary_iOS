import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';
import '../hr_dashboard_models.dart';
import '../native_attendance_filter_style.dart';
import 'leave_record_models.dart';

TextStyle _text(
  double size, {
  Color color = Colors.black,
  String family = 'Poppins',
  FontWeight weight = FontWeight.w700,
}) => TextStyle(
  fontFamily: family,
  fontFamilyFallback: const ['DocDiaryBengali'],
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: 1.5,
);
Color leaveRecordStatusColor(String status) => switch (status) {
  '0' => DocColors.muted,
  '1' => DocColors.greenSea,
  '2' => const Color(0xffc23616),
  '3' => const Color(0xffff7675),
  _ => const Color(0xff6c6e6f),
};

class NativeLeaveRecordLayout extends StatelessWidget {
  const NativeLeaveRecordLayout({
    super.key,
    required this.month,
    required this.filter,
    required this.onBack,
    required this.onBranch,
    required this.onDivision,
    required this.onDepartment,
    required this.onEmployee,
    required this.onMonth,
    required this.onSummary,
    required this.onRow,
    required this.onRefresh,
    this.data,
    this.waiting = false,
    this.enabled = true,
    this.message,
  });
  final LeaveRecordMonth month;
  final LeaveRecordData? data;
  final LeaveRecordFilter filter;
  final bool waiting, enabled;
  final String? message;
  final VoidCallback onBack, onMonth, onSummary;
  final ValueChanged<LeaveRecordChoice> onBranch,
      onDivision,
      onDepartment,
      onEmployee;
  final ValueChanged<LeaveRecordRow> onRow;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context),
        width = MediaQuery.sizeOf(context).shortestSide;
    final sdp = width < 300 ? 1.0 : (width / 30).floor() * 30 / 300;
    final active = enabled && !waiting && message == null && data != null;
    final rows = data == null ? <LeaveRecordRow>[] : filter.rows(data!);
    final compact =
        media.size.height < 650 ||
        media.textScaler.scale(12) > 16.8 ||
        [
          filter.division,
          filter.department,
          filter.employee,
        ].any((id) => id.length > 60) ||
        (data != null &&
            [
              ...data!.divisions,
              ...filter.departments(data!),
              ...filter.employees(data!),
            ].any(
              (c) =>
                  [
                    filter.division,
                    filter.department,
                    filter.employee,
                  ].contains(c.id) &&
                  c.name.length > 60,
            ));
    Widget field(
      String name,
      List<LeaveRecordChoice> choices,
      String selected,
      bool allowed,
      ValueChanged<LeaveRecordChoice> changed,
    ) => _RecordField(
      name: name,
      choices: choices,
      selected:
          selected.isEmpty
              ? ''
              : choices.where((c) => c.id == selected).firstOrNull?.name ?? '',
      enabled: active && allowed,
      changed: changed,
      sdp: sdp,
    );
    final controls = [
      Padding(
        padding: EdgeInsets.all(4 * sdp),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: field(
                'Division',
                data?.divisions ?? [],
                filter.division,
                true,
                onDivision,
              ),
            ),
            SizedBox(width: 6 * sdp),
            Expanded(
              child: field(
                'Department',
                data == null ? [] : filter.departments(data!),
                filter.department,
                filter.departmentEnabled,
                onDepartment,
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(4 * sdp, 4 * sdp, 4 * sdp, 8 * sdp),
        child: field(
          'Employee',
          data == null ? [] : filter.employees(data!),
          filter.employee,
          filter.employeeEnabled,
          onEmployee,
        ),
      ),
      Card(
        margin: EdgeInsets.all(4 * sdp),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8 * sdp),
          side: const BorderSide(color: DocColors.greenSea),
        ),
        child: InkWell(
          key: const Key('leave_record_month'),
          onTap: active ? onMonth : null,
          borderRadius: BorderRadius.circular(8 * sdp),
          child: Padding(
            padding: EdgeInsets.all(7 * sdp),
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 3 * sdp,
                children: [
                  Text(
                    '${hrMonths[month.first.month - 1].toUpperCase()}, ${month.first.year}',
                    style: _text(12 * sdp, color: DocColors.greenSea),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18 * sdp,
                    color: DocColors.greenSea,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      _RecordHeading(sdp: sdp, onSummary: active ? onSummary : null),
    ];
    Widget empty() => Padding(
      padding: EdgeInsets.all(8 * sdp),
      child: Text(
        'No Leave Record Found',
        textAlign: TextAlign.center,
        style: _text(12 * sdp, color: Colors.black54),
      ),
    );
    Widget row(int i) => _RecordCard(
      row: rows[i],
      sdp: sdp,
      onTap: active ? () => onRow(rows[i]) : null,
    );
    Widget list =
        compact
            ? CustomScrollView(
              key: const Key('leave_record_scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                for (final control in controls)
                  SliverToBoxAdapter(child: control),
                if (rows.isEmpty)
                  SliverToBoxAdapter(child: empty())
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => row(i),
                      childCount: rows.length,
                    ),
                  ),
              ],
            )
            : Column(
              children: [
                ...controls,
                Expanded(
                  child: ListView.builder(
                    key: const Key('leave_record_scroll'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 10, bottom: 8),
                    itemCount: rows.isEmpty ? 1 : rows.length,
                    itemBuilder: (_, i) => rows.isEmpty ? empty() : row(i),
                  ),
                ),
              ],
            );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: DocColors.primary,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(12 * sdp),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('leave_record_back'),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tightFor(
                        width: 19 * sdp,
                        height: 19 * sdp,
                      ),
                      icon: Icon(Icons.arrow_back_ios, size: 19 * sdp),
                      color: Colors.white,
                      disabledColor: Colors.white54,
                      onPressed: !waiting ? onBack : null,
                    ),
                    SizedBox(width: 12 * sdp),
                    Expanded(
                      child: Text(
                        'Leave Record',
                        style: _text(13 * sdp, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: media.size.width * .38,
                      ),
                      child: _LeaveRecordMenu(
                        name: 'branch',
                        choices: data?.branches ?? [],
                        enabled: active,
                        changed: onBranch,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/hospital_icon.png',
                              width: 16 * sdp,
                              height: 18 * sdp,
                              color: Colors.white,
                            ),
                            SizedBox(width: 2 * sdp),
                            Flexible(
                              child: Text(
                                data?.branch.name ?? 'None',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                  ],
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
                                  key: Key('leave_record_loading'),
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
                              : Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  8.8,
                                  8.8,
                                  8.8,
                                  0,
                                ),
                                child: RefreshIndicator(
                                  onRefresh: onRefresh,
                                  child: list,
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
}

class _RecordField extends StatelessWidget {
  const _RecordField({
    required this.name,
    required this.choices,
    required this.selected,
    required this.enabled,
    required this.changed,
    required this.sdp,
  });
  final String name, selected;
  final List<LeaveRecordChoice> choices;
  final bool enabled;
  final ValueChanged<LeaveRecordChoice> changed;
  final double sdp;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 1,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: _LeaveRecordMenu(
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

class _RecordHeading extends StatelessWidget {
  const _RecordHeading({required this.sdp, required this.onSummary});
  final double sdp;
  final VoidCallback? onSummary;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.fromLTRB(2 * sdp, 8 * sdp, 2 * sdp, 5 * sdp),
    elevation: 2,
    color: const Color(0xff596275),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8 * sdp)),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8 * sdp),
        border: Border.all(color: DocColors.muted, width: 2),
      ),
      padding: const EdgeInsets.all(7),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                flex: const [27, 18, 19, 16][i],
                child: InkWell(
                  key: i == 3 ? const Key('leave_record_status') : null,
                  onTap: i == 3 ? onSummary : null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4 * sdp,
                      vertical: 2 * sdp,
                    ),
                    child: Align(
                      alignment:
                          i == 0 ? Alignment.centerLeft : Alignment.center,
                      child: Text(
                        const [
                          'EMP  NAME',
                          'LEAVE TYPE',
                          'LEAVE DATE',
                          'STATUS',
                        ][i],
                        textAlign: i == 0 ? TextAlign.start : TextAlign.center,
                        style: _text(
                          9 * sdp,
                          color:
                              i == 3 ? const Color(0xfff6e58d) : Colors.white,
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

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.row,
    required this.sdp,
    required this.onTap,
  });
  final LeaveRecordRow row;
  final double sdp;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.fromLTRB(2 * sdp, 0, 2 * sdp, 4 * sdp),
    elevation: 3,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8 * sdp)),
    child: InkWell(
      key: Key('leave_record_row_${row.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8 * sdp),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8 * sdp),
          border: Border.all(color: DocColors.muted, width: 2),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 27,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4 * sdp,
                    vertical: 2 * sdp,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.value('emp_name'),
                        style: _text(9 * sdp, color: DocColors.greenSea),
                      ),
                      Text(
                        row.value('job_calling_title'),
                        style: _text(8 * sdp),
                      ),
                      if (row.value('coa_name').isNotEmpty)
                        Text(
                          '(${row.value('coa_name')})',
                          style: _text(7 * sdp, color: const Color(0xff6c6e6f)),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 18,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4 * sdp,
                    vertical: 2 * sdp,
                  ),
                  child: Center(
                    child: Text(
                      row.value('leave_type'),
                      textAlign: TextAlign.center,
                      style: _text(8 * sdp, color: const Color(0xffcf6a87)),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 19,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4 * sdp,
                    vertical: 2 * sdp,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        row.dateLabel,
                        textAlign: TextAlign.center,
                        style: _text(8 * sdp),
                      ),
                      Text(
                        row.daysLabel,
                        textAlign: TextAlign.center,
                        style: _text(7 * sdp, color: const Color(0xff6c6e6f)),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 16,
                child: Padding(
                  padding: EdgeInsets.all(4 * sdp),
                  child: Center(
                    child: Text(
                      row.statusLabel,
                      textAlign: TextAlign.center,
                      style: _text(
                        8 * sdp,
                        color: leaveRecordStatusColor(row.status),
                      ).copyWith(
                        shadows: const [
                          Shadow(
                            color: Color(0xffced6e0),
                            offset: Offset(1, 1),
                            blurRadius: 2,
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
      ),
    ),
  );
}

/// Own this module's menus as well as its dialogs during logout/background/disposal.
class _LeaveRecordMenu extends StatefulWidget {
  const _LeaveRecordMenu({
    required this.name,
    required this.choices,
    required this.enabled,
    required this.changed,
    required this.child,
  });
  final String name;
  final List<LeaveRecordChoice> choices;
  final bool enabled;
  final ValueChanged<LeaveRecordChoice> changed;
  final Widget child;
  @override
  State<_LeaveRecordMenu> createState() => _LeaveRecordMenuState();
}

class _LeaveRecordMenuState extends State<_LeaveRecordMenu> {
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
  void didUpdateWidget(covariant _LeaveRecordMenu old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) _close();
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<LeaveRecordChoice>(
    key: Key('leave_record_${widget.name}'),
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
              key: Key('leave_record_${widget.name}_option_$i'),
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
