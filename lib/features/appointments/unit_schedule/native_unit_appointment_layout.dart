import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';
import '../../../core/native_dates.dart';
import '../doctor_schedule/doctor_appointment_models.dart';
import '../doctor_schedule/native_appointment_calendar.dart';
import '../doctor_schedule/native_appointment_timeline_card.dart';
import 'unit_appointment_models.dart';

TextStyle unitAppointmentText(
  double size,
  double sdp, {
  FontWeight weight = FontWeight.w400,
  Color color = const Color(0xff6c6e6f),
  String family = 'Poppins',
}) => appointmentText(
  math.max(8, size * sdp - 1),
  weight: weight,
  color: color,
  family: family,
);

/// activity_unit_wise_appointment + unit_wise_appointment_extra_layout.
class NativeUnitAppointmentLayout extends StatelessWidget {
  const NativeUnitAppointmentLayout({
    super.key,
    required this.window,
    required this.selected,
    required this.now,
    required this.units,
    required this.unit,
    required this.doctor,
    required this.rows,
    required this.doctorCount,
    required this.hasDoctors,
    required this.generation,
    required this.onBack,
    required this.onUnit,
    required this.onDoctor,
    required this.onStats,
    required this.onDate,
    required this.onMonth,
    required this.scroll,
    this.title = 'Unit Appointment',
    this.keyPrefix = 'unit_appointment',
    this.leadingFilter,
    this.unitLabel,
    this.unitEnabled = true,
    this.doctorEnabled = true,
    this.controlsMargin = 5,
    this.emptyMessage = 'No Doctor/Therapist Found',
    this.onCall,
    this.busy = false,
    this.enabled = true,
    this.message,
  });
  final DoctorAppointmentWindow window;
  final DateTime selected, now;
  final List<UnitAppointmentChoice> units;
  final UnitAppointmentChoice? unit, doctor;
  final List<UnitAppointmentDoctor> rows;
  final int doctorCount, generation;
  final bool hasDoctors, busy, enabled;
  final String? message;
  final VoidCallback onBack, onStats;
  final ValueChanged<Rect> onUnit, onDoctor;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<int> onMonth;
  final ScrollController scroll;
  final String title, keyPrefix, emptyMessage;
  final String? unitLabel;
  final Widget? leadingFilter;
  final bool unitEnabled, doctorEnabled;
  final double controlsMargin;
  final ValueChanged<UnitAppointmentSlot>? onCall;
  Key _key(String suffix) => Key('${keyPrefix}_$suffix');
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context), sdp = appointmentScale(context);
    final active = enabled && !busy && message == null;
    Widget fieldRow(Widget field, Widget badge) => Padding(
      padding: EdgeInsets.fromLTRB(4 * sdp, 0, 4 * sdp, 5 * sdp),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 8, child: field),
            SizedBox(width: 8 * sdp),
            Expanded(flex: 2, child: badge),
          ],
        ),
      ),
    );
    Widget month(int delta) => SizedBox(
      width: 48,
      height: 25,
      child: Material(
        color:
            window.canMove(selected, delta)
                ? DocColors.primary
                : const Color(0xffb2bec3),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          key: _key(delta < 0 ? 'previous' : 'next'),
          onTap:
              active && window.canMove(selected, delta)
                  ? () => onMonth(delta)
                  : null,
          child: Icon(
            delta < 0 ? Icons.chevron_left : Icons.chevron_right,
            size: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
    final controls = ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              controlsMargin * sdp + 8.8,
              (controlsMargin + 3) * sdp + 8.8,
              controlsMargin * sdp + 8.8,
              0,
            ),
            child: Column(
              children: [
                if (leadingFilter != null) leadingFilter!,
                fieldRow(
                  NativeScheduleSelectionField(
                    fieldKey: _key('unit'),
                    label: unitLabel ?? (unit == null ? 'Select Unit' : 'Unit'),
                    value: unit?.name ?? '',
                    sdp: sdp,
                    enabled: unitEnabled,
                    onTap:
                        active && unitEnabled && units.isNotEmpty
                            ? onUnit
                            : null,
                  ),
                  NativeScheduleTotalsButton(
                    tapKey: _key('totals'),
                    sdp: sdp,
                    onTap: active ? onStats : null,
                  ),
                ),
                fieldRow(
                  NativeScheduleSelectionField(
                    fieldKey: _key('doctor'),
                    label:
                        doctor == null
                            ? 'Select Doctor/Therapist'
                            : 'Doctor/Therapist',
                    value: doctor?.name ?? '',
                    sdp: sdp,
                    enabled: doctorEnabled,
                    onTap:
                        active && doctorEnabled && hasDoctors && doctorCount > 0
                            ? onDoctor
                            : null,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8 * sdp),
                      border: Border.all(color: DocColors.greenSea),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _UnitIcon(
                              _UnitGlyph.person,
                              size: 17 * sdp,
                              color: DocColors.primary,
                            ),
                            Text(
                              hasDoctors ? '  $doctorCount' : '',
                              key: _key('doctor_count'),
                              style: unitAppointmentText(
                                8,
                                sdp,
                                weight: FontWeight.w700,
                                color: Colors.black87,
                                family: 'OpenSans',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(5 * sdp, 0, 5 * sdp, 5 * sdp),
                  child: Row(
                    children: [
                      month(-1),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(5 * sdp),
                          child: Text(
                            DoctorAppointmentWindow.label(selected),
                            key: _key('month'),
                            textAlign: TextAlign.center,
                            style: unitAppointmentText(
                              12,
                              sdp,
                              weight: FontWeight.w700,
                              color: DocColors.greenSea,
                            ),
                          ),
                        ),
                      ),
                      month(1),
                    ],
                  ),
                ),
              ],
            ),
          ),
          NativeAppointmentCalendar(
            window: window,
            selected: selected,
            enabled: active,
            onSelected: onDate,
          ),
        ],
      ),
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
                        key: _key('back'),
                        tooltip: 'Back',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 44,
                        ),
                        onPressed: busy ? null : onBack,
                        icon: _UnitIcon(
                          _UnitGlyph.back,
                          size: 19 * sdp,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          title,
                          style: unitAppointmentText(
                            14,
                            sdp,
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
                    child: Stack(
                      children: [
                        CustomScrollView(
                          key: _key('scroll'),
                          controller: scroll,
                          slivers: [
                            if (media.size.height - media.padding.vertical >
                                    450 &&
                                media.textScaler.scale(12) <= 18)
                              PinnedHeaderSliver(child: controls)
                            else
                              SliverToBoxAdapter(child: controls),
                            if (message != null)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    message!,
                                    key: _key('message'),
                                    textAlign: TextAlign.center,
                                    style: unitAppointmentText(
                                      12,
                                      sdp,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                            else if (hasDoctors && rows.isEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    emptyMessage,
                                    key: _key('empty'),
                                    textAlign: TextAlign.center,
                                    style: unitAppointmentText(
                                      12,
                                      sdp,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.only(top: 10),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (_, index) => _UnitDoctorCard(
                                      key: ValueKey(
                                        '${oracleDate(selected)}_${unit?.id}_${generation}_${rows[index].id}_$index',
                                      ),
                                      doctor: rows[index],
                                      index: index,
                                      now: now,
                                      sdp: sdp,
                                      onCall: onCall,
                                    ),
                                    childCount: rows.length,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (busy)
                          Positioned.fill(
                            child: ColoredBox(
                              color: const Color(0xeeffffff),
                              child: Center(
                                child: CircularProgressIndicator(
                                  key: _key('loading'),
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
          ),
        ),
      ),
    );
  }
}

/// Shared native readonly fields; AllAppointment adds a department row.
class NativeScheduleSelectionField extends StatelessWidget {
  const NativeScheduleSelectionField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.sdp,
    required this.onTap,
    this.enabled = true,
  });
  final Key fieldKey;
  final String label, value;
  final double sdp;
  final ValueChanged<Rect>? onTap;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Builder(
    builder:
        (context) => Material(
          elevation: 1,
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: DocColors.primary),
          ),
          child: InkWell(
            key: fieldKey,
            borderRadius: BorderRadius.circular(10),
            onTap:
                !enabled || onTap == null
                    ? null
                    : () {
                      final box = context.findRenderObject()! as RenderBox;
                      onTap!(box.localToGlobal(Offset.zero) & box.size);
                    },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: InputDecorator(
                isEmpty: value.isEmpty,
                decoration: InputDecoration(
                  enabled: enabled,
                  labelText: label,
                  labelStyle: unitAppointmentText(10, sdp, family: 'Roboto'),
                  floatingLabelStyle: unitAppointmentText(
                    11,
                    sdp,
                    family: 'Roboto',
                  ),
                  suffixIcon: const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xff6c6e6f),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                ),
                child: Text(
                  value.isEmpty ? ' ' : value,
                  style: unitAppointmentText(
                    9,
                    sdp,
                    family: 'OpenSans',
                    color: enabled ? Colors.black : DocColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
  );
}

class NativeScheduleTotalsButton extends StatelessWidget {
  const NativeScheduleTotalsButton({
    super.key,
    required this.tapKey,
    required this.sdp,
    required this.onTap,
  });
  final Key tapKey;
  final double sdp;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: DocColors.primary,
    elevation: 1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: DocColors.greenSea),
    ),
    child: InkWell(
      key: tapKey,
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Center(
          child: _UnitIcon(
            _UnitGlyph.clock,
            size: 17 * sdp,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}

/// doc_list_view_layout: each doctor has an always-visible horizontal schedule.
class _UnitDoctorCard extends StatelessWidget {
  const _UnitDoctorCard({
    super.key,
    required this.doctor,
    required this.index,
    required this.now,
    required this.sdp,
    this.onCall,
  });
  final UnitAppointmentDoctor doctor;
  final int index;
  final DateTime now;
  final double sdp;
  final ValueChanged<UnitAppointmentSlot>? onCall;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(5 * sdp, 5 * sdp, 5 * sdp, 12 * sdp),
    child: Material(
      key: Key('unit_doctor_card_${doctor.id}_$index'),
      color: Colors.white,
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8 * sdp),
        side: const BorderSide(color: DocColors.muted, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(4 * sdp),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(8 * sdp, 2 * sdp, 8 * sdp, 0),
                    child: Text(
                      doctor.label,
                      key: Key('unit_doctor_name_${doctor.id}_$index'),
                      textAlign: TextAlign.center,
                      style: unitAppointmentText(
                        13,
                        sdp,
                        weight: FontWeight.w700,
                        color: DocColors.greenSea,
                      ),
                    ),
                  ),
                  Text(
                    'Total Appointment:  ${doctor.appointmentCount}',
                    textAlign: TextAlign.center,
                    style: unitAppointmentText(8, sdp, weight: FontWeight.w700),
                  ),
                  Text(
                    'Total Blank Schedule:  ${doctor.blankCount}',
                    textAlign: TextAlign.center,
                    style: unitAppointmentText(8, sdp, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Text(
              '-----------------------------------------------',
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              style: unitAppointmentText(
                10,
                sdp,
                weight: FontWeight.w700,
                family: 'OpenSans',
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(4 * sdp, 8 * sdp, 4 * sdp, 6 * sdp),
              child:
                  doctor.schedules.isEmpty
                      ? const SizedBox.shrink()
                      : _UnitScheduleStrip(
                        doctor: doctor,
                        index: index,
                        now: now,
                        sdp: sdp,
                        onCall: onCall,
                      ),
            ),
            if (doctor.schedules.isEmpty)
              Text(
                'No Schedule Found',
                key: Key('unit_doctor_no_schedule_${doctor.id}_$index'),
                textAlign: TextAlign.center,
                style: unitAppointmentText(10, sdp, weight: FontWeight.w700),
              ),
          ],
        ),
      ),
    ),
  );
}

class _UnitSlotMeasure {
  _UnitSlotMeasure(
    UnitAppointmentSlot slot,
    DateTime now,
    double sdp,
    TextScaler scaler,
    TextDirection direction, {
    bool callable = false,
  }) {
    final white = slot.completed(now), booked = slot.booked;
    final normal = white ? Colors.white : const Color(0xff6c6e6f);
    styles = [
      unitAppointmentText(
        11,
        sdp,
        weight: FontWeight.w700,
        color: white ? Colors.white : Colors.black,
      ),
      unitAppointmentText(
        10,
        sdp,
        weight: FontWeight.w600,
        color:
            white
                ? Colors.white
                : booked
                ? Colors.black
                : normal,
      ),
      unitAppointmentText(8, sdp, color: normal),
      unitAppointmentText(9, sdp, color: normal),
    ];
    texts = [
      slot.value('schedule_time'),
      booked ? slot.value('pat_name') : '',
      booked ? '(${slot.value('pat_code')})' : '',
      booked ? slot.value('pfn_fee_name') : '',
    ];
    messageStyle = unitAppointmentText(
      10,
      sdp,
      weight: FontWeight.w600,
      color: normal,
    );
    message = slot.message(now);
    double widest = 0, timeWidth = 0;
    for (var i = 0; i < texts.length; i++) {
      final painter = TextPainter(
        text: TextSpan(
          text: texts[i].isEmpty ? ' ' : texts[i],
          style: styles[i],
        ),
        textDirection: direction,
        textScaler: scaler,
      )..layout();
      widest = math.max(widest, painter.width);
      if (i == 0) timeWidth = painter.width;
      heights.add(painter.height);
      painter.dispose();
    }
    final painter = TextPainter(
      text: TextSpan(text: message, style: messageStyle),
      textDirection: direction,
      textScaler: scaler,
    )..layout();
    widest = math.max(widest, painter.width);
    painter.dispose();
    showCall = callable;
    if (callable) widest = math.max(widest, timeWidth + 36 * sdp);
    padding = 8 * sdp + (1 - math.cos(math.pi / 4)) * 8 * sdp;
    width = widest.ceilToDouble() + 2 * padding + 10 * sdp;
    height = heights.reduce((a, b) => a + b) + 5 + 2 * padding + 10 * sdp;
    background =
        white
            ? const Color(0xff57d2d0)
            : booked
            ? const Color(0xfff5f5f5)
            : const Color(0xffced6e0);
    elevation = booked ? 2 : 1.5;
  }
  late final List<TextStyle> styles;
  late final List<String> texts;
  late final TextStyle messageStyle;
  late final String message;
  late final double width, height, padding, elevation;
  late final Color background;
  late final bool showCall;
  final heights = <double>[];
}

class _UnitScheduleStrip extends StatefulWidget {
  const _UnitScheduleStrip({
    required this.doctor,
    required this.index,
    required this.now,
    required this.sdp,
    this.onCall,
  });
  final UnitAppointmentDoctor doctor;
  final int index;
  final DateTime now;
  final double sdp;
  final ValueChanged<UnitAppointmentSlot>? onCall;
  @override
  State<_UnitScheduleStrip> createState() => _UnitScheduleStripState();
}

class _UnitScheduleStripState extends State<_UnitScheduleStrip> {
  ScrollController? _scroll;
  List<_UnitSlotMeasure> _measures = const [];
  double? _sdp;
  TextScaler? _scaler;
  TextDirection? _direction;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measure();
  }

  @override
  void didUpdateWidget(_UnitScheduleStrip old) {
    super.didUpdateWidget(old);
    final changedDoctor = old.doctor != widget.doctor;
    final changedTime = widget.doctor.schedules.any(
      (slot) =>
          slot.completed(old.now) != slot.completed(widget.now) ||
          slot.message(old.now) != slot.message(widget.now),
    );
    _measure(
      force:
          changedDoctor ||
          changedTime ||
          (old.onCall == null) != (widget.onCall == null),
      preservePosition: !changedDoctor && changedTime,
    );
  }

  void _measure({bool force = false, bool preservePosition = false}) {
    final scaler = MediaQuery.textScalerOf(context),
        direction = Directionality.of(context);
    if (!force &&
        _sdp == widget.sdp &&
        _scaler == scaler &&
        _direction == direction) {
      return;
    }
    _sdp = widget.sdp;
    _scaler = scaler;
    _direction = direction;
    _measures = [
      for (final slot in widget.doctor.schedules)
        _UnitSlotMeasure(
          slot,
          widget.now,
          widget.sdp,
          scaler,
          direction,
          callable:
              widget.onCall != null &&
              slot.booked &&
              slot.value('pat_cell').isNotEmpty,
        ),
    ];
    final index = widget.doctor.initialScheduleIndex(widget.now);
    final offset = _measures.take(index).fold(0.0, (sum, m) => sum + m.width);
    if (_scroll == null) {
      _scroll = ScrollController(
        initialScrollOffset: offset,
        keepScrollOffset: false,
      );
    } else if (!preservePosition) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll!.hasClients) {
          _scroll!.jumpTo(offset.clamp(0.0, _scroll!.position.maxScrollExtent));
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _measures.map((m) => m.height).reduce(math.max),
    child: ListView.builder(
      key: Key('unit_doctor_slots_${widget.doctor.id}_${widget.index}'),
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      itemCount: _measures.length,
      itemExtentBuilder: (index, _) => _measures[index].width,
      itemBuilder: (_, index) {
        final m = _measures[index];
        return Padding(
          padding: EdgeInsets.all(5 * widget.sdp),
          child: Material(
            key: Key('unit_slot_${widget.doctor.id}_${widget.index}_$index'),
            color: m.background,
            elevation: m.elevation,
            borderRadius: BorderRadius.circular(8 * widget.sdp),
            child: Padding(
              padding: EdgeInsets.all(m.padding),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < m.texts.length; i++) ...[
                        if (i == 1) const SizedBox(height: 5),
                        SizedBox(
                          height: m.heights[i],
                          child: Text(
                            m.texts[i],
                            textAlign: TextAlign.center,
                            softWrap: false,
                            style: m.styles[i],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (m.message.isNotEmpty)
                    Positioned.fill(
                      top: 5,
                      child: Center(
                        child: Text(
                          m.message,
                          textAlign: TextAlign.center,
                          softWrap: false,
                          style: m.messageStyle,
                        ),
                      ),
                    ),
                  if (m.showCall)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Semantics(
                        button: true,
                        label:
                            'Call ${widget.doctor.schedules[index].value('pat_name')}',
                        child: Tooltip(
                          message: 'Call',
                          child: InkResponse(
                            key: Key(
                              'unit_slot_call_${widget.doctor.id}_${widget.index}_$index',
                            ),
                            onTap:
                                () => widget.onCall?.call(
                                  widget.doctor.schedules[index],
                                ),
                            child: _UnitIcon(
                              _UnitGlyph.phone,
                              size: 14 * widget.sdp,
                              color:
                                  widget.doctor.schedules[index].completed(
                                        widget.now,
                                      )
                                      ? Colors.white
                                      : DocColors.greenSea,
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
      },
    ),
  );
}

enum _UnitGlyph { clock, person, back, phone }

class _UnitIcon extends StatelessWidget {
  const _UnitIcon(this.glyph, {required this.size, required this.color});
  final _UnitGlyph glyph;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _UnitIconPainter(glyph, color),
  );
}

/// Original access_time_filled_24.xml, person_24.xml and arrow_back.xml paths.
class _UnitIconPainter extends CustomPainter {
  const _UnitIconPainter(this.glyph, this.color);
  final _UnitGlyph glyph;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final p = Path();
    switch (glyph) {
      case _UnitGlyph.clock:
        p.fillType = PathFillType.evenOdd;
        p.moveTo(11.99, 2);
        p.cubicTo(6.47, 2, 2, 6.48, 2, 12);
        p.cubicTo(2, 17.52, 6.47, 22, 11.99, 22);
        p.cubicTo(17.52, 22, 22, 17.52, 22, 12);
        p.cubicTo(22, 6.48, 17.52, 2, 11.99, 2);
        p.close();
        p.moveTo(15.29, 16.71);
        p.lineTo(11, 12.41);
        p.lineTo(11, 7);
        p.lineTo(13, 7);
        p.lineTo(13, 11.59);
        p.lineTo(16.71, 15.3);
        p.lineTo(15.29, 16.71);
        p.close();
      case _UnitGlyph.person:
        p.moveTo(12, 12);
        p.cubicTo(14.21, 12, 16, 10.21, 16, 8);
        p.cubicTo(16, 5.79, 14.21, 4, 12, 4);
        p.cubicTo(9.79, 4, 8, 5.79, 8, 8);
        p.cubicTo(8, 10.21, 9.79, 12, 12, 12);
        p.close();
        p.moveTo(12, 14);
        p.cubicTo(9.33, 14, 4, 15.34, 4, 18);
        p.lineTo(4, 20);
        p.lineTo(20, 20);
        p.lineTo(20, 18);
        p.cubicTo(20, 15.34, 14.67, 14, 12, 14);
        p.close();
      case _UnitGlyph.back:
        p.moveTo(11.67, 3.87);
        p.lineTo(9.9, 2.1);
        p.lineTo(0, 12);
        p.lineTo(9.9, 21.9);
        p.lineTo(11.67, 20.13);
        p.lineTo(3.54, 12);
        p.close();
      case _UnitGlyph.phone:
        p.moveTo(6.62, 10.79);
        p.cubicTo(8.06, 13.62, 10.38, 15.93, 13.21, 17.38);
        p.lineTo(15.41, 15.18);
        p.cubicTo(15.68, 14.91, 16.08, 14.82, 16.43, 14.94);
        p.cubicTo(17.55, 15.31, 18.76, 15.51, 20, 15.51);
        p.cubicTo(20.55, 15.51, 21, 15.96, 21, 16.51);
        p.lineTo(21, 20);
        p.cubicTo(21, 20.55, 20.55, 21, 20, 21);
        p.cubicTo(10.61, 21, 3, 13.39, 3, 4);
        p.cubicTo(3, 3.45, 3.45, 3, 4, 3);
        p.lineTo(7.5, 3);
        p.cubicTo(8.05, 3, 8.5, 3.45, 8.5, 4);
        p.cubicTo(8.5, 5.25, 8.7, 6.45, 9.07, 7.57);
        p.cubicTo(9.18, 7.92, 9.10, 8.31, 8.82, 8.59);
        p.lineTo(6.62, 10.79);
        p.close();
    }
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_UnitIconPainter old) =>
      old.glyph != glyph || old.color != color;
}
