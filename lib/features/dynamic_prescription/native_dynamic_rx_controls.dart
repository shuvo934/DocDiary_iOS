import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dynamic_clinical_models.dart';
import 'native_dynamic_rx_icons.dart';

abstract final class DynamicRxColors {
  static const primary = Color(0xff16a085), header = Color(0xff50c2c0);
  static const light = Color(0xffe7f8f9), outline = Color(0xffdde3e8);
  static const text = Color(0xff202124), secondary = Color(0xff667085);
  static const error = Color(0xffd92d20);
}

/// Native sdp uses the 300dp baseline. Only font size has the agreed iOS -1pt.
class DynamicRxMetrics {
  DynamicRxMetrics(BuildContext context)
    : scale = MediaQuery.sizeOf(context).shortestSide / 300;
  final double scale;
  double d(double value) => value * scale;
  TextStyle text(
    double value, {
    FontWeight weight = FontWeight.w400,
    Color color = DynamicRxColors.text,
    double? spacing,
  }) => TextStyle(
    fontFamily: 'Poppins',
    fontFamilyFallback: const ['Roboto'],
    fontSize: math.max(1, d(value) - 1),
    fontWeight: weight,
    color: color,
    height: 1.5,
    letterSpacing: spacing,
  );
}

class NativeDynamicRxField extends StatelessWidget {
  const NativeDynamicRxField({
    super.key,
    required this.id,
    required this.label,
    required this.controller,
    this.enabled = true,
    this.readOnly = false,
    this.error,
    this.focusNode,
    this.onChanged,
    this.onTap,
    this.onTapOutside,
    this.suffix,
    this.minLines = 1,
    this.maxLines = 1,
    this.numeric = false,
    this.formatters,
    this.filled = false,
    this.unit,
  });
  final String id, label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled, readOnly, numeric, filled;
  final String? error, unit;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final ValueChanged<PointerDownEvent>? onTapOutside;
  final Widget? suffix;
  final int minLines, maxLines;
  final List<TextInputFormatter>? formatters;

  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(m.d(8)),
      borderSide: const BorderSide(color: Color(0xff999999)),
    );
    return TextField(
      key: Key('dy_field_$id'),
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      showCursor: !readOnly,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType:
          numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : maxLines > 1
              ? TextInputType.multiline
              : TextInputType.text,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      inputFormatters: formatters,
      cursorColor: DynamicRxColors.primary,
      style: m.text(
        10,
        weight: FontWeight.w500,
        color: enabled ? DynamicRxColors.text : const Color(0xff999999),
      ),
      onChanged: onChanged,
      onTap: onTap,
      onTapOutside:
          onTapOutside ?? (_) => FocusManager.instance.primaryFocus?.unfocus(),
      onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: InputDecoration(
        isDense: true,
        alignLabelWithHint: minLines > 1,
        labelText: label,
        labelStyle: m.text(
          10,
          color: enabled ? const Color(0xff666666) : const Color(0xff999999),
        ),
        floatingLabelStyle: m.text(8, color: DynamicRxColors.primary),
        contentPadding: EdgeInsets.symmetric(
          horizontal: m.d(12),
          vertical: m.d(10),
        ),
        border: border,
        enabledBorder: border,
        disabledBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xffcccccc)),
        ),
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(
            color: DynamicRxColors.primary,
            width: 2,
          ),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: DynamicRxColors.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: DynamicRxColors.error, width: 2),
        ),
        errorText: error,
        errorStyle: m.text(7, color: DynamicRxColors.error),
        errorMaxLines: 3,
        filled: filled,
        fillColor: const Color(0xfff9fafb),
        suffixIcon: suffix,
        suffixIconConstraints: BoxConstraints(
          minWidth: m.d(32),
          minHeight: m.d(34),
        ),
        suffixText: unit,
        suffixStyle: m.text(7, color: DynamicRxColors.secondary),
      ),
    );
  }
}

/// ClinicalOptionAdapter's filtering and native anchored dropdown behavior.
/// Overlay updates from parent rebuilds are deferred past the build phase.
class NativeDynamicRxChoiceField extends StatefulWidget {
  const NativeDynamicRxChoiceField({
    super.key,
    required this.id,
    required this.label,
    required this.controller,
    required this.options,
    required this.onChoice,
    required this.onChanged,
    this.error,
    this.enabled = true,
    this.dropdownOnly = false,
    this.maxLines = 1,
  });
  final String id, label;
  final TextEditingController controller;
  final List<DynamicRxOption> options;
  final ValueChanged<DynamicRxOption> onChoice;
  final ValueChanged<String> onChanged;
  final String? error;
  final bool enabled, dropdownOnly;
  final int maxLines;
  @override
  State<NativeDynamicRxChoiceField> createState() => _ChoiceFieldState();
}

