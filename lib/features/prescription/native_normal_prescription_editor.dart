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
                          enabled: enabled,
                          onPick: () => onPick(spec.fields[i]),
                          onChanged: (text) => onChanged(spec.fields[i], text),
                          onChoice:
                              (choice) => onChoice(spec.fields[i], choice),
                        ),
                        if (errors[spec.fields[i].header] != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 3),
                            child: Text(
                              errors[spec.fields[i].header]!,
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
                  onPressed: enabled ? onSave : null,
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

/// Android AutoCompleteTextView: the input itself filters a list anchored to it.
/// IDs are supplied only by a selected option, never resolved from the name.
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
  });
  final RxField field;
  final String label;
  final TextEditingController controller;
  final List<RxChoice> choices;
  final VoidCallback onPick;
  final ValueChanged<String> onChanged;
  final ValueChanged<RxChoice> onChoice;
  final bool enabled;
  @override
  State<NativeRxField> createState() => _NativeRxFieldState();
}

class _NativeRxFieldState extends State<NativeRxField>
    with WidgetsBindingObserver {
  final _focus = FocusNode(), _link = LayerLink();
  OverlayEntry? _entry;
  String _query = '';
  bool get _canChoose => widget.enabled && widget.field.lookup.isNotEmpty;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (!_focus.hasFocus) _close();
  }

  void _close() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _close();
      _focus.unfocus();
    }
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entry?.markNeedsBuild();
    });
  }

  @override
  void didUpdateWidget(covariant NativeRxField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _close();
      _focus.unfocus();
    } else {
      _entry?.markNeedsBuild();
    }
  }

  void _open() {
    if (!_canChoose) return;
    _query = '';
    _focus.requestFocus();
    if (_entry != null) {
      _entry!.markNeedsBuild();
      return;
    }
    _entry = OverlayEntry(builder: _overlay);
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  Widget _overlay(BuildContext overlayContext) {
    if (!mounted || !_canChoose) return const SizedBox.shrink();
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return const SizedBox.shrink();
    final rect = box.localToGlobal(Offset.zero) & box.size,
        media = MediaQuery.of(context);
    // Scaffold consumes local viewInsets when resizing the body. Use the view's
    // screen coordinates for an overlay positioned above that body.
    final view = View.of(context);
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
    final screenHeight = view.physicalSize.height / view.devicePixelRatio;
    final below =
        screenHeight -
        bottomInset -
        (bottomInset > 0 ? 0 : media.padding.bottom) -
        rect.bottom -
        4;
    final above = rect.top - media.padding.top - 8;
    final up = below < 160 && above > below,
        maxHeight = math.min(300.0, math.max(48.0, up ? above : below));
    final matches =
        widget.choices
            .where(
              (c) => c.description.toLowerCase().contains(_query.toLowerCase()),
            )
            .toList();
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {
              _close();
              _focus.unfocus();
            },
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: up ? Alignment.topLeft : Alignment.bottomLeft,
            followerAnchor: up ? Alignment.bottomLeft : Alignment.topLeft,
            child: TextFieldTapRegion(
              child: Material(
                elevation: 4,
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: rect.width,
                    maxHeight: maxHeight,
                  ),
                  child: SizedBox(
                    width: rect.width,
                    child:
                        matches.isEmpty
                            ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No options found'),
                            )
                            : ListView.builder(
                              key: Key('rx_dropdown_${widget.field.header}'),
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: matches.length,
                              itemBuilder: (context, index) {
                                final choice = matches[index];
                                final duplicate =
                                    matches
                                        .where((c) => c.name == choice.name)
                                        .length >
                                    1;
                                return InkWell(
                                  key: Key('rx_choice_${choice.id}'),
                                  onTap: () {
                                    _close();
                                    widget.controller.text = choice.name;
                                    widget.onChoice(choice);
                                    _focus.unfocus();
                                  },
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 48,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            choice.name,
                                            style: rxNativeText(
                                              16,
                                              color: Colors.black,
                                            ),
                                          ),
                                          if (choice.note.isNotEmpty ||
                                              duplicate)
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
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _close();
    WidgetsBinding.instance.removeObserver(this);
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.field.isDate, drop = widget.field.lookup.isNotEmpty;
    return CompositedTransformTarget(
      link: _link,
      child: Material(
        color: Colors.white,
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
          style: rxNativeText(16, color: Colors.black),
          minLines: 1,
          maxLines: widget.field.numeric ? 1 : null,
          keyboardType:
              widget.field.numeric || widget.field.header == 'P_DURATION'
                  ? TextInputType.number
                  : TextInputType.text,
          textInputAction: TextInputAction.done,
          onTap:
              date
                  ? widget.onPick
                  : drop
                  ? _open
                  : null,
          onChanged: (text) {
            widget.onChanged(text);
            if (drop) {
              _query = text;
              if (_entry == null) {
                _open();
                _query = text;
              }
              _entry?.markNeedsBuild();
            }
          },
          onEditingComplete: () {
            _close();
            _focus.unfocus();
          },
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: rxNativeText(16),
            floatingLabelStyle: rxNativeText(16),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            filled: true,
            fillColor: Colors.white,
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
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xff757575),
                      ),
                      onPressed: widget.enabled ? _open : null,
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
