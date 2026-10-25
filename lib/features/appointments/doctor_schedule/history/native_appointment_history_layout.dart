import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_theme.dart';
import '../native_appointment_timeline_card.dart';
import 'doctor_appointment_history_models.dart';

class NativeAppointmentHistoryLayout extends StatelessWidget {
  const NativeAppointmentHistoryLayout({
    super.key,
    required this.patient,
    required this.range,
    required this.rows,
    required this.now,
    this.clock,
    required this.onBack,
    required this.onRange,
    required this.onToggle,
    required this.onFilter,
    this.selected = const {},
    this.choices = const {},
    this.showFilters = false,
    this.waiting = false,
    this.enabled = true,
    this.failed = false,
    this.message,
  });
  final AppointmentHistoryPatient patient;
  final AppointmentHistoryRange range;
  final List<AppointmentHistoryRow> rows;
  final DateTime now;
  final DateTime Function()? clock;
  final VoidCallback onBack, onRange, onToggle;
  final void Function(AppointmentHistoryFilter, Rect) onFilter;
  final Map<AppointmentHistoryFilter, AppointmentHistoryChoice> selected;
  final Map<AppointmentHistoryFilter, List<AppointmentHistoryChoice>> choices;
  final bool showFilters, waiting, enabled, failed;
  final String? message;
  @override
  Widget build(BuildContext context) {
    final sdp = appointmentScale(context), media = MediaQuery.of(context);
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
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(
                    52,
                    (media.size.height - media.padding.vertical) * .09,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12 * sdp,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('doctor_history_back'),
                        tooltip: 'Back',
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 44,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: waiting ? null : onBack,
                        icon: Icon(
                          Icons.arrow_back_ios,
                          size: 19 * sdp,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Appointment History',
                          style: appointmentText(
                            13 * sdp,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Material(
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  child: SafeArea(
                    top: false,
                    child:
                        waiting
                            ? const Center(
                              child: CircularProgressIndicator(
                                key: Key('doctor_history_loading'),
                              ),
                            )
                            : CustomScrollView(
                              key: const Key('doctor_history_scroll'),
                              slivers: [
                                _NativeHistoryHeader(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      8.8,
                                      10.8,
                                      8.8,
                                      0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          patient.name,
                                          key: const Key(
                                            'doctor_history_patient',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: appointmentText(
                                            13 * sdp,
                                            weight: FontWeight.w700,
                                            color: Colors.black,
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.only(
                                            bottom: 4 * sdp,
                                          ),
                                          child: Text(
                                            patient.code,
                                            key: const Key(
                                              'doctor_history_patient_code',
                                            ),
                                            textAlign: TextAlign.center,
                                            style: appointmentText(10 * sdp),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 4 * sdp,
                                            vertical: 5 * sdp,
                                          ),
                                          child: IntrinsicHeight(
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Expanded(
                                                  child: _HistoryField(
                                                    label: 'Date Range',
                                                    value: range.label,
                                                    fieldKey: const Key(
                                                      'doctor_history_range',
                                                    ),
                                                    enabled: enabled,
                                                    onTap: (_) => onRange(),
                                                    sdp: sdp,
                                                    date: true,
                                                  ),
                                                ),
                                                SizedBox(width: 5 * sdp),
                                                ElevatedButton.icon(
                                                  key: const Key(
                                                    'doctor_history_filter_toggle',
                                                  ),
                                                  onPressed:
                                                      enabled ? onToggle : null,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        DocColors.primary,
                                                    foregroundColor:
                                                        Colors.white,
                                                    minimumSize: Size.zero,
                                                    elevation: 1,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8 * sdp,
                                                          ),
                                                    ),
                                                  ),
                                                  icon: Icon(
                                                    Icons.search,
                                                    size: 16 * sdp,
                                                  ),
                                                  label: Text(
                                                    'FILTER',
                                                    style: appointmentText(
                                                      9 * sdp,
                                                      weight: FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          child:
                                              showFilters
                                                  ? Column(
                                                    key: const Key(
                                                      'doctor_history_filters',
                                                    ),
                                                    children: [
                                                      for (final kind
                                                          in AppointmentHistoryFilter
                                                              .values)
                                                        Padding(
                                                          padding:
                                                              EdgeInsets.fromLTRB(
                                                                4 * sdp,
                                                                0,
                                                                4 * sdp,
                                                                5 * sdp,
                                                              ),
                                                          child: _HistoryField(
                                                            label: kind.label,
                                                            value:
                                                                selected[kind]
                                                                    ?.name ??
                                                                '',
                                                            sdp: sdp,
                                                            fieldKey: Key(
                                                              'doctor_history_filter_${kind.name}',
                                                            ),
                                                            enabled:
                                                                enabled &&
                                                                (choices[kind]
                                                                        ?.isNotEmpty ??
                                                                    false),
                                                            onTap:
                                                                (anchor) =>
                                                                    onFilter(
                                                                      kind,
                                                                      anchor,
                                                                    ),
                                                          ),
                                                        ),
                                                    ],
                                                  )
                                                  : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (message != null)
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        message!,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )
                                else if (!failed && rows.isEmpty)
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.all(8 * sdp),
                                      child: Text(
                                        'No Appointment History Found',
                                        key: const Key('doctor_history_empty'),
                                        textAlign: TextAlign.center,
                                        style: appointmentText(
                                          14,
                                          weight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  )
                                else if (!failed)
                                  SliverPadding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.8 + 4 * sdp,
                                    ),
                                    sliver: SliverList.builder(
                                      itemCount: rows.length,
                                      itemBuilder:
                                          (context, index) => _HistoryCard(
                                            row: rows[index],
                                            now: clock?.call() ?? now,
                                            index: index,
                                            sdp: sdp,
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
    );
  }
}

class _NativeHistoryHeader extends StatelessWidget {
  const _NativeHistoryHeader({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final header = ColoredBox(color: Colors.white, child: child);
    // Native patient/date/filter controls sit above the scrolling RecyclerView.
    // Let the entire body scroll when large text/landscape needs more space.
    return media.size.height - media.padding.vertical > 450 &&
            media.textScaler.scale(12) <= 18
        ? PinnedHeaderSliver(child: header)
        : SliverToBoxAdapter(child: header);
  }
}

class _HistoryField extends StatelessWidget {
  const _HistoryField({
    required this.label,
    required this.value,
    required this.fieldKey,
    required this.sdp,
    required this.enabled,
    required this.onTap,
    this.date = false,
  });
  final String label, value;
  final Key fieldKey;
  final double sdp;
  final bool enabled, date;
  final ValueChanged<Rect> onTap;
  @override
  Widget build(BuildContext context) => Builder(
    builder:
        (context) => Material(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8 * sdp),
            side: const BorderSide(color: DocColors.primary),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: fieldKey,
            onTap:
                enabled
                    ? () {
                      final box = context.findRenderObject()! as RenderBox;
                      onTap(box.localToGlobal(Offset.zero) & box.size);
                    }
                    : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: InputDecorator(
                isEmpty: value.isEmpty,
                decoration: InputDecoration(
                  labelText: label,
                  enabled: enabled,
                  labelStyle: appointmentText(9 * sdp, color: Colors.black54),
                  floatingLabelStyle: appointmentText(
                    10 * sdp,
                    color: Colors.black54,
                  ),
                  prefixIcon:
                      date
                          ? Icon(
                            Icons.calendar_month,
                            color: DocColors.greenSea,
                            size: 17 * sdp,
                          )
                          : null,
                  suffixIcon:
                      date
                          ? null
                          : const Icon(
                            Icons.arrow_drop_down,
                            color: Color(0xff6c6e6f),
                          ),
                  filled: true,
                  fillColor: enabled ? Colors.white : const Color(0xfff5f5f5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
                child: Text(
                  value.isEmpty ? ' ' : value,
                  style: appointmentText(
                    9 * sdp,
                    weight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.row,
    required this.now,
    required this.index,
    required this.sdp,
  });
  final AppointmentHistoryRow row;
  final DateTime now;
  final int index;
  final double sdp;
  @override
  Widget build(BuildContext context) {
    final status = row.status(now);
    final badge = Container(
      key: Key('doctor_history_status_$index'),
      padding: EdgeInsets.all(4 * sdp),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15 * sdp),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 2,
            offset: Offset(0, 2), // নিচের দিকে shadow
          ),
        ],
        color: switch (status) {
          AppointmentHistoryStatus.canceled => const Color(0xffc23616),
          AppointmentHistoryStatus.completed => DocColors.greenSea,
          _ => const Color(0xff6c6e6f),
        },
      ),
      child: Text(
        status.label,
        textAlign: TextAlign.center,
        style: appointmentText(
          7 * sdp,
          weight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
    final time = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          row.value('schedule_time'),
          textAlign: TextAlign.center,
          style: appointmentText(
            11 * sdp,
            weight: FontWeight.w700,
            color: DocColors.primary,
          ),
        ),
        Text(
          '( ${row.value('ets')} )',
          textAlign: TextAlign.center,
          style: appointmentText(9 * sdp, family: 'PatuaOne'),
        ),
      ],
    );
    Widget line(String label, Widget value) => Padding(
      padding: EdgeInsets.all(2 * sdp),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Text(
              label,
              style: appointmentText(
                10 * sdp,
                weight: FontWeight.w600,
                color: DocColors.primary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              ':',
              style: appointmentText(
                10 * sdp,
                weight: FontWeight.w600,
                color: DocColors.primary,
              ),
            ),
          ),
          Expanded(flex: 13, child: value),
        ],
      ),
    );
    return Card(
      key: Key('doctor_history_card_$index'),
      elevation: 1,
      color: Colors.white,
      margin: EdgeInsets.symmetric(horizontal: 4 * sdp, vertical: 8 * sdp),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8 * sdp),
        side: const BorderSide(color: Color(0xff95a5a6), width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(5 * sdp),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(3 * sdp, 3 * sdp, 3 * sdp, 0),
              child: Text(
                '${row.value('app_date').toUpperCase()}, ${row.value('date_name')}',
                textAlign: TextAlign.center,
                style: appointmentText(
                  12 * sdp,
                  weight: FontWeight.w700,
                  color: DocColors.greenSea,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(3 * sdp, 3 * sdp, 3 * sdp, 6 * sdp),
              child:
                  MediaQuery.textScalerOf(context).scale(12) > 18
                      ? Column(
                        children: [
                          time,
                          Align(alignment: Alignment.centerRight, child: badge),
                        ],
                      )
                      : Stack(
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 70 * sdp),
                            child: SizedBox(
                              width: double.infinity,
                              child: time,
                            ),
                          ),
                          Align(alignment: Alignment.centerRight, child: badge),
                        ],
                      ),
            ),
            line(
              'Service',
              Text(
                row.value('pfn_fee_name'),
                style: appointmentText(
                  10 * sdp,
                  weight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
            line(
              'Doctor',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.value('doc_name'),
                    style: appointmentText(
                      10 * sdp,
                      weight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    '( ${row.value('depts_name')} )',
                    style: appointmentText(9 * sdp, weight: FontWeight.w500),
                  ),
                  Text(
                    '( ${row.value('deptd_name')} )',
                    style: appointmentText(9 * sdp, weight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NativeAppointmentHistoryChoices extends StatefulWidget {
  const NativeAppointmentHistoryChoices({
    super.key,
    required this.kind,
    required this.choices,
    required this.anchor,
  });
  final AppointmentHistoryFilter kind;
  final List<AppointmentHistoryChoice> choices;
  final Rect anchor;
  @override
  State<NativeAppointmentHistoryChoices> createState() =>
      _NativeAppointmentHistoryChoicesState();
}

class _NativeAppointmentHistoryChoicesState
    extends State<NativeAppointmentHistoryChoices> {
  final _space = GlobalKey();
  Size? _bounds;
  Offset? _origin;
  int _measure = 0;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    key: _space,
    builder: (context, bounds) {
      final size = Size(bounds.maxWidth, bounds.maxHeight);
      if (_bounds != size) {
        _bounds = size;
        _origin = null;
        final generation = ++_measure;
        // DialogRoute has already consumed its SafeArea insets. Measure the
        // actual overlay origin instead of adding a second notch/status inset.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || generation != _measure) return;
          final box = _space.currentContext?.findRenderObject();
          if (box is RenderBox && box.hasSize) {
            setState(() => _origin = box.localToGlobal(Offset.zero));
          }
        });
      }
      if (_origin == null) return const SizedBox.expand();
      final choices = widget.choices, kind = widget.kind;
      final rect = widget.anchor.shift(-_origin!);
      final below = bounds.maxHeight - rect.bottom - 8, above = rect.top - 8;
      final up = below < 144 && above > below;
      final height = math.max(48, math.min(320, up ? above : below)).toDouble();
      final width = rect.width.clamp(160.0, bounds.maxWidth - 16).toDouble();
      return Stack(
        children: [
          Positioned(
            left: rect.left.clamp(8.0, bounds.maxWidth - width - 8).toDouble(),
            width: width,
            top: up ? null : rect.bottom,
            bottom: up ? bounds.maxHeight - rect.top : null,
            child: Material(
              color: Colors.white,
              elevation: 3,
              borderRadius: BorderRadius.circular(4),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: height),
                child: ListView(
                  key: const Key('doctor_history_choices'),
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    for (var i = 0; i < choices.length; i++)
                      InkWell(
                        key: Key('doctor_history_choice_${kind.name}_$i'),
                        onTap: () => Navigator.pop(context, choices[i]),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  choices[i].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: appointmentText(
                                    16,
                                    family: 'Roboto',
                                    color: Colors.black,
                                  ),
                                ),
                                if (choices
                                        .where((c) => c.name == choices[i].name)
                                        .length >
                                    1)
                                  Text(
                                    'ID: ${choices[i].id}',
                                    style: appointmentText(
                                      12,
                                      family: 'Roboto',
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
        ],
      );
    },
  );
}