class _ChoiceFieldState extends State<NativeDynamicRxChoiceField>
    with WidgetsBindingObserver {
  final _focus = FocusNode();
  final _link = LayerLink();
  final _target = GlobalKey();
  OverlayEntry? _entry;
  bool _all = false, _queued = false, _sawKeyboard = false;
  bool _showRequested = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant NativeDynamicRxChoiceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _afterFrame();
  }

  void _focusChanged() {
    if (!_focus.hasFocus) {
      _close();
    } else if (_showRequested) {
      _afterFrame();
    }
  }

  void _close() {
    _showRequested = false;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  void _afterFrame() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted) return;
      if (!widget.enabled || !_focus.hasFocus) {
        _close();
        return;
      }
      final keyboard = View.of(context).viewInsets.bottom > 0;
      if (_sawKeyboard && !keyboard && !widget.dropdownOnly) {
        _close();
        _focus.unfocus();
        _sawKeyboard = false;
        return;
      }
      _sawKeyboard = keyboard;
      if (_showRequested) _refresh();
    });
  }

  @override
  void didChangeMetrics() => _afterFrame();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _close();
      _focus.unfocus();
    }
  }

  List<DynamicRxOption> get _matches {
    final query = widget.controller.text.trim();
    if (_all || widget.dropdownOnly) return widget.options;
    if (query.length < 2) return const [];
    return widget.options
        .where((option) => option.matches(query))
        .toList(growable: false);
  }

  void _showAll() {
    if (!widget.enabled) return;
    if (widget.dropdownOnly) FocusManager.instance.primaryFocus?.unfocus();
    _all = true;
    _showRequested = true;
    _focus.requestFocus();
    if (_focus.hasFocus) {
      _refresh();
    } else {
      _afterFrame();
    }
  }

  void _refresh() {
    if (!mounted ||
        !widget.enabled ||
        !_showRequested ||
        !_focus.hasFocus ||
        _matches.isEmpty) {
      _close();
      return;
    }
    if (_entry == null) {
      _entry = OverlayEntry(builder: _popup);
      Overlay.of(context).insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }
  }

  Widget _popup(BuildContext overlayContext) {
    if (!mounted || !widget.enabled || !_focus.hasFocus || _matches.isEmpty) {
      return const SizedBox.shrink();
    }
    final object = _target.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize) {
      return const SizedBox.shrink();
    }
    final view = View.of(context), position = object.localToGlobal(Offset.zero);
    final height = view.physicalSize.height / view.devicePixelRatio;
    final keyboard = view.viewInsets.bottom / view.devicePixelRatio;
    final below = height - keyboard - position.dy - object.size.height - 8;
    final above = position.dy - MediaQuery.paddingOf(context).top - 8;
    final up = below < 160 && above > below;
    final room = math.min(300.0, math.max(0.0, up ? above : below));
    if (room < 1) return const SizedBox.shrink();
    final options = _matches, m = DynamicRxMetrics(context);
    return Positioned(
      width: object.size.width,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: up ? Alignment.topLeft : Alignment.bottomLeft,
        followerAnchor: up ? Alignment.bottomLeft : Alignment.topLeft,
        offset: Offset(0, up ? -2 : 2),
        child: TextFieldTapRegion(
          child: Material(
            color: Colors.white,
            elevation: 6,
            borderRadius: BorderRadius.circular(m.d(4)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: room),
              child: ListView.separated(
                key: Key('dy_options_${widget.id}'),
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder:
                    (_, _) => const Divider(
                      height: 1,
                      color: DynamicRxColors.outline,
                    ),
                itemBuilder: (_, index) {
                  final option = options[index];
                  return InkWell(
                    key: Key('dy_option_${widget.id}_${option.id}_$index'),
                    onTap: () {
                      _close();
                      widget.controller.value = TextEditingValue(
                        text: option.name,
                        selection: TextSelection.collapsed(
                          offset: option.name.length,
                        ),
                      );
                      widget.onChoice(option);
                      _focus.unfocus();
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: m.d(12),
                        vertical: m.d(9),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.name,
                            style: m.text(10, weight: FontWeight.w500),
                          ),
                          if (option.note.isNotEmpty)
                            Text(
                              option.note,
                              style: m.text(
                                7,
                                color: DynamicRxColors.secondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context);
    return CompositedTransformTarget(
      key: _target,
      link: _link,
      child: NativeDynamicRxField(
        id: widget.id,
        label: widget.label,
        controller: widget.controller,
        enabled: widget.enabled,
        error: widget.error,
        focusNode: _focus,
        readOnly: widget.dropdownOnly,
        maxLines: widget.maxLines,
        onTap: _showAll,
        onTapOutside: (_) {
          _close();
          _focus.unfocus();
        },
        onChanged: (value) {
          _all = false;
          _showRequested = true;
          widget.onChanged(value);
          _refresh();
        },
        suffix: IconButton(
          key: Key('dy_dropdown_${widget.id}'),
          padding: EdgeInsets.zero,
          tooltip: 'Show ${widget.label}',
          onPressed:
              widget.enabled
                  ? () {
                    if (_entry != null) {
                      _close();
                    } else {
                      _showAll();
                    }
                  }
                  : null,
          icon: NativeDynamicRxIcon(
            DynamicRxGlyph.dropdown,
            size: m.d(20),
            color:
                widget.enabled
                    ? const Color(0xff666666)
                    : const Color(0xffaaaaaa),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _close();
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    super.dispose();
  }
}

class NativeDynamicRxSheet extends StatelessWidget {
  const NativeDynamicRxSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.body,
    required this.saveLabel,
    required this.onSave,
  });
  final String title, subtitle, saveLabel;
  final DynamicRxGlyph icon;
  final Widget body;
  final VoidCallback? onSave;
  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context);
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ColoredBox(
            color: DynamicRxColors.header,
            child: Padding(
              padding: EdgeInsets.all(m.d(8)),
              child: Column(
                children: [
                  SizedBox(height: m.d(7)),
                  Container(
                    width: m.d(32),
                    height: m.d(4),
                    color: const Color(0xffd0d5dd),
                  ),
                  Row(
                    children: [
                      Container(
                        width: m.d(36),
                        height: m.d(36),
                        decoration: BoxDecoration(
                          color: const Color(0xffeaf7f8),
                          borderRadius: BorderRadius.circular(m.d(9)),
                        ),
                        child: Center(
                          child: NativeDynamicRxIcon(icon, size: m.d(21)),
                        ),
                      ),
                      SizedBox(width: m.d(8)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: m.text(
                                11,
                                weight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: m.text(7, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      SizedBox.square(
                        dimension: m.d(36),
                        child: IconButton(
                          key: const Key('dy_sheet_close'),
                          tooltip: 'Close',
                          padding: EdgeInsets.all(m.d(8)),
                          onPressed: () => Navigator.pop(context),
                          icon: NativeDynamicRxIcon(
                            DynamicRxGlyph.close,
                            size: m.d(20),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: body),
          const Divider(height: 1, thickness: 1, color: Color(0xffeaecf0)),
          Padding(
            padding: EdgeInsets.fromLTRB(m.d(12), m.d(8), m.d(12), m.d(10)),
            child: Row(
              children: [
                Expanded(
                  child: NativeDynamicRxButton(
                    label: 'CANCEL',
                    outlined: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                SizedBox(width: m.d(10)),
                Expanded(
                  child: NativeDynamicRxButton(
                    label: saveLabel,
                    onPressed: onSave,
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

class NativeDynamicRxButton extends StatelessWidget {
  const NativeDynamicRxButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context);
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 3),
      ),
      textStyle: WidgetStatePropertyAll(
        m.text(9, weight: FontWeight.w700, spacing: 1),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(m.d(8))),
      ),
      foregroundColor: WidgetStatePropertyAll(
        outlined ? DynamicRxColors.primary : Colors.white,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            outlined
                ? Colors.white
                : states.contains(WidgetState.disabled)
                ? DynamicRxColors.primary.withValues(alpha: .45)
                : DynamicRxColors.primary,
      ),
      side:
          outlined
              ? const WidgetStatePropertyAll(
                BorderSide(color: DynamicRxColors.primary),
              )
              : null,
      elevation: const WidgetStatePropertyAll(0),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return SizedBox(
      height: m.d(40),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ElevatedButton(
          key: Key('dy_action_$label'),
          onPressed: onPressed,
          style: style,
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
        ),
      ),
    );
  }
}

Future<T?> showNativeDynamicRxSheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder:
          (sheetContext) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height:
                    MediaQuery.sizeOf(sheetContext).height -
                    MediaQuery.paddingOf(sheetContext).top -
                    MediaQuery.viewInsetsOf(sheetContext).bottom,
                child: child,
              ),
            ),
          ),
    );
