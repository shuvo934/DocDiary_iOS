import 'package:flutter/material.dart';

import 'dynamic_prescription_review_models.dart';
import 'native_dynamic_rx_controls.dart';
import 'native_dynamic_rx_icons.dart';

/// fragment_prescription_review.xml, view_prescription_review_summary.xml,
/// item_prescription_review_row.xml. Section badges count populated categories.
class NativeDynamicReviewTab extends StatefulWidget {
  const NativeDynamicReviewTab({
    super.key,
    required this.review,
    required this.onEdit,
  });
  final DynamicPrescriptionReview review;
  final ValueChanged<int> onEdit;
  @override
  State<NativeDynamicReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<NativeDynamicReviewTab>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  @override
  bool get wantKeepAlive => true;
  TextStyle _sp(
    DynamicRxMetrics m,
    double value, {
    Color color = DynamicRxColors.text,
    FontWeight weight = FontWeight.w400,
  }) =>
      m.text(value, color: color, weight: weight).copyWith(fontSize: value - 1);
  Widget _status(DynamicRxMetrics m) {
    final ready = widget.review.hasRx;
    return Container(
      key: const Key('dy_review_status'),
      margin: EdgeInsets.only(top: m.d(4)),
      decoration: BoxDecoration(
        color: ready ? const Color(0xfff2fbf6) : const Color(0xfffffaeb),
        borderRadius: BorderRadius.circular(m.d(10)),
        border: Border.all(
          color: ready ? const Color(0xffb7e4c7) : const Color(0xfffedf89),
        ),
      ),
      padding: EdgeInsets.all(m.d(8)),
      child: Row(
        children: [
          Container(
            width: m.d(24),
            height: m.d(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ready ? const Color(0xff27ae60) : const Color(0xfff79009),
            ),
            child: NativeDynamicRxIcon(
              ready
                  ? DynamicRxGlyph.reviewReady
                  : DynamicRxGlyph.reviewAttention,
              size: m.d(20),
              color: Colors.white,
            ),
          ),
          SizedBox(width: m.d(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready ? 'Ready for final review' : 'Rx information required',
                  style: m.text(
                    9,
                    weight: FontWeight.w500,
                    color:
                        ready
                            ? const Color(0xff1b8f4b)
                            : const Color(0xffb54708),
                  ),
                ),
                Text(
                  ready
                      ? 'Verify the details and confirm below to enable Generate.'
                      : 'Add at least one Rx item before generating.',
                  style: m.text(7, color: DynamicRxColors.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    String id,
    String title,
    DynamicRxGlyph icon,
    int tab,
    List<DynamicReviewRow> rows,
    DynamicRxMetrics m,
  ) => Card(
    key: Key('dy_review_$id'),
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: m.d(1),
    margin: EdgeInsets.only(top: m.d(5)),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(m.d(10)),
      side: const BorderSide(color: Color(0xffe4e7ec)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: m.d(52),
          child: Padding(
            padding: EdgeInsets.only(left: m.d(10), right: m.d(8)),
            child: Row(
              children: [
                Container(
                  width: m.d(34),
                  height: m.d(34),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xffeaf7f8),
                    borderRadius: BorderRadius.circular(m.d(8)),
                  ),
                  child: NativeDynamicRxIcon(icon, size: m.d(19)),
                ),
                SizedBox(width: m.d(9)),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _sp(
                            m,
                            13,
                            color: const Color(0xff101828),
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: m.d(7)),
                      Container(
                        height: m.d(23),
                        alignment: Alignment.center,
                        padding: EdgeInsets.symmetric(horizontal: m.d(7)),
                        decoration: BoxDecoration(
                          color: const Color(0xffe8f7f8),
                          borderRadius: BorderRadius.circular(m.d(12)),
                        ),
                        child: Text(
                          DynamicPrescriptionReview.badge(rows.length),
                          key: Key('dy_review_count_$id'),
                          style: _sp(
                            m,
                            9,
                            color: const Color(0xff159aa5),
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox.square(
                  dimension: m.d(36),
                  child: IconButton(
                    key: Key('dy_review_edit_$id'),
                    tooltip: 'Edit $title',
                    padding: EdgeInsets.all(m.d(9)),
                    onPressed: () => widget.onEdit(tab),
                    icon: NativeDynamicRxIcon(
                      DynamicRxGlyph.edit,
                      size: m.d(18),
                      color: const Color(0xff50c2c0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xffeef1f4)),
        if (rows.isEmpty)
          SizedBox(
            height: m.d(52),
            child: Center(
              child: Text(
                'No information added',
                style: _sp(m, 11, color: const Color(0xff98a2b3)),
              ),
            ),
          )
        else
          for (var i = 0; i < rows.length; i++) ...[
            SizedBox(
              height: m.d(34),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: m.d(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        rows[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _sp(m, 11, color: const Color(0xff475467)),
                      ),
                    ),
                    Text(
                      rows[i].value,
                      style: _sp(
                        m,
                        11,
                        color: const Color(0xff344054),
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i != rows.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: m.d(12)),
                child: const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xffeef1f4),
                ),
              ),
          ],
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final m = DynamicRxMetrics(context);
    return ColoredBox(
      color: Colors.white,
      child: ListenableBuilder(
        listenable: widget.review,
        builder:
            (context, _) => SingleChildScrollView(
              key: const PageStorageKey<String>('dynamic_review_scroll'),
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(m.d(4), m.d(4), m.d(4), m.d(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _status(m),
                  _section(
                    'clinical',
                    'Clinical',
                    DynamicRxGlyph.stethoscope,
                    0,
                    widget.review.clinicalRows,
                    m,
                  ),
                  _section(
                    'rx',
                    'Rx',
                    DynamicRxGlyph.pill,
                    1,
                    widget.review.rxRows,
                    m,
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: m.d(5)),
                    child: _section(
                      'advice',
                      'Advice & Follow-up',
                      DynamicRxGlyph.advice,
                      2,
                      widget.review.adviceRows,
                      m,
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}
