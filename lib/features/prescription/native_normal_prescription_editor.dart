import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../appointments/doctor_schedule/native_appointment_timeline_card.dart';
import 'normal_prescription_models.dart';
import 'normal_prescription_native_style.dart';

class NativeNormalPrescriptionEditor extends StatelessWidget {
  const NativeNormalPrescriptionEditor({
    super.key,
    required this.spec,
    required this.controllers,
    required this.choices,
    required this.onPick,
    required this.onChanged,
    required this.onChoice,
    required this.onSave,
    required this.onCancel,
    this.onDelete,
    this.enabled = true,
    this.updating = false,
    this.errors = const {},
    this.onValidate,
    this.disabledFields = const {},
    this.messages = const {},
  });
  final RxSectionSpec spec;
  final Map<String, TextEditingController> controllers;
  final Map<String, List<RxChoice>> choices;
  final ValueChanged<RxField> onPick;
  final void Function(RxField, String) onChanged;
  final void Function(RxField, RxChoice) onChoice;
  final VoidCallback onSave, onCancel;
  final VoidCallback? onDelete;
  final bool enabled, updating;
  final Map<String, String> errors;
  final ValueChanged<RxField>? onValidate;
  final Set<String> disabledFields;
  final Map<String, String> messages;
  @override
  Widget build(BuildContext context) {
    final s = appointmentScale(context);
    return Column(
      key: const Key('rx_editor'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const Key('rx_editor_scroll'),
            padding: EdgeInsets.fromLTRB(8 * s, 12 * s, 8 * s, 12 * s),
            child: Column(
              children: [
                for (var i = 0; i < spec.fields.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == spec.fields.length - 1 ? 0 : 12 * s,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        NativeRxField(
                          key: ValueKey('rx_input_${spec.fields[i].header}'),
                          field: spec.fields[i],
                          label: rxNativeFieldLabel(spec, spec.fields[i]),
                          controller: controllers[spec.fields[i].header]!,
                          choices: choices[spec.fields[i].header] ?? const [],
                          enabled:
                              enabled &&
                              !disabledFields.contains(spec.fields[i].header),
                          onPick: () => onPick(spec.fields[i]),
                          onChanged: (text) => onChanged(spec.fields[i], text),
                          onChoice:
                              (choice) => onChoice(spec.fields[i], choice),
                          onValidate: () => onValidate?.call(spec.fields[i]),
                        ),
                        if ((errors[spec.fields[i].header] ??
                                messages[spec.fields[i].header]) !=
                            null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 3),
                            child: Text(
                              errors[spec.fields[i].header] ??
                                  messages[spec.fields[i].header]!,
                              style: rxNativeText(
                                12,
                                color: Colors.redAccent,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: NativeRxActionButton(
                  key: const Key('rx_save'),
                  label: updating ? 'UPDATE' : 'ADD',
                  scale: s,
                  form: true,
                  onPressed:
                      enabled &&
                              !spec.fields.any(
                                (f) =>
                                    f.required &&
                                    disabledFields.contains(f.header),
                              )
                          ? onSave
                          : null,
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 40),
                Expanded(
                  child: NativeRxActionButton(
                    key: const Key('rx_editor_delete'),
                    label: 'DELETE',
                    scale: s,
                    form: true,
                    onPressed: enabled ? onDelete : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The same anchored, searchable input interaction as Thana/Upazila.
class NativeRxField extends StatefulWidget {
  const NativeRxField({
    super.key,
    required this.field,
    required this.label,
    required this.controller,
    required this.choices,
    required this.onPick,
    required this.onChanged,
    required this.onChoice,
    this.enabled = true,
    this.onValidate,
  });
  final RxField field;
  final String label;
  final TextEditingController controller;
  final List<RxChoice> choices;
  final VoidCallback onPick;
  final ValueChanged<String> onChanged;
  final ValueChanged<RxChoice> onChoice;
  final bool enabled;
  final VoidCallback? onValidate;
  @override
  State<NativeRxField> createState() => _NativeRxFieldState();
}

class _NativeRxFieldState extends State<NativeRxField>
    with WidgetsBindingObserver {
  final _focus = FocusNode(), _link = LayerLink();
  final _target = GlobalKey();
  OverlayEntry? _entry;
  bool _all = false, _refreshScheduled = false, _validationScheduled = false;
  bool _keyboardVisible = false, _disposing = false;
  bool get _canChoose => widget.enabled && widget.field.lookup.isNotEmpty;

  List<RxChoice> get _options {
    final query = widget.controller.text.trim().toLowerCase();
    return widget.choices
        .where((choice) {
          final name = choice.name.toLowerCase();
          return name.isNotEmpty &&
              (_all ||
                  name.startsWith(query) ||
                  name
                      .split(RegExp(r'\s+'))
                      .any((word) => word.startsWith(query)));
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (!_focus.hasFocus) {
      _close();
      _validateAfterFrame();
    }
  }

  void _validateAfterFrame() {
    if (_disposing || _validationScheduled) return;
    _validationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validationScheduled = false;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (mounted &&
          widget.enabled &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed)) {
        widget.onValidate?.call();
      }
    });
  }

  void _close() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
  }

  // An overlay is outside this field's subtree. Updating it from
  // didUpdateWidget would mark an unrelated element dirty during build.
  void _refreshAfterFrame() {
    if (_refreshScheduled || _disposing) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (!mounted) return;
      final keyboardVisible = View.of(context).viewInsets.bottom > 0;
      final keyboardClosed = _keyboardVisible && !keyboardVisible;
      _keyboardVisible = keyboardVisible;
      if (!widget.enabled || keyboardClosed) {
        _close();
        _focus.unfocus();
      } else if (_entry != null) {
        if (_focus.hasFocus) {
          _show(all: _all);
        } else {
          _close();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _close();
      _focus.unfocus();
    }
  }

  @override
  void didChangeMetrics() => _refreshAfterFrame();

  @override
  void didUpdateWidget(covariant NativeRxField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshAfterFrame();
  }

  void _show({bool all = false, bool requestFocus = false}) {
    if (!_canChoose) return;
    _all = all;
    if (_options.isEmpty ||
        (!all && widget.controller.text.trim().length < 2)) {
      _close();
      return;
    }
    if (requestFocus) _focus.requestFocus();
    _keyboardVisible = View.of(context).viewInsets.bottom > 0;
    if (_entry != null) {
      _entry!.markNeedsBuild();
      return;
    }
    _entry = OverlayEntry(builder: _overlay);
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  Widget _overlay(BuildContext overlayContext) {
    if (!mounted || !_canChoose) return const SizedBox.shrink();
    final matches = _options;
    final box = _target.currentContext?.findRenderObject();
    if (matches.isEmpty || box is! RenderBox || !box.attached || !box.hasSize) {
      return const SizedBox.shrink();
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final media = MediaQuery.of(context), view = View.of(context);
    // Scaffold consumes its local viewInsets; the overlay uses screen space.
    final inset = view.viewInsets.bottom / view.devicePixelRatio;
    final below = math.max(
      0.0,
      view.physicalSize.height / view.devicePixelRatio -
          inset -
          (inset > 0 ? 0 : media.padding.bottom) -
          rect.bottom -
          4,
    );
    final above = math.max(0.0, rect.top - media.padding.top - 8);
    final up = below < 160 && above > below;
    final maxHeight = math.min(300.0, up ? above : below);
    if (maxHeight < 1) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      top: 0,
      width: rect.width,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: up ? Alignment.topLeft : Alignment.bottomLeft,
        followerAnchor: up ? Alignment.bottomLeft : Alignment.topLeft,
        offset: Offset(0, up ? -2 : 2),
        child: TextFieldTapRegion(
          child: Material(
            elevation: 4,
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ListView.builder(
                key: Key('rx_dropdown_${widget.field.header}'),
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final choice = matches[index];
                  final duplicate =
                      matches.where((c) => c.name == choice.name).length > 1;
                  return InkWell(
                    key: Key('rx_choice_${choice.id}'),
                    onTap: () {
                      _close();
                      widget.controller.value = TextEditingValue(
                        text: choice.name,
                        selection: TextSelection.collapsed(
                          offset: choice.name.length,
                        ),
                      );
                      widget.onChoice(choice);
                      _focus.unfocus();
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              choice.name,
                              style: rxNativeText(16, color: Colors.black),
                            ),
                            if (choice.note.isNotEmpty || duplicate)
                              Text(
                                choice.note.isEmpty
                                    ? 'ID: ${choice.id}'
                                    : choice.note,
                                style: rxNativeText(12),
                              ),
                          ],
                        ),
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
  void dispose() {
    _disposing = true;
    _close();
    WidgetsBinding.instance.removeObserver(this);
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.field.isDate, drop = widget.field.lookup.isNotEmpty;
    final fill = widget.enabled ? Colors.white : const Color(0xfff5f5f5);
    final textColor = widget.enabled ? Colors.black : const Color(0xff999999);
    return CompositedTransformTarget(
      key: _target,
      link: _link,
      child: Material(
        color: fill,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: DocColors.primary, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: TextField(
          key: Key('rx_field_${widget.field.header}'),
          controller: widget.controller,
          focusNode: _focus,
          enabled: widget.enabled,
          readOnly: date,
          style: rxNativeText(16, color: textColor),
          cursorColor: DocColors.greenSea,
          minLines: 1,
          maxLines: widget.field.numeric ? 1 : null,
          keyboardType:
              widget.field.numeric || widget.field.header == 'P_DURATION'
                  ? TextInputType.number
                  : TextInputType.text,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          onTap:
              date
                  ? widget.onPick
                  : drop
                  ? () => _show(all: true, requestFocus: true)
                  : null,
          onTapOutside: (_) {
            _close();
            _focus.unfocus();
          },
          onChanged: (text) {
            widget.onChanged(text);
            if (drop) _show();
          },
          onEditingComplete: () {
            _close();
            _focus.unfocus();
            _validateAfterFrame();
          },
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: rxNativeText(
              16,
              color:
                  widget.enabled
                      ? const Color(0xff6c6e6f)
                      : const Color(0xff999999),
            ),
            floatingLabelStyle: rxNativeText(16),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            filled: true,
            fillColor: fill,
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            prefixIcon:
                date
                    ? const Icon(
                      Icons.calendar_month,
                      color: DocColors.greenSea,
                      size: 24,
                    )
                    : null,
            suffixIcon:
                drop
                    ? IconButton(
                      key: Key('rx_dropdown_button_${widget.field.header}'),
                      tooltip: 'Show ${widget.label}',
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color:
                            widget.enabled
                                ? const Color(0xff757575)
                                : const Color(0xff999999),
                      ),
                      onPressed:
                          widget.enabled
                              ? () {
                                if (_entry != null) {
                                  _close();
                                } else {
                                  _show(all: true, requestFocus: true);
                                }
                              }
                              : null,
                    )
                    : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
