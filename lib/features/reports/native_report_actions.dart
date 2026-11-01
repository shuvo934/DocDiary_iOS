import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'native_report_controls.dart';
import 'native_report_icons.dart';

/// Native MaterialButton proportions: a wide pill, tracked PatuaOne label,
/// and a smaller visible surface inside its accessible tap target.
class NativeReportPdfButton extends StatelessWidget {
  const NativeReportPdfButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => TextButton(
    key: const Key('report_pdf_view'),
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: DocColors.primary,
      disabledBackgroundColor: const Color(0xffb2bec3),
      foregroundColor: Colors.white,
      elevation: 1.5,
      minimumSize: const Size(88, 36),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30 * reportScale(context)),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Text(
        'PDF VIEW',
        style: reportText(
          9,
          reportScale(context),
          family: 'PatuaOne',
          color: Colors.white,
        ).copyWith(letterSpacing: 1.25),
      ),
    ),
  );
}

/// The native image is 24dp plus 3sdp padding per side. Painting a 48dp card
/// with a 15sdp corner produces a rounded square; the visible native surface
/// must stay circular while the surrounding tap target stays accessible.
class NativeReportPageButton extends StatelessWidget {
  const NativeReportPageButton({
    super.key,
    required this.forward,
    required this.onPressed,
  });
  final bool forward;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final diameter = 24 + 6 * reportScale(context);
    return IconButton(
      key: Key(forward ? 'report_pdf_next' : 'report_pdf_previous'),
      tooltip: forward ? 'Next page' : 'Previous page',
      onPressed: onPressed,
      iconSize: diameter,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: SizedBox.square(
        dimension: diameter,
        child: Material(
          key: Key(
            forward ? 'report_pdf_next_surface' : 'report_pdf_previous_surface',
          ),
          color: DocColors.primary,
          elevation: 1.5,
          shape: const CircleBorder(),
          child: Center(
            child: NativeReportIcon(
              forward ? ReportGlyph.forward : ReportGlyph.back,
              size: 24,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class NativeReportZoomButton extends StatelessWidget {
  const NativeReportZoomButton({
    super.key,
    required this.zoomIn,
    required this.onPressed,
  });
  final bool zoomIn;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    key: Key(zoomIn ? 'report_pdf_zoom_in' : 'report_pdf_zoom_out'),
    tooltip: zoomIn ? 'Zoom in' : 'Zoom out',
    onPressed: onPressed,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    padding: EdgeInsets.zero,
    icon: Text(
      zoomIn ? '+' : '−',
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 24,
        height: 1,
        color: onPressed == null ? const Color(0xffb2bec3) : DocColors.greenSea,
      ),
    ),
  );
}
