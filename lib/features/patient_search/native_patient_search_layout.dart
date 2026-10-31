import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../appointments/doctor_schedule/native_appointment_timeline_card.dart';
import '../dynamic_prescription/native_dynamic_rx_controls.dart';
import 'patient_search_models.dart';

const patientSearchText = Color(0xff6c6e6f);

class NativePatientSearchShell extends StatelessWidget {
  const NativePatientSearchShell({
    super.key,
    this.title = "Patient's Prescription",
    required this.child,
    required this.onBack,
    this.compactHeader = false,
  });
  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final bool compactHeader;
  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context);
    return Scaffold(
      backgroundColor: DocColors.primary,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder:
              (_, bounds) => Column(
                children: [
                  SizedBox(
                    height:
                        compactHeader
                            ? 56
                            : math.max(56, bounds.maxHeight * .09),
                    child: Row(
                      children: [
                        SizedBox(width: m.d(12)),
                        SizedBox(
                          width: m.d(19),
                          height: 48,
                          child: IconButton(
                            key: const Key('patient_search_back'),
                            tooltip: 'Back',
                            padding: EdgeInsets.zero,
                            onPressed: onBack,
                            icon: CustomPaint(
                              size: Size.square(m.d(19)),
                              painter: const _PatientSearchBackPainter(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            title,
                            style: m.text(
                              14,
                              color: Colors.white,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                    ),
                  ),
                  SizedBox(height: compactHeader ? m.d(4) : 5),
                  Expanded(
                    child: Container(
                      key: const Key('patient_search_white_body'),
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        // Native MaterialCardView reserves horizontal corner clearance.
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          child: child,
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

/// Original arrow_back.xml geometry (rather than a platform back icon).
class _PatientSearchBackPainter extends CustomPainter {
  const _PatientSearchBackPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      Path()
        ..moveTo(11.67, 3.87)
        ..lineTo(9.9, 2.1)
        ..lineTo(0, 12)
        ..lineTo(9.9, 21.9)
        ..lineTo(11.67, 20.13)
        ..lineTo(3.54, 12)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_PatientSearchBackPainter old) => false;
}

class NativePatientSearchCard extends StatelessWidget {
  const NativePatientSearchCard({
    super.key,
    required this.patient,
    required this.dynamicMode,
    required this.onPrescription,
    required this.onProgress,
    required this.onAppointments,
    this.onCall,
  });
  final PatientSearchRow patient;
  final bool dynamicMode;
  final VoidCallback? onPrescription, onProgress, onAppointments, onCall;
  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context),
        large = MediaQuery.textScalerOf(context).scale(14) > 21;
    Widget button(String label, VoidCallback? onTap, String key) =>
        AppointmentOutlineButton(
          key: Key('${key}_${patient.historyId}'),
          label: label,
          sdp: appointmentScale(context),
          enabled: onTap != null,
          onPressed: onTap ?? () {},
        );
    Widget pair(Widget left, Widget right) =>
        large
            ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                left,
                Align(alignment: Alignment.centerRight, child: right),
              ],
            )
            : Row(
              children: [Expanded(child: left), SizedBox(width: m.d(7)), right],
            );
    final address = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (patient.area.isNotEmpty)
          Text(
            '(${patient.area})',
            style: m.text(9, color: patientSearchText, weight: FontWeight.w500),
          ),
        if (dynamicMode && patient.year.isNotEmpty)
          Text(
            '(${patient.year})',
            style: m.text(9, color: patientSearchText, weight: FontWeight.w500),
          ),
      ],
    );
    final progress = Row(
      children: [
        Text(
          'HP ',
          style: m.text(9, color: patientSearchText, weight: FontWeight.w600),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(m.d(2)),
            child: LinearProgressIndicator(
              key: Key('patient_search_hp_${patient.historyId}'),
              value: patient.progress / 10,
              minHeight: m.d(4),
              color: DocColors.greenSea,
              backgroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: dynamicMode ? m.d(4) : 5,
        vertical: dynamicMode ? m.d(11) : 15,
      ),
      child: Material(
        key: Key('patient_search_card_${patient.historyId}'),
        elevation: 1.5,
        color: DocColors.clouds,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(m.d(8)),
          side: const BorderSide(color: DocColors.greenSea),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('patient_search_prescription_${patient.historyId}'),
          onTap: onPrescription,
          child: Padding(
            padding: EdgeInsets.all(m.d(11)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder:
                      (_, bounds) => Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              patient.name,
                              style: m.text(
                                11,
                                color: Colors.black,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (onCall != null)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: m.d(8)),
                              child: _PatientCallButton(
                                key: Key(
                                  'patient_search_call_${patient.historyId}',
                                ),
                                label: 'Call ${patient.name}',
                                onPressed: onCall!,
                                radius: m.d(8),
                              ),
                            ),
                          if (patient.area.isNotEmpty ||
                              dynamicMode && patient.year.isNotEmpty) ...[
                            SizedBox(width: m.d(7)),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: bounds.maxWidth * .4,
                              ),
                              child: address,
                            ),
                          ],
                        ],
                      ),
                ),
                pair(
                  Text(
                    patient.code,
                    style: m.text(
                      10,
                      color: patientSearchText,
                      weight: FontWeight.w600,
                    ),
                  ),
                  button(
                    'APPOINTMENT VIEW',
                    onAppointments,
                    'patient_search_appointments',
                  ),
                ),
                if (patient.genderAge.isNotEmpty)
                  Text(
                    patient.genderAge,
                    style: m.text(
                      10,
                      color: patientSearchText,
                      weight: FontWeight.w600,
                    ),
                  ),
                if (patient.progress > 0)
                  pair(
                    progress,
                    button(
                      'VIEW PROGRESS',
                      onProgress,
                      'patient_search_progress',
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 3.0),
                    child: Text(
                      'No Progress Found',
                      style: m.text(
                        9,
                        color: patientSearchText,
                        weight: FontWeight.w600,
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
}

/// phone_24.xml, with the native 32dp button and 6dp Material insets.
class _PatientCallButton extends StatelessWidget {
  const _PatientCallButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.radius,
  });
  final String label;
  final VoidCallback onPressed;
  final double radius;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    child: ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: const BorderSide(color: DocColors.greenSea),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
              child: const CustomPaint(
                size: Size.square(15),
                painter: _PatientCallPainter(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PatientCallPainter extends CustomPainter {
  const _PatientCallPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final path =
        Path()
          ..moveTo(6.62, 10.79)
          ..relativeCubicTo(1.44, 2.83, 3.76, 5.14, 6.59, 6.59)
          ..relativeLineTo(2.2, -2.2)
          ..relativeCubicTo(.27, -.27, .67, -.36, 1.02, -.24)
          ..relativeCubicTo(1.12, .37, 2.33, .57, 3.57, .57)
          ..relativeCubicTo(.55, 0, 1, .45, 1, 1)
          ..lineTo(21, 20)
          ..relativeCubicTo(0, .55, -.45, 1, -1, 1)
          ..relativeCubicTo(-9.39, 0, -17, -7.61, -17, -17)
          ..relativeCubicTo(0, -.55, .45, -1, 1, -1)
          ..relativeLineTo(3.5, 0)
          ..relativeCubicTo(.55, 0, 1, .45, 1, 1)
          ..relativeCubicTo(0, 1.25, .2, 2.45, .57, 3.57)
          ..relativeCubicTo(.11, .35, .03, .74, -.25, 1.02)
          ..relativeLineTo(-2.2, 2.2)
          ..close();
    canvas.drawPath(path, Paint()..color = DocColors.greenSea);
  }

  @override
  bool shouldRepaint(_PatientCallPainter oldDelegate) => false;
}
