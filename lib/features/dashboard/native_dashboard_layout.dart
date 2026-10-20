import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../management/management_access.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/native_dates.dart';
import '../auth/profile_repository.dart';
import 'dashboard_repository.dart';
import 'meeting_countdown.dart';
import 'native_meeting_panel.dart';
import 'native_dashboard_format.dart';
import 'native_dashboard_icons.dart';

enum DashboardDestination {
  profile,
  appointment,
  leave,
  patients,
  payment,
  management,
  unitAppointment,
  allAppointment,
  reports,
  changePhoto,
}

class DashboardMenuItem {
  const DashboardMenuItem(this.destination, this.label);
  final DashboardDestination destination;
  final String label;
}

/// Visibility comes from DocDashboard.updateInterface/updateAdminInterface.
List<DashboardMenuItem> nativeDashboardMenu(AccountProfile profile) {
  if (profile.isDoctor) {
    return const [
      DashboardMenuItem(DashboardDestination.profile, 'Profile'),
      DashboardMenuItem(DashboardDestination.appointment, 'Appointment'),
      DashboardMenuItem(DashboardDestination.leave, 'Block Time'),
      DashboardMenuItem(DashboardDestination.patients, 'Patient'),
    ];
  }
  final managementAccess = ManagementAccess(profile);
  final access = managementAccess.role;
  final payment =
      access == 2
          ? profile.value('hr_payment_active') == '1'
          : access == 3
          ? profile.value('acc_payment_active') == '1'
          : true;
  final appointment =
      access == 2
          ? profile.value('hr_appointment_active') == '1'
          : access == 3
          ? profile.value('acc_appointment_active') == '1'
          : true;
  final management = managementAccess.title;
  return [
    if (payment)
      const DashboardMenuItem(DashboardDestination.payment, 'Payment'),
    if (appointment)
      const DashboardMenuItem(DashboardDestination.appointment, 'Appointment'),
    const DashboardMenuItem(DashboardDestination.patients, 'Patient'),
    DashboardMenuItem(DashboardDestination.management, management),
  ];
}

double _sdp(BuildContext context) {
  final width = MediaQuery.sizeOf(context).shortestSide;
  return width < 300 ? 1 : (width / 30).floor() * 30 / 300;
}

TextStyle _text(
  String family,
  double size, {
  Color color = Colors.black,
  FontWeight weight = FontWeight.normal,
}) => TextStyle(
  inherit: false,
  textBaseline: TextBaseline.alphabetic,
  fontFamily: family,
  fontSize: size,
  fontWeight: weight,
  color: color,
  fontVariations:
      family == 'OpenSans'
          ? const [ui.FontVariation('wght', 700)]
          : family == 'Archivo'
          ? const [ui.FontVariation('wght', 700), ui.FontVariation('wdth', 100)]
          : null,
);

/// Step 1: activity_doc_dashboard + doc_dashboard_extra_layout summary UI.
/// Doctor countdown is integrated; admin charts remain a separate checkpoint.
class NativeDashboardLayout extends StatelessWidget {
  const NativeDashboardLayout({
    super.key,
    required this.profile,
    required this.summary,
    required this.period,
    required this.now,
    required this.loading,
    required this.showSwitch,
    required this.onSwitch,
    required this.onLogout,
    required this.onPeriod,
    required this.onRefresh,
    required this.onDestination,
    this.picture,
    this.error,
    this.countdown,
    this.meetingRefreshing = false,
    this.adminOverview,
  });

