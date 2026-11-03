import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
import '../../appointments/admin_modify/native_admin_appointment_controls.dart';
import '../../profile/native_profile_icons.dart';
export '../../appointments/admin_modify/native_admin_appointment_controls.dart'
    show adminAppointmentScale, adminAppointmentText;

const vtTextColor = Color(0xff747677);
const vtDisabled = Color(0xfff5f5f5);
const vtCloud = Color(0xff95a5a6);
TextStyle vtText(
  double size,
  double scale, {
  Color color = vtTextColor,
  FontWeight weight = FontWeight.w700,
  String family = 'Roboto',
}) => adminAppointmentText(
  size,
  scale,
  color: color,
  weight: weight,
  family: family,
);

class NativeVoucherShell extends StatefulWidget {
  const NativeVoucherShell({
    super.key,
    required this.title,
    required this.child,
    required this.onBack,
    required this.backKey,
  });
  final String title, backKey;
  final Widget child;
  final VoidCallback? onBack;
  @override
  State<NativeVoucherShell> createState() => _NativeVoucherShellState();
}

class _NativeVoucherShellState extends State<NativeVoucherShell> {
  final _toasts = AppToastOwner();
  void _wait() => _toasts.show(context, 'Please wait while loading');
  @override
  void didUpdateWidget(covariant NativeVoucherShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onBack == null && widget.onBack != null) _toasts.clear();
  }

  @override
  void dispose() {
    _toasts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    return PopScope(
      canPop: widget.onBack != null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.onBack == null) _wait();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: DocColors.primary,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20 * s,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 19 * s,
                        child: IconButton(
                          key: Key(widget.backKey),
                          tooltip: 'Back',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minHeight: 44),
                          onPressed: widget.onBack ?? _wait,
                          icon: NativeProfileIcon(
                            NativeProfileGlyph.back,
                            size: 19 * s,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: vtText(
                            14,
                            s,
                            family: 'Poppins',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: SafeArea(top: false, child: widget.child),
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

class VoucherDateField extends StatelessWidget {
  const VoucherDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label, value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$label: $value',
      child: Material(
        color: Colors.white,
        elevation: 1.5,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: DocColors.primary),
        ),
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7 * s),
            child: Row(
              children: [
                SizedBox(
                  width: 20 * s,
                  height: 20 * s,
                  child: CustomPaint(painter: _CalendarPainter()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: vtText(
                          10,
                          s,
                          family: 'Poppins',
                          weight: FontWeight.w400,
                        ),
                      ),
                      if (value.isNotEmpty)
                        Text(
                          value,
                          style: vtText(
                            10.5,
                            s,
                            family: 'Poppins',
                            color: Colors.black,
                            weight: FontWeight.w500,
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
    );
  }
}

class _CalendarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width, p = Paint();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(width * .12, width * .17, width * .76, width * .74),
        Radius.circular(width * .07),
      ),
      p..color = const Color(0xffdfe3e5),
    );
    canvas.drawRect(
      Rect.fromLTWH(width * .12, width * .2, width * .76, width * .2),
      p..color = const Color(0xffd65147),
    );
    for (final x in [.3, .7]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(width * x, width * .1, width * .07, width * .2),
          Radius.circular(width * .03),
        ),
        p..color = const Color(0xffb2bec3),
      );
    }
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 3; x++) {
        canvas.drawRect(
          Rect.fromLTWH(
            width * (.25 + x * .19),
            width * (.5 + y * .12),
            width * .1,
            width * .07,
          ),
          p..color = const Color(0xffa5afb5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class VoucherTypeField extends StatelessWidget {
  const VoucherTypeField({
    super.key,
    required this.controller,
    required this.selected,
    required this.choices,
    required this.enabled,
    required this.onSelected,
    this.onMenuChanged,
  });
  final MenuController controller;
  final String selected;
  final List<String> choices;
  final bool enabled;
  final ValueChanged<String> onSelected;
  final VoidCallback? onMenuChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final s = adminAppointmentScale(context);
      return MenuAnchor(
        controller: controller,
        consumeOutsideTap: true,
        onOpen: onMenuChanged,
        onClose: onMenuChanged,
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
          maximumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 320)),
          elevation: const WidgetStatePropertyAll(8),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          ),
        ),
        menuChildren: [
          for (var i = 0; i < choices.length; i++)
            MenuItemButton(
              key: Key('vt_type_option_$i'),
              onPressed: enabled ? () => onSelected(choices[i]) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  choices[i],
                  style: vtText(
                    11,
                    s,
                    family: 'Poppins',
                    weight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
        ],
        builder:
            (context, menu, child) => NativeAdminAppointmentField(
              key: const Key('vt_type'),
              label: 'Voucher Type',
              value: selected,
              onTap:
                  enabled && choices.isNotEmpty
                      ? () {
                        if (menu.isOpen) {
                          menu.close();
                        } else {
                          menu.open();
                        }
                      }
                      : null,
              enabled: enabled,
              dropdown: true,
            ),
      );
    },
  );
}

double voucherTextHeight(
  BuildContext context,
  String value,
  double width,
  TextStyle style, {
  double vertical = 8,
  double minimum = 24,
}) {
  final painter = TextPainter(
    text: TextSpan(text: value, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: math.max(1, width - 10));
  return math.max(minimum, painter.height + vertical);
}

Widget voucherCell({
  required double width,
  required double height,
  required String text,
  required TextStyle style,
  Color? color,
  Color line = Colors.black,
  bool border = true,
  VoidCallback? onTap,
  Key? key,
}) => Container(
  width: width,
  height: height,
  decoration: BoxDecoration(
    color: color,
    border: border ? Border(right: BorderSide(color: line, width: 1)) : null,
  ),
  child: InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Center(
        child: Text(text, key: key, style: style, textAlign: TextAlign.center),
      ),
    ),
  ),
);

class VoucherDashes extends StatelessWidget {
  const VoucherDashes({super.key, this.color = const Color(0xffb2bec3)});
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 1,
    child: CustomPaint(painter: _DashPainter(color)),
  );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p =
        Paint()
          ..color = color
          ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, .5),
        Offset(math.min(x + 4, size.width), .5),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}
