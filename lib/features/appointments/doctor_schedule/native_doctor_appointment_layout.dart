import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';
import 'doctor_appointment_models.dart';
import 'native_appointment_calendar.dart';
import 'native_appointment_timeline_card.dart';

class NativeDoctorAppointmentLayout extends StatelessWidget {
  const NativeDoctorAppointmentLayout({
    super.key,
    required this.window,
    required this.selected,
    required this.now,
    required this.onBack,
    required this.onSelected,
    required this.onMonth,
    required this.onAction,
    this.features,
    this.rows = const [],
    this.waiting = false,
    this.enabled = true,
    this.message,
  });
  final DoctorAppointmentWindow window;
  final DateTime selected, now;
  final DoctorAppointmentFeatures? features;
  final List<DoctorAppointmentRow> rows;
  final bool waiting, enabled;
  final String? message;
  final VoidCallback onBack;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<int> onMonth;
  final void Function(DoctorAppointmentAction, DoctorAppointmentRow?) onAction;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context), sdp = appointmentScale(context);
    final active = enabled && !waiting && message == null, flags = features;
    Widget month(int delta, IconData icon) => SizedBox(
      width: 48,
      height: 32,
      child: Material(
        color:
            window.canMove(selected, delta)
                ? DocColors.primary
                : const Color(0xffb2bec3),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          key: Key(
            delta < 0
                ? 'doctor_appointment_previous'
                : 'doctor_appointment_next',
          ),
          onTap:
              active && window.canMove(selected, delta)
                  ? () => onMonth(delta)
                  : null,
          child: Icon(icon, size: 24, color: Colors.white),
        ),
      ),
    );
    final controls = ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 10 * sdp,
              vertical: 5 * sdp,
            ),
            child: Row(
              children: [
                month(-1, Icons.chevron_left),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5 * sdp),
                    child: Text(
                      DoctorAppointmentWindow.label(selected),
                      key: const Key('doctor_appointment_month'),
                      textAlign: TextAlign.center,
                      style: appointmentText(
                        12 * sdp,
                        weight: FontWeight.w700,
                        color: DocColors.greenSea,
                      ),
                    ),
                  ),
                ),
                month(1, Icons.chevron_right),
              ],
            ),
          ),
          NativeAppointmentCalendar(
            window: window,
            selected: selected,
            enabled: active,
            onSelected: onSelected,
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
                    52.0,
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
                        key: const Key('doctor_appointment_back'),
                        tooltip: 'Back',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 44,
                        ),
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
                          'Appointment Schedule',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appointmentText(
                            13 * sdp,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (flags?.dynamicPrescription ?? false) ...[
                        SizedBox(width: 4 * sdp),
                        AppointmentOutlineButton(
                          key: const Key('doctor_appointment_walk_in'),
                          label: 'Walk-in Rx',
                          allCaps: false,
                          fontSize: 9,
                          sdp: sdp,
                          enabled: active,
                          onPressed:
                              () => onAction(
                                DoctorAppointmentAction.walkIn,
                                null,
                              ),
                        ),
                      ],
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
                          key: const Key('doctor_appointment_scroll'),
                          slivers: [
                            if (media.size.height - media.padding.vertical >
                                    450 &&
                                media.textScaler.scale(12) <= 18)
                              PinnedHeaderSliver(child: controls)
                            else
                              SliverToBoxAdapter(child: controls),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 10),
                            ),
                            if (message != null)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    message!,
                                    textAlign: TextAlign.center,
                                    style: appointmentText(12 * sdp),
                                  ),
                                ),
                              )
                            else if (!waiting && flags != null && rows.isEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    'No Schedule Found',
                                    key: const Key('doctor_appointment_empty'),
                                    textAlign: TextAlign.center,
                                    style: appointmentText(
                                      12 * sdp,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                            else if (flags != null)
                              SliverList.builder(
                                itemCount: rows.length,
                                itemBuilder:
                                    (context, index) =>
                                        NativeAppointmentTimelineCard(
                                          view: rows[index].present(flags, now),
                                          index: index,
                                          first: index == 0,
                                          last: index == rows.length - 1,
                                          enabled: active,
                                          onAction:
                                              (action) =>
                                                  onAction(action, rows[index]),
                                        ),
                              ),
                          ],
                        ),
                        if (waiting)
                          const Positioned.fill(
                            child: Stack(
                              children: [
                                ModalBarrier(
                                  dismissible: false,
                                  color: Color(0x66ffffff),
                                ),
                                Center(
                                  child: CircularProgressIndicator(
                                    key: Key('doctor_appointment_loading'),
                                  ),
                                ),
                              ],
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
