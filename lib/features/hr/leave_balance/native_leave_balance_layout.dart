import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';
import '../native_attendance_filter_style.dart';
import 'leave_balance_models.dart';
import 'native_leave_balance_chart.dart';

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

class NativeLeaveBalanceLayout extends StatelessWidget {
  const NativeLeaveBalanceLayout({
    super.key,
    required this.year,
    required this.onBack,
    required this.onBranch,
    required this.onDivision,
    required this.onDepartment,
    required this.onDesignation,
    required this.onEmployee,
    required this.onYear,
    this.catalog,
    this.report,
    this.waiting = false,
    this.enabled = true,
    this.message,
  });
  final LeaveBalanceYear year;
  final LeaveBalanceCatalog? catalog;
  final LeaveBalanceReport? report;
  final VoidCallback onBack, onYear;
  final ValueChanged<LeaveBalanceChoice> onBranch,
      onDivision,
      onDepartment,
      onDesignation;
  final ValueChanged<LeaveBalanceEmployee> onEmployee;
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
      List<LeaveBalanceChoice> choices,
      LeaveBalanceChoice? selected,
      bool allowed,
      ValueChanged<LeaveBalanceChoice> changed,
    ) => _BalanceField(
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
                      if (value is LeaveBalanceEmployee) {
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
        media.textScaler.scale(14) <= 21 &&
        [
          data?.division,
          data?.department,
          data?.designation,
          data?.employee,
        ].every((c) => (c?.name.length ?? 0) < 60);
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
                        key: const Key('leave_balance_back'),
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
                          'Leave Balance',
                          key: const Key('leave_balance_title'),
                          style: _text(13 * sdp, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: math.max(75, width * .28),
                        ),
                        child: _BalanceMenu(
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Material(
                key: const Key('leave_balance_content_card'),
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
                            key: const Key('leave_balance_scroll'),
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
                                  child: _BalanceHeader(
                                    employee: data!.employee!,
                                    sdp: sdp,
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: Card(
                                    key: const Key('leave_balance_chart_card'),
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
                                    child: Column(
                                      children: [
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: InkWell(
                                            key: const Key(
                                              'leave_balance_year',
                                            ),
                                            onTap: active ? onYear : null,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    8,
                                                    7,
                                                    8,
                                                    5,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    year.label,
                                                    style: _text(
                                                      10 * sdp,
                                                      color: DocColors.primary,
                                                      weight: FontWeight.w600,
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
                                        ),
                                        SizedBox(
                                          height: 205 * sdp,
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4 * sdp,
                                            ),
                                            child: NativeLeaveBalanceChart(
                                              rows: report!.chart,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: _BalanceTable(
                                    rows: report!.rows,
                                    sdp: sdp,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        if (waiting)
                          const Positioned.fill(
                            child: ColoredBox(
                              color: Colors.white,
                              child: Center(
                                child: CircularProgressIndicator(
                                  key: Key('leave_balance_loading'),
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

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.employee, required this.sdp});
  final LeaveBalanceEmployee employee;
  final double sdp;
  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('leave_balance_identity'),
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

class _BalanceField extends StatelessWidget {
  const _BalanceField({
    required this.name,
    required this.choices,
    required this.selected,
    required this.enabled,
    required this.changed,
    required this.sdp,
  });
  final String name, selected;
  final List<LeaveBalanceChoice> choices;
  final bool enabled;
  final ValueChanged<LeaveBalanceChoice> changed;
  final double sdp;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 1,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: _BalanceMenu(
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
class _BalanceMenu extends StatefulWidget {
  const _BalanceMenu({
    required this.name,
    required this.choices,
    required this.enabled,
    required this.changed,
    required this.child,
  });
  final String name;
  final List<LeaveBalanceChoice> choices;
  final bool enabled;
  final ValueChanged<LeaveBalanceChoice> changed;
  final Widget child;
  @override
  State<_BalanceMenu> createState() => _BalanceMenuState();
}

class _BalanceMenuState extends State<_BalanceMenu> {
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
  void didUpdateWidget(covariant _BalanceMenu old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) _close();
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<LeaveBalanceChoice>(
    key: Key('leave_balance_${widget.name}'),
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
              key: Key('leave_balance_${widget.name}_option_$i'),
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

class _BalanceTable extends StatelessWidget {
  const _BalanceTable({required this.rows, required this.sdp});
  final List<LeaveBalanceRow> rows;
  final double sdp;
  static const weights = [25, 15, 15, 13, 14, 13, 15];
  static const headings = [
    'Leave Category',
    'Opening Quantity',
    'Current Quantity',
    'Consumed',
    'Transferred',
    'Cash Taken',
    'Balance Quantity',
  ];
  Widget cells(List<String> values, {bool heading = false}) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i != 0)
            SizedBox(
              width: 1,
              child: ColoredBox(color: heading ? Colors.white : Colors.black54),
            ),
          Expanded(
            flex: weights[i],
            child: Container(
              alignment: Alignment.center,
              padding:
                  heading
                      ? EdgeInsets.symmetric(
                        horizontal: 2 * sdp,
                        vertical: 8 * sdp,
                      )
                      : const EdgeInsets.all(2),
              child: Text(
                values[i],
                textAlign: TextAlign.center,
                style: _text(
                  7 * sdp,
                  color: heading ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Card(
    key: const Key('leave_balance_table'),
    margin: EdgeInsets.fromLTRB(3, 4 * sdp, 3, 8 * sdp),
    color: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8 * sdp)),
    clipBehavior: Clip.antiAlias,
    child:
        rows.isEmpty
            ? Padding(
              padding: EdgeInsets.symmetric(vertical: 4 * sdp),
              child: Text(
                'No Data Found',
                key: const Key('leave_balance_no_data'),
                textAlign: TextAlign.center,
                style: _text(
                  12 * sdp,
                  color: const Color(0xff6c6e6f),
                  weight: FontWeight.w600,
                ),
              ),
            )
            : Column(
              children: [
                ColoredBox(
                  color: DocColors.primary,
                  child: cells(headings, heading: true),
                ),
                for (var i = 0; i < rows.length; i++) ...[
                  if (i != 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.black26,
                    ),
                  KeyedSubtree(
                    key: Key('leave_balance_table_row_$i'),
                    child: cells(rows[i].values),
                  ),
                ],
              ],
            ),
  );
}