  final AccountProfile profile;
  final DashboardSummary? summary;
  final SummaryPeriod period;
  final DateTime now;
  final bool loading;
  final bool showSwitch;
  final VoidCallback onSwitch;
  final VoidCallback onLogout;
  final ValueChanged<SummaryPeriod> onPeriod;
  final Future<void> Function() onRefresh;
  final ValueChanged<DashboardDestination> onDestination;
  final Uint8List? picture;
  final String? error;
  final MeetingSnapshot? countdown;
  final bool meetingRefreshing;
  final Widget? adminOverview;
  @override
  Widget build(BuildContext context) {
    final sdp = _sdp(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: DocColors.clouds,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: DocColors.primary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: meetingRefreshing ? Colors.white : DocColors.clouds,
        body:
            meetingRefreshing
                ? const Center(
                  child: CircularProgressIndicator(
                    key: Key('dashboard_meeting_refreshing'),
                    color: DocColors.primary,
                    strokeWidth: 4,
                  ),
                )
                : SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      _Header(
                        sdp: sdp,
                        showSwitch: showSwitch,
                        onSwitch: onSwitch,
                        onLogout: onLogout,
                      ),
                      Expanded(
                        child: CustomPaint(
                          painter: const _DashboardTopCornerShadowPainter(),
                          child: Material(
                            key: const Key('dashboard_white_surface'),
                            color: Colors.white,
                            elevation: 0,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: RefreshIndicator(
                              color: DocColors.primary,
                              onRefresh: onRefresh,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 2.0,
                                  left: 6.0,
                                  right: 6.0,
                                  bottom: 6.0,
                                ),
                                child: SingleChildScrollView(
                                  key: const Key('dashboard_scroll'),
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _Identity(
                                        profile: profile,
                                        now: now,
                                        sdp: sdp,
                                        picture: picture,
                                        onDestination: onDestination,
                                      ),
                                      if (profile.isDoctor)
                                        _DoctorActions(
                                          profile: profile,
                                          sdp: sdp,
                                          onDestination: onDestination,
                                        ),
                                      if (profile.isDoctor && summary != null)
                                        NativeMeetingPanel(
                                          summary: summary!,
                                          countdown: countdown,
                                          now: now,
                                          sdp: sdp,
                                        ),
                                      _PeriodTabs(
                                        period: period,
                                        loading: loading,
                                        sdp: sdp,
                                        onPeriod: onPeriod,
                                      ),
                                      if (loading)
                                        Padding(
                                          padding: EdgeInsets.all(48 * sdp),
                                          child: const Center(
                                            child: SizedBox.square(
                                              dimension: 40,
                                              child: CircularProgressIndicator(
                                                color: DocColors.primary,
                                                strokeWidth: 4,
                                              ),
                                            ),
                                          ),
                                        )
                                      else if (error != null)
                                        _LoadError(
                                          message: error!,
                                          sdp: sdp,
                                          onRetry: onRefresh,
                                        )
                                      else if (summary != null) ...[
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            6 * sdp,
                                            (profile.isDoctor ? 10 : 8) * sdp +
                                                5,
                                            6 * sdp,
                                            0,
                                          ),
                                          child: Text(
                                            nativeDashboardDate(period, now),
                                            key: const Key(
                                              'dashboard_date_range',
                                            ),
                                            style: _text(
                                              'Archivo',
                                              12 * sdp,
                                              color: const Color(0xFF6C6E6F),
                                              weight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        if (profile.isDoctor)
                                          _DoctorSummary(
                                            summary: summary!,
                                            sdp: sdp,
                                          )
                                        else
                                          _AdminSummary(
                                            summary: summary!,
                                            sdp: sdp,
                                          ),
                                      ],
                                      if (!profile.isDoctor &&
                                          summary != null &&
                                          adminOverview != null)
                                        adminOverview!,
                                      const SizedBox(height: 16),
                                    ],
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
        bottomNavigationBar:
            meetingRefreshing
                ? null
                : ColoredBox(
                  color: Colors.white,
                  child: _BottomMenu(
                    profile: profile,
                    sdp: sdp,
                    onDestination: onDestination,
                  ),
                ),
      ),
    );
  }
}

/// Paint only the two rounded top arcs. The white surface itself keeps zero
/// elevation, so there is no shadow along the center, sides or bottom edge.
class _DashboardTopCornerShadowPainter extends CustomPainter {
  const _DashboardTopCornerShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 30.0;
    const blur = 3.5;
    final topEdge =
        Path()
          ..moveTo(0, radius)
          ..arcToPoint(
            const Offset(radius, 0),
            radius: const Radius.circular(radius),
          )
          ..lineTo(size.width - radius, 0)
          ..arcToPoint(
            Offset(size.width, radius),
            radius: const Radius.circular(radius),
          );

    final shadow =
        Paint()
          ..color = const Color(0x33000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, blur);

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, -blur * 3, size.width, radius));
    canvas.drawPath(topEdge, shadow);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DashboardTopCornerShadowPainter oldDelegate) =>
      false;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.sdp,
    required this.showSwitch,
    required this.onSwitch,
    required this.onLogout,
  });
  final double sdp;
  final bool showSwitch;
  final VoidCallback onSwitch;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(12 * sdp),
    child: Row(
      children: [
        Image.asset(
          'assets/images/doc_diary_default.png',
          width: 22 * sdp,
          height: 22 * sdp,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, right: 5),
            child: Text(
              'Dashboard',
              style: _text('Poppins', 14 * sdp, weight: FontWeight.w700),
            ),
          ),
        ),
        if (showSwitch) ...[
          _IconTap(
            key: const Key('switch_account'),
            label: 'Switch user',
            onTap: onSwitch,
            child: Image.asset(
              'assets/images/switch_user_icon.png',
              width: 18 * sdp,
              height: 18 * sdp,
              color: DocColors.greenSea,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
          SizedBox(width: 12 * sdp),
        ],
        _IconTap(
          key: const Key('logout_button'),
          label: 'Log Out',
          onTap: onLogout,
          child: NativeDashboardIcon(
            NativeDashboardGlyph.logout,
            size: 18 * sdp,
            color: DocColors.greenSea,
          ),
        ),
      ],
    ),
  );
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.profile,
    required this.now,
    required this.sdp,
    required this.picture,
    required this.onDestination,
  });
  final AccountProfile profile;
  final DateTime now;
  final double sdp;
  final Uint8List? picture;
  final ValueChanged<DashboardDestination> onDestination;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Image.asset(
      profile.isDoctor
          ? 'assets/images/doctor.png'
          : 'assets/images/profile.png',
      fit: BoxFit.cover,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(7 * sdp, 12 * sdp, 7 * sdp, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting(now),
                  key: const Key('dashboard_greeting'),
                  style: _text(
                    'Poppins',
                    13 * sdp,
                    color: DocColors.greenSea,
                    weight: FontWeight.w700,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 2 * sdp, bottom: 4 * sdp),
                  child: Text(
                    profile.displayName,
                    key: const Key('account_name'),
                    style: _text('Poppins', 11 * sdp, weight: FontWeight.w500),
                  ),
                ),
                if (profile.centerName.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 4 * sdp),
                    child: Text(
                      '(${profile.centerName})',
                      key: const Key('center_name'),
                      style: _text(
                        'Poppins',
                        9 * sdp,
                        color: const Color(0xFF2196F3),
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 50 * sdp,
            height: 50 * sdp,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Material(
                  key: const Key('dashboard_profile_picture'),
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: Container(
                    width: 42 * sdp,
                    height: 42 * sdp,
                    padding: const EdgeInsets.all(1),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: DocColors.greenSea,
                    ),
                    child: ClipOval(
                      child:
                          picture == null
                              ? fallback()
                              : Image.memory(
                                picture!,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder:
                                    (context, error, stack) => fallback(),
                              ),
                    ),
                  ),
                ),
                if (!profile.isDoctor)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _IconTap(
                      key: const Key('dashboard_change_photo'),
                      label: 'Change profile picture',
                      onTap:
                          () => onDestination(DashboardDestination.changePhoto),
                      child: NativeDashboardIcon(
                        NativeDashboardGlyph.camera,
                        size: 12 * sdp,
                        color: DocColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorActions extends StatelessWidget {
  const _DoctorActions({
    required this.profile,
    required this.sdp,
    required this.onDestination,
  });
  final AccountProfile profile;
  final double sdp;
  final ValueChanged<DashboardDestination> onDestination;

  Widget _button(String label, DashboardDestination destination) => Padding(
    padding: EdgeInsets.fromLTRB(3 * sdp, 6 * sdp, 4 * sdp, 4 * sdp),
    child: SizedBox(
      height: 48,
      child: Align(
        alignment: Alignment.center,
        widthFactor: 1,
        child: ElevatedButton(
          key: Key('dashboard_${destination.name}'),
          onPressed: () => onDestination(destination),
          style: ElevatedButton.styleFrom(
            backgroundColor: DocColors.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            minimumSize: const Size(88, 36),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15 * sdp),
            ),
            textStyle: _text(
              'OpenSans',
              8 * sdp,
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
          child: Text(label.toUpperCase(), textAlign: TextAlign.center),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (profile.value('doc_manager_flag') == '1') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: _button('Report Manager', DashboardDestination.reports),
          ),
          Flexible(
            child: _button(
              'All Appointment',
              DashboardDestination.allAppointment,
            ),
          ),
        ],
      );
    }
    if (profile.value('doc_deptd_head_flag') == '1') {
      return Align(
        alignment: Alignment.centerRight,
        child: _button(
          'Unit Appointment',
          DashboardDestination.unitAppointment,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({
    required this.period,
    required this.loading,
    required this.sdp,
    required this.onPeriod,
  });
  final SummaryPeriod period;
  final bool loading;
  final double sdp;
  final ValueChanged<SummaryPeriod> onPeriod;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(3, 15, 3, 0),
    child: Row(
      children: [
        for (final item in SummaryPeriod.values)
          Expanded(
            child: Semantics(
              selected: period == item,
              button: true,
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient:
                        period == item
                            ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [DocColors.primary, DocColors.greenSea],
                            )
                            : null,
                  ),
                  child: InkWell(
                    key: Key('dashboard_period_${item.name}'),
                    borderRadius: BorderRadius.circular(40),
                    onTap: loading ? null : () => onPeriod(item),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              item.label.toUpperCase(),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _text(
                                'PatuaOne',
                                9 * sdp,
                                color:
                                    period == item
                                        ? Colors.white
                                        : Colors.black54,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        // if (period == item)
                        //   const Positioned(
                        //     left: 0,
                        //     right: 0,
                        //     bottom: 0,
                        //     child: SizedBox(
                        //       height: 2,
                        //       child: ColoredBox(color: Colors.white),
                        //     ),
                        //   ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _DoctorSummary extends StatelessWidget {
  const _DoctorSummary({required this.summary, required this.sdp});
  final DashboardSummary summary;
  final double sdp;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: EdgeInsets.only(top: 5 * sdp),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'TOTAL SCHEDULE',
                value: summary.values['TOTAL SCHEDULE'] ?? '',
                sdp: sdp,
                colors: const [Color(0xFF50C2C0), Color(0xFF82CCDD)],
              ),
            ),
            Expanded(
              child: _SummaryCard(
                label: 'BLOCKED SCHEDULE',
                value: summary.values['BLOCKED SCHEDULE'] ?? '',
                sdp: sdp,
                colors: const [Color(0xFFB2BEC3), Color(0xFFB2BEC3)],
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: EdgeInsets.only(top: 5 * sdp, left: 5 * sdp),
        child: Text(
          'Appointment',
          style: _text(
            'Poppins',
            12 * sdp,
            color: DocColors.greenSea,
            weight: FontWeight.w700,
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.only(top: 5 * sdp),
        child: Row(
          children: [
            Expanded(
              child: _AppointmentCard(
                label: 'TOTAL',
                value: summary.values['TOTAL'] ?? '',
                color: const Color(0xFFFFBE76),
                sdp: sdp,
              ),
            ),
            Expanded(
              child: _AppointmentCard(
                label: 'COMPLETED',
                value: summary.values['COMPLETED'] ?? '',
                color: DocColors.primary,
                sdp: sdp,
              ),
            ),
            Expanded(
              child: _AppointmentCard(
                label: 'REMAINING',
                value: summary.values['REMAINING'] ?? '',
                color: DocColors.muted,
                sdp: sdp,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _AdminSummary extends StatelessWidget {
  const _AdminSummary({required this.summary, required this.sdp});
  final DashboardSummary summary;
  final double sdp;

  Widget _heading(String label) => Padding(
    padding: EdgeInsets.only(top: 10 * sdp, left: 5 * sdp),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: _text(
        'Poppins',
        12 * sdp,
        color: DocColors.greenSea,
        weight: FontWeight.w700,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('Appointment'),
      Padding(
        padding: EdgeInsets.only(top: 5 * sdp),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'TOTAL',
                value: summary.values['TOTAL APPOINTMENT'] ?? '',
                sdp: sdp,
                colors: const [Color(0xFF50C2C0), Color(0xFF82CCDD)],
              ),
            ),
            Expanded(
              child: _SummaryCard(
                label: 'CANCELED',
                value: summary.values['CANCELED APPOINTMENT'] ?? '',
                sdp: sdp,
                colors: const [Color(0xFFB2BEC3), Color(0xFFB2BEC3)],
              ),
            ),
          ],
        ),
      ),
      _heading('Payment'),
      Padding(
        padding: EdgeInsets.only(top: 5 * sdp),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'RECEIVE',
                value: nativeDashboardMoney(
                  summary.values['PAYMENT RECEIVED'] ?? '',
                ),
                sdp: sdp,
                valueSize: 18,
                colors: const [Color(0xFF50C2C0), Color(0xFF82CCDD)],
              ),
            ),
            Expanded(
              child: _SummaryCard(
                label: 'RETURN',
                value: nativeDashboardMoney(
                  summary.values['PAYMENT RETURNED'] ?? '',
                ),
                sdp: sdp,
                valueSize: 18,
                colors: const [Color(0xFFFDA000), Color(0xFFFFBF40)],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.sdp,
    required this.colors,
    this.valueSize = 25,
  });
  final String label;
  final String value;
  final double sdp;
  final List<Color> colors;
  final double valueSize;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(5),
    child: Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 5 * sdp),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: _text(
                    'Poppins',
                    10 * sdp,
                    color: Colors.white,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                value,
                key: Key('dashboard_value_$label'),
                textAlign: TextAlign.center,
                style: _text('Baloo', valueSize * sdp, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.label,
    required this.value,
    required this.color,
    required this.sdp,
  });
  final String label;
  final String value;
  final Color color;
  final double sdp;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(5),
    child: Material(
      elevation: 3,
      color: color,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 75 * sdp),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/background_png_dot.png',
                fit: BoxFit.fill,
                color: const Color(0x80ECF0F1),
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 5 * sdp),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: _text(
                        'Poppins',
                        11 * sdp,
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    key: Key('dashboard_value_$label'),
                    textAlign: TextAlign.center,
                    style: _text('Baloo', 25 * sdp, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BottomMenu extends StatelessWidget {
  const _BottomMenu({
    required this.profile,
    required this.sdp,
    required this.onDestination,
  });
  final AccountProfile profile;
  final double sdp;
  final ValueChanged<DashboardDestination> onDestination;

  Widget _icon(DashboardDestination destination) {
    final size = 17 * sdp;
    if (destination == DashboardDestination.patients) {
      return Image.asset(
        'assets/images/patient_icon.png',
        width: size,
        height: size,
        color: Colors.white,
        colorBlendMode: BlendMode.srcIn,
      );
    }
    if (destination == DashboardDestination.management) {
      return Image.asset(
        'assets/images/hr_accounting_new.png',
        width: size,
        height: size,
        color: Colors.white,
        colorBlendMode: BlendMode.srcIn,
      );
    }
    final glyph = switch (destination) {
      DashboardDestination.profile => NativeDashboardGlyph.profile,
      DashboardDestination.appointment => NativeDashboardGlyph.appointment,
      DashboardDestination.leave => NativeDashboardGlyph.leave,
      _ => NativeDashboardGlyph.payment,
    };
    return NativeDashboardIcon(glyph, size: size, color: Colors.white);
  }

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('dashboard_bottom_menu'),
    color: DocColors.primary,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
    clipBehavior: Clip.antiAlias,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          4 * sdp,
          4 * sdp,
          4 * sdp,
          4 * sdp + 10 / MediaQuery.devicePixelRatioOf(context),
        ),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (final item in nativeDashboardMenu(profile))
                Expanded(
                  child: _IconTap(
                    key: Key('dashboard_nav_${item.destination.name}'),
                    label: item.label,
                    onTap: () => onDestination(item.destination),
                    child: Center(child: _icon(item.destination)),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _IconTap extends StatelessWidget {
  const _IconTap({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
  });
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    child: Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: InkWell(onTap: onTap, child: child),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.message,
    required this.sdp,
    required this.onRetry,
  });
  final String message;
  final double sdp;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 16 * sdp, vertical: 32 * sdp),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: _text('Poppins', 12 * sdp, color: const Color(0xFF6C6E6F)),
        ),
        const SizedBox(height: 16),
        IconButton(
          key: const Key('dashboard_retry'),
          tooltip: 'Retry',
          onPressed: onRetry,
          color: DocColors.primary,
          icon: const Icon(Icons.refresh),
          iconSize: 32 * sdp,
        ),
      ],
    ),
  );
}

/// Native access/full-load failures hide the content and navigation while
/// retaining the same dashboard header behind their blocking dialog.
class NativeDashboardGateBackground extends StatelessWidget {
  const NativeDashboardGateBackground({super.key, this.loading = false});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).shortestSide;
    final sdp = width < 300 ? 1.0 : (width / 30).floor() * 30 / 300;
    return Scaffold(
      backgroundColor: DocColors.clouds,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              sdp: sdp,
              showSwitch: false,
              onSwitch: () {},
              onLogout: () {},
            ),
            Expanded(
              child: ColoredBox(
                color: Colors.white,
                child:
                    loading
                        ? const Center(
                          child: CircularProgressIndicator(
                            color: DocColors.primary,
                          ),
                        )
                        : const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
