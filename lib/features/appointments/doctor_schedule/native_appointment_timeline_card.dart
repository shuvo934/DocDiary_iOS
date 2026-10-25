import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import 'doctor_appointment_models.dart';

TextStyle appointmentText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = const Color(0xff6c6e6f),
  String family = 'Poppins',
}) => TextStyle(
  fontFamily: family,
  fontFamilyFallback: const ['DocDiaryBengali'],
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1.5,
);
double appointmentScale(BuildContext context) {
  final width = MediaQuery.sizeOf(context).shortestSide;
  return width < 300 ? 1 : (width / 30).floor() * 30 / 300;
}

class NativeAppointmentTimelineCard extends StatelessWidget {
  const NativeAppointmentTimelineCard({
    super.key,
    required this.view,
    required this.index,
    required this.first,
    required this.last,
    required this.onAction,
    this.enabled = true,
  });
  final DoctorAppointmentPresentation view;
  final int index;
  final bool first, last, enabled;
  final ValueChanged<DoctorAppointmentAction> onAction;
  @override
  Widget build(BuildContext context) {
    final sdp = appointmentScale(context), tone = view.tone;
    final white =
        tone == DoctorAppointmentTone.completed ||
        tone == DoctorAppointmentTone.missed;
    final color = white ? Colors.white : const Color(0xff6c6e6f);
    final primaryText =
        white
            ? Colors.white
            : !view.booked || !view.timed
            ? color
            : Colors.black;
    final background = switch (tone) {
      DoctorAppointmentTone.empty => const Color(0xffced6e0),
      DoctorAppointmentTone.upcoming => const Color(0xfff5f5f5),
      DoctorAppointmentTone.completed => const Color(0xff57d2d0),
      DoctorAppointmentTone.awaitingAvail => const Color(0xffedf8f8),
      DoctorAppointmentTone.missed => const Color(0xffcf6a87),
    };
    final markerColor = switch (tone) {
      DoctorAppointmentTone.empty => const Color(0xff95a5a6),
      DoctorAppointmentTone.upcoming => DocColors.clouds,
      DoctorAppointmentTone.completed => DocColors.primary,
      DoctorAppointmentTone.awaitingAvail => const Color(0xffc8f0f0),
      DoctorAppointmentTone.missed => const Color(0xffcf6a87),
    };
    final row = view.row;
    Widget action(
      DoctorAppointmentAction value,
      String label, {
      bool full = false,
    }) => AppointmentOutlineButton(
      key: Key('doctor_appointment_${index}_${value.name}'),
      label: label,
      sdp: sdp,
      full: full,
      minWidth: value == DoctorAppointmentAction.avail ? 50 * sdp : 0,
      enabled: enabled,
      onPressed: () => onAction(value),
    );
    final actions = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        if (view.showAvail) action(DoctorAppointmentAction.avail, 'AVAIL'),
        if (view.availMessage != null)
          Text(
            view.availMessage!,
            style: appointmentText(
              8 * sdp,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
        if (view.showPrescription)
          action(view.prescriptionAction, view.prescriptionLabel),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 22,
              child: CustomPaint(
                painter: _Timeline(first: first, last: last),
                child: Center(
                  child: Icon(
                    tone == DoctorAppointmentTone.completed
                        ? Icons.check_circle
                        : tone == DoctorAppointmentTone.missed
                        ? Icons.warning
                        : Icons.circle,
                    key: Key('doctor_appointment_marker_$index'),
                    size: 22,
                    color: markerColor,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                key: Key('doctor_appointment_card_$index'),
                color: background,
                elevation:
                    tone == DoctorAppointmentTone.empty
                        ? 1
                        : tone == DoctorAppointmentTone.upcoming
                        ? (view.timed ? 4 : 1)
                        : 3,
                margin: const EdgeInsets.fromLTRB(10, 15, 5, 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8 * sdp),
                  side:
                      tone == DoctorAppointmentTone.upcoming
                          ? const BorderSide(color: Color(0xff95a5a6), width: 2)
                          : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            row.value('schedule_time'),
                            key: Key('doctor_appointment_time_$index'),
                            style: appointmentText(
                              11 * sdp,
                              weight: FontWeight.w700,
                              color: white ? Colors.white : Colors.black,
                            ),
                          ),
                          if (view.showAvail ||
                              view.showPrescription ||
                              view.availMessage != null)
                            actions,
                        ],
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 3 * sdp,
                        children: [
                          Text(
                            view.patientLabel,
                            key: Key('doctor_appointment_patient_$index'),
                            style: appointmentText(
                              10 * sdp,
                              weight: FontWeight.w600,
                              color: primaryText,
                            ),
                          ),
                          if (view.booked)
                            Text(
                              '(${row.value('pat_code')})',
                              style: appointmentText(8 * sdp, color: color),
                            ),
                        ],
                      ),
                      if (view.booked) ...[
                        Text(
                          '${row.value('pat_gender')}  •  ${row.value('pat_age_now')}',
                          style: appointmentText(9 * sdp, color: color),
                        ),
                        Text(
                          row.value('pfn_fee_name'),
                          style: appointmentText(9 * sdp, color: color),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child:
                                  view.hasProgress
                                      ? Row(
                                        children: [
                                          Text(
                                            'HP ',
                                            style: appointmentText(
                                              9 * sdp,
                                              weight: FontWeight.w600,
                                              color: color,
                                            ),
                                          ),
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(8),
                                              ),
                                              child: LinearProgressIndicator(
                                                key: Key(
                                                  'doctor_appointment_hp_$index',
                                                ),
                                                value: row.progressFraction,
                                                minHeight: 4 * sdp,
                                                color: DocColors.greenSea,
                                                backgroundColor: Colors.white,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 4 * sdp),
                                        ],
                                      )
                                      : Text(
                                        'No Progress Found',
                                        style: appointmentText(
                                          9 * sdp,
                                          weight: FontWeight.w600,
                                          color: color,
                                        ),
                                      ),
                            ),
                            if (view.progressChecked)
                              Padding(
                                padding: EdgeInsets.only(right: 4 * sdp),
                                child: Icon(
                                  Icons.check_circle,
                                  key: Key(
                                    'doctor_appointment_progress_check_$index',
                                  ),
                                  size: 11 * sdp,
                                  color: DocColors.greenSea,
                                ),
                              ),
                            if (view.showProgress)
                              action(
                                DoctorAppointmentAction.progress,
                                view.progressLabel,
                              ),
                          ],
                        ),
                        if (view.showHistory)
                          action(
                            DoctorAppointmentAction.history,
                            'Appointment History',
                            full: true,
                          ),
                        if (view.showVideoNotice)
                          Padding(
                            padding: EdgeInsets.only(top: 5 * sdp),
                            child: Text(
                              'Video Call Link will be available before 10 mins of Schedule Time',
                              key: Key(
                                'doctor_appointment_video_notice_$index',
                              ),
                              style: appointmentText(
                                9 * sdp,
                                color: DocColors.greenSea,
                              ).copyWith(
                                decoration: TextDecoration.underline,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        if (view.showVideo)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: TextButton.icon(
                                key: Key('doctor_appointment_${index}_video'),
                                onPressed:
                                    enabled
                                        ? () => onAction(
                                          DoctorAppointmentAction.video,
                                        )
                                        : null,
                                style: TextButton.styleFrom(
                                  backgroundColor: DocColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      8 * sdp,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.videocam, size: 17),
                                label: Text(
                                  'VIDEO CALL',
                                  style: appointmentText(
                                    8 * sdp,
                                    family: 'OpenSans',
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
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

class AppointmentOutlineButton extends StatelessWidget {
  const AppointmentOutlineButton({
    super.key,
    required this.label,
    required this.sdp,
    required this.onPressed,
    this.enabled = true,
    this.full = false,
    this.fontSize = 7,
    this.allCaps = true,
    this.minWidth = 0,
    this.layoutHeight = 25,
  });
  final String label;
  final double sdp, fontSize, minWidth, layoutHeight;
  final VoidCallback onPressed;
  final bool enabled, full, allCaps;
  @override
  Widget build(BuildContext context) {
    // Android's 25sdp MaterialButton includes a 6dp top/bottom inset.
    // Match its visible outline while keeping that spacing between rows.
    final child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: enabled ? onPressed : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: DocColors.greenSea,
            disabledForegroundColor: DocColors.greenSea,
            padding: const EdgeInsets.fromLTRB(16, 3, 16, 1),
            minimumSize: Size(
              minWidth,
              (layoutHeight * sdp - 12).clamp(0, double.infinity),
            ),
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: const BorderSide(color: DocColors.greenSea),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8 * sdp),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 1.0),
            child: Text(
              allCaps ? label.toUpperCase() : label,
              textAlign: TextAlign.center,
              style: appointmentText(
                fontSize * sdp,
                color: DocColors.greenSea,
              ).copyWith(letterSpacing: fontSize * sdp * .089),
            ),
          ),
        ),
      ),
    );
    return full ? SizedBox(width: double.infinity, child: child) : child;
  }
}

class _Timeline extends CustomPainter {
  const _Timeline({required this.first, required this.last});
  final bool first, last;
  @override
  void paint(Canvas canvas, Size size) {
    final p =
        Paint()
          ..color = DocColors.primary
          ..strokeWidth = 2;
    final middle = size.height / 2, x = size.width / 2;
    if (!first) canvas.drawLine(Offset(x, 0), Offset(x, middle - 11), p);
    if (!last) {
      canvas.drawLine(Offset(x, middle + 11), Offset(x, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_Timeline old) => old.first != first || old.last != last;
}
