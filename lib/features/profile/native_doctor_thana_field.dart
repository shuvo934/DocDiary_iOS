import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'doctor_address_repository.dart';

/// Anchored, searchable Android-style dropdown; the district stays read-only.
class NativeDoctorThanaField extends StatefulWidget {
  const NativeDoctorThanaField({
    super.key,
    required this.controller,
    required this.focus,
    required this.items,
    required this.decoration,
    required this.style,
    required this.onChanged,
    required this.onSelected,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final List<DoctorThana> items;
  final InputDecoration decoration;
  final TextStyle style;
  final ValueChanged<String> onChanged;
  final ValueChanged<DoctorThana> onSelected;
  @override
  State<NativeDoctorThanaField> createState() => _NativeDoctorThanaFieldState();
}

class _NativeDoctorThanaFieldState extends State<NativeDoctorThanaField>
    with WidgetsBindingObserver {
  final _link = LayerLink();
  final _target = GlobalKey();
  OverlayEntry? _popup;
  bool _all = false;

  @override
  void initState() {
    super.initState();
    widget.focus.addListener(_focusChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  void _focusChanged() {
    if (!widget.focus.hasFocus) {
      _hide();
    }
  }

  List<DoctorThana> get _options {
    final query = widget.controller.text.toLowerCase();
    return widget.items
        .where(
          (item) =>
              item.name.isNotEmpty &&
              (_all ||
                  item.name.toLowerCase().startsWith(query) ||
                  item.name
                      .toLowerCase()
                      .split(RegExp(r'\s+'))
                      .any((word) => word.startsWith(query))),
        )
        .toList(growable: false);
  }

  void _hide() {
    _popup?.remove();
    _popup?.dispose();
    _popup = null;
  }

  void _show({bool all = false}) {
    _all = all;
    if (_options.isEmpty || (!all && widget.controller.text.length < 2)) {
      _hide();
      return;
    }
    if (_popup != null) {
      _popup!.markNeedsBuild();
      return;
    }
    _popup = OverlayEntry(builder: _buildPopup);
    Overlay.of(context).insert(_popup!);
  }

  @override
  void didUpdateWidget(NativeDoctorThanaField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focus != widget.focus) {
      oldWidget.focus.removeListener(_focusChanged);
      widget.focus.addListener(_focusChanged);
      _hide();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _popup?.markNeedsBuild();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _hide();
    }
  }

  Widget _buildPopup(BuildContext overlayContext) {
    final box = _target.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return const SizedBox.shrink();
    }
    final origin = box.localToGlobal(Offset.zero);
    final media = MediaQuery.of(overlayContext);
    final below = math.max(
      0.0,
      media.size.height -
          media.viewInsets.bottom -
          media.padding.bottom -
          origin.dy -
          box.size.height -
          8,
    );
    final above = math.max(0.0, origin.dy - media.padding.top - 8);
    final up = below < 120 && above > below;
    final height = math.min(240.0, up ? above : below);
    final options = _options;
    if (height < 1 || options.isEmpty) {
      return const SizedBox.shrink();
    }
    return Positioned(
      width: box.size.width,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: up ? Alignment.topLeft : Alignment.bottomLeft,
        followerAnchor: up ? Alignment.bottomLeft : Alignment.topLeft,
        offset: Offset(0, up ? -2 : 2),
        child: TextFieldTapRegion(
          child: Material(
            key: const Key('address_thana_options'),
            color: Colors.white,
            elevation: 8,
            borderRadius: BorderRadius.circular(4),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: height),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder:
                    (context, index) => InkWell(
                      key: Key(
                        'address_thana_option_${options[index].id}_$index',
                      ),
                      onTap: () {
                        final selected = options[index];
                        _hide();
                        widget.onSelected(selected);
                        widget.focus.unfocus();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          options[index].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            color: Colors.black,
                          ),
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

  @override
  void dispose() {
    _hide();
    widget.focus.removeListener(_focusChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    key: _target,
    link: _link,
    child: TextField(
      key: const Key('address_thana'),
      controller: widget.controller,
      focusNode: widget.focus,
      style: widget.style,
      cursorColor: DocColors.greenSea,
      textInputAction: TextInputAction.done,
      decoration: widget.decoration.copyWith(
        suffixIcon: IconButton(
          key: const Key('address_thana_dropdown'),
          tooltip: 'Show Thana/Upazila',
          color: Colors.black54,
          icon: const Icon(Icons.arrow_drop_down),
          onPressed: () {
            if (_popup != null) {
              _hide();
            } else {
              widget.focus.requestFocus();
              _show(all: true);
            }
          },
        ),
      ),
      onTap: () {
        if (widget.controller.text.length >= 2) {
          _show();
        }
      },
      onChanged: (value) {
        widget.onChanged(value);
        _show();
      },
      onTapOutside: (_) {
        widget.focus.unfocus();
        _hide();
      },
      onSubmitted: (_) => widget.focus.unfocus(),
    ),
  );
}
