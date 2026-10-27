import 'package:flutter/material.dart';

import 'native_dynamic_rx_controls.dart';
import 'native_dynamic_rx_icons.dart';

/// The same native expandable-section component used by Clinical.
/// Expansion belongs to the section, not to a modal edit sheet.
class NativeDynamicRxSection extends StatefulWidget {
  const NativeDynamicRxSection({
    super.key,
    required this.id,
    required this.title,
    required this.icon,
    required this.badge,
    required this.empty,
    required this.onAdd,
    required this.rows,
    this.initiallyExpanded = false,
  });
  final String id, title, badge, empty;
  final DynamicRxGlyph icon;
  final VoidCallback onAdd;
  final List<Widget> rows;
  final bool initiallyExpanded;
  @override
  State<NativeDynamicRxSection> createState() => _RxSectionState();
}

class DynamicRxRowDetail {
  const DynamicRxRowDetail(
    this.text, {
    this.size = 8,
    this.top = 2,
    this.maxLines,
    this.color = DynamicRxColors.secondary,
    this.weight = FontWeight.w400,
  });
  final String text;
  final double size, top;
  final int? maxLines;
  final Color color;
  final FontWeight weight;
}

/// Native medicine/clinical row adapters share the same edit and delete controls.
class NativeDynamicRxEntryRow extends StatelessWidget {
  const NativeDynamicRxEntryRow({
    super.key,
    required this.id,
    required this.title,
    required this.onEdit,
    required this.onDelete,
    this.details = const [],
    this.medicine = false,
  });
  final String id, title;
  final VoidCallback onEdit, onDelete;
  final List<DynamicRxRowDetail> details;
  final bool medicine;
  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context);
    Widget action(
      DynamicRxGlyph glyph,
      String name,
      VoidCallback onTap,
      Color color,
    ) => SizedBox.square(
      dimension: m.d(30),
      child: IconButton(
        key: Key('dy_${name}_$id'),
        tooltip: '${name == 'edit' ? 'Edit' : 'Delete'} $title',
        padding: EdgeInsets.all(m.d(6)),
        onPressed: onTap,
        icon: NativeDynamicRxIcon(glyph, size: m.d(18), color: color),
      ),
    );
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(m.d(7)),
      child: InkWell(
        key: Key('dy_row_$id'),
        onTap: onEdit,
        borderRadius: BorderRadius.circular(m.d(7)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: m.d(
              medicine
                  ? 60
                  : details.isEmpty
                  ? 42
                  : 48,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              m.d(10),
              m.d(medicine ? 7 : 6),
              m.d(5),
              m.d(medicine ? 7 : 6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: m.text(
                          9,
                          weight: medicine ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      for (final detail in details)
                        Padding(
                          padding: EdgeInsets.only(top: m.d(detail.top)),
                          child: Text(
                            detail.text,
                            maxLines: detail.maxLines,
                            overflow:
                                detail.maxLines == null
                                    ? null
                                    : TextOverflow.ellipsis,
                            style: m.text(
                              detail.size,
                              color: detail.color,
                              weight: detail.weight,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: m.d(medicine ? 6 : 5)),
                action(
                  DynamicRxGlyph.edit,
                  'edit',
                  onEdit,
                  DynamicRxColors.primary,
                ),
                SizedBox(width: m.d(2)),
                action(
                  DynamicRxGlyph.delete,
                  'delete',
                  onDelete,
                  DynamicRxColors.error,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RxSectionState extends State<NativeDynamicRxSection> {
  late bool _expanded;
  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context),
        id = widget.id,
        title = widget.title,
        icon = widget.icon,
        badge = widget.badge,
        empty = widget.empty,
        add = widget.onAdd,
        rows = widget.rows;
    final expanded = _expanded;
    void toggle() => setState(() => _expanded = !expanded);
    return Card(
      key: Key('dy_section_$id'),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: m.d(1),
      margin: EdgeInsets.only(top: m.d(5)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(m.d(8)),
        side: const BorderSide(color: DynamicRxColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('dy_toggle_$id'),
            onTap: toggle,
            child: SizedBox(
              height: m.d(50),
              child: Padding(
                padding: EdgeInsets.only(left: m.d(8), right: m.d(5)),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: m.d(30),
                      child: Padding(
                        padding: EdgeInsets.all(m.d(6)),
                        child: NativeDynamicRxIcon(icon),
                      ),
                    ),
                    SizedBox(width: m.d(8)),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: m.text(11, weight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(width: m.d(5)),
                    Container(
                      height: m.d(25),
                      constraints: BoxConstraints(minWidth: m.d(25)),
                      padding: EdgeInsets.symmetric(
                        horizontal: m.d(6),
                        vertical: m.d(2),
                      ),
                      decoration: BoxDecoration(
                        color: DynamicRxColors.light,
                        borderRadius: BorderRadius.circular(m.d(50)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge,
                        key: Key('dy_count_$id'),
                        style: m.text(
                          8,
                          weight: FontWeight.w700,
                          color: DynamicRxColors.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: m.d(3)),
                    SizedBox.square(
                      dimension: m.d(25),
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(
                          side: BorderSide(color: DynamicRxColors.primary),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: Key('dy_add_$id'),
                          onTap: () {
                            setState(() => _expanded = true);
                            add();
                          },
                          child: Padding(
                            padding: EdgeInsets.all(m.d(6)),
                            child: const NativeDynamicRxIcon(
                              DynamicRxGlyph.add,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: m.d(30),
                      height: m.d(50),
                      child: IconButton(
                        tooltip: expanded ? 'Collapse $title' : 'Expand $title',
                        padding: EdgeInsets.all(m.d(7)),
                        onPressed: toggle,
                        icon: NativeDynamicRxIcon(
                          expanded
                              ? DynamicRxGlyph.expandLess
                              : DynamicRxGlyph.expandMore,
                          color: DynamicRxColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child:
                !expanded
                    ? const SizedBox.shrink()
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: DynamicRxColors.outline,
                        ),
                        if (rows.isEmpty)
                          SizedBox(
                            height: m.d(48),
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: m.d(10),
                                ),
                                child: Text(
                                  empty,
                                  style: m.text(
                                    9,
                                    color: DynamicRxColors.secondary,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              m.d(5),
                              m.d(4),
                              m.d(5),
                              m.d(5),
                            ),
                            child: Column(children: rows),
                          ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
