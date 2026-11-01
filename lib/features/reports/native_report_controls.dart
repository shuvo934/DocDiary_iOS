import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import 'native_report_icons.dart';
import 'report_manager_models.dart';

double reportScale(BuildContext context) {
  final width = MediaQuery.sizeOf(context).shortestSide;
  return width < 300 ? 1 : (width / 30).floor() * 30 / 300;
}

TextStyle reportText(
  double size,
  double scale, {
  String family = 'Poppins',
  FontWeight weight = FontWeight.w400,
  Color color = Colors.black,
}) => TextStyle(
  inherit: false,
  textBaseline: TextBaseline.alphabetic,
  fontFamily: family,
  fontFamilyFallback: const ['DocDiaryBengali'],
  fontSize: math.max(8, size * scale - 1),
  fontWeight: weight,
  color: color,
  height: 1.5,
);

class NativeReportFrame extends StatelessWidget {
  const NativeReportFrame({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.parameterHeader = false,
    this.action,
  });
  final String title;
  final VoidCallback onClose;
  final Widget child;
  final bool parameterHeader;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final scale = reportScale(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: DocColors.clouds,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale,
                  vertical: 8 * scale,
                ),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('report_close'),
                      onPressed: onClose,
                      tooltip: 'Close',
                      padding: EdgeInsets.zero,
                      icon: NativeReportIcon(
                        ReportGlyph.close,
                        size: 21 * scale,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: reportText(
                          parameterHeader ? 13 : 11,
                          scale,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (action != null) ...[
                      SizedBox(width: 4 * scale),
                      action!,
                    ],
                  ],
                ),
              ),
              const SizedBox(
                height: 1,
                width: double.infinity,
                child: ColoredBox(color: DocColors.greenSea),
              ),
              Expanded(child: ColoredBox(color: Colors.white, child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

class NativeReportFilterField extends StatelessWidget {
  const NativeReportFilterField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
    this.calendar = false,
  });
  final String label, value;
  final VoidCallback? onTap;
  final bool enabled, calendar;
  @override
  Widget build(BuildContext context) {
    final scale = reportScale(context),
        radius = BorderRadius.circular(8 * reportScale(context));
    final border = UnderlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    );
    return Semantics(
      button: true,
      enabled: enabled && onTap != null,
      label: '$label${value.isEmpty ? '' : ': $value'}',
      child: Material(
        color: Colors.white,
        elevation: .7 * scale,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: enabled ? DocColors.primary : const Color(0xffb2bec3),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onTap : null,
          child: InputDecorator(
            isEmpty: value.isEmpty,
            decoration: InputDecoration(
              enabled: enabled,
              labelText: label,
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              labelStyle: reportText(10, scale, color: const Color(0xff6c6e6f)),
              floatingLabelStyle: reportText(
                11,
                scale,
                color: const Color(0xff6c6e6f),
              ),
              fillColor: enabled ? Colors.white : const Color(0xfff5f5f5),
              filled: true,
              border: border,
              enabledBorder: border,
              disabledBorder: border,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10 * scale,
              ),
              prefixIcon:
                  calendar
                      ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: NativeReportIcon(
                          ReportGlyph.calendar,
                          color: DocColors.greenSea,
                          size: 22,
                        ),
                      )
                      : null,
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: reportText(
                9,
                scale,
                weight: FontWeight.w500,
                color: enabled ? Colors.black : const Color(0xff95a5a6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NativeReportGradientButton extends StatelessWidget {
  const NativeReportGradientButton({
    super.key,
    required this.onPressed,
    required this.label,
  });
  final VoidCallback? onPressed;
  final String label;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? .45 : 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [DocColors.primary, DocColors.greenSea],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  label,
                  style: reportText(
                    13,
                    reportScale(context),
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Native report_parameter_selection_layout + report_parameter_selection_details_view.
class NativeReportParameterDialog extends StatefulWidget {
  const NativeReportParameterDialog({
    super.key,
    required this.parameter,
    required this.choices,
  });
  final ReportParameter parameter;
  final List<ReportChoice> choices;
  @override
  State<NativeReportParameterDialog> createState() => _ParameterDialogState();
}

class _ParameterDialogState extends State<NativeReportParameterDialog> {
  final _search = TextEditingController(), _focus = FocusNode();
  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = reportScale(context), media = MediaQuery.of(context);
    final visible =
        widget.choices
            .asMap()
            .entries
            .where(
              (e) => e.value.name.toLowerCase().contains(
                _search.text.toLowerCase(),
              ),
            )
            .toList();
    return Dialog(
      key: const Key('report_parameter_dialog'),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: math.max(
            140,
            media.size.height -
                media.viewInsets.bottom -
                media.padding.vertical -
                60,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: DocColors.primary,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  'Select ${widget.parameter.label}',
                  style: reportText(
                    13,
                    scale,
                    family: 'RussoOne',
                    color: Colors.white,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                4 * scale,
                8 * scale,
                4 * scale,
                4 * scale,
              ),
              child: Material(
                color: Colors.white,
                elevation: 1,
                borderRadius: BorderRadius.circular(8 * scale),
                child: TextField(
                  key: const Key('report_parameter_search'),
                  controller: _search,
                  focusNode: _focus,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  smartQuotesType: SmartQuotesType.disabled,
                  smartDashesType: SmartDashesType.disabled,
                  style: reportText(10, scale, weight: FontWeight.w500),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _focus.unfocus(),
                  decoration: InputDecoration(
                    labelText:
                        _search.text.isEmpty
                            ? 'Search ${widget.parameter.label}'
                            : widget.parameter.label,
                    labelStyle: reportText(
                      10,
                      scale,
                      color: const Color(0xffb2bec3),
                    ),
                    floatingLabelStyle: reportText(
                      11,
                      scale,
                      color: const Color(0xff6c6e6f),
                    ),
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8 * scale),
                      borderSide: const BorderSide(color: DocColors.primary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8 * scale),
                      borderSide: const BorderSide(color: DocColors.primary),
                    ),
                  ),
                ),
              ),
            ),
            Flexible(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  4 * scale,
                  10 * scale,
                  4 * scale,
                  6 * scale,
                ),
                child: Material(
                  color: Colors.white,
                  elevation: 1.5,
                  borderRadius: BorderRadius.circular(10 * scale),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ColoredBox(
                        color: DocColors.primary,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8 * scale,
                            vertical: 4 * scale,
                          ),
                          child: Text(
                            widget.parameter == ReportParameter.doctor
                                ? 'DOCTOR NAME'
                                : widget.parameter.label.toUpperCase(),
                            style: reportText(
                              9,
                              scale,
                              family: 'PatuaOne',
                              color: Colors.white,
                              weight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (visible.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(8 * scale),
                          child: Text(
                            'No Information Found',
                            textAlign: TextAlign.center,
                            style: reportText(
                              12,
                              scale,
                              weight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: visible.length,
                            separatorBuilder:
                                (_, _) => const SizedBox(
                                  height: 1,
                                  child: ColoredBox(color: Color(0xff95a5a6)),
                                ),
                            itemBuilder: (context, index) {
                              final e = visible[index];
                              return Material(
                                color: DocColors.clouds,
                                child: InkWell(
                                  key: Key('report_parameter_option_${e.key}'),
                                  onTap: () {
                                    _focus.unfocus();
                                    Navigator.pop(context, e.value);
                                  },
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 34,
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        8 * scale,
                                        4 * scale,
                                        4 * scale,
                                        4 * scale,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          e.value.name,
                                          style: reportText(
                                            8,
                                            scale,
                                            family: 'OpenSans',
                                            weight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton(
                  key: const Key('report_parameter_cancel'),
                  onPressed: () {
                    _focus.unfocus();
                    Navigator.pop(context);
                  },
                  child: const Text('CANCEL'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
