import 'package:flutter/material.dart';
import 'dynamic_history_models.dart';
import 'native_dynamic_builder_icons.dart';
import 'native_dynamic_rx_controls.dart';

/// One native History row shared by the Builder and read-only PatientSearch.
class NativeDynamicHistoryItemTile extends StatelessWidget {
  const NativeDynamicHistoryItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.isSelected,
    required this.onTap,
    this.keyPrefix = 'dy_history_option',
  });
  final DynamicPrescriptionHistoryItem item;
  final int index;
  final bool isSelected;
  final VoidCallback? onTap;
  final String keyPrefix;
  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context);
    final selected = isSelected;
    Widget optional(
      String value, {
      int lines = 2,
      double size = 7,
      FontWeight weight = FontWeight.w400,
    }) =>
        value.isEmpty
            ? const SizedBox.shrink()
            : Text(
              value,
              maxLines: lines,
              overflow: TextOverflow.ellipsis,
              style: m.text(
                size,
                weight: weight,
                color:
                    size == 8
                        ? const Color(0xff202124)
                        : DynamicRxColors.secondary,
              ),
            );
    return Padding(
      padding: EdgeInsets.only(bottom: m.d(6)),
      child: Material(
        color: selected ? const Color(0xfff2fbf6) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(m.d(8)),
          side: BorderSide(
            color: selected ? const Color(0xff27ae60) : const Color(0xffeaecf0),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('${keyPrefix}_${item.rvmId}_$index'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: m.d(76)),
            child: Padding(
              padding: EdgeInsets.all(m.d(6)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.prescriptionDate,
                          style: m.text(9, weight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(width: m.d(2)),
                      ColoredBox(
                        color: DynamicRxColors.light,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: m.d(5),
                            vertical: m.d(2),
                          ),
                          child: Text(
                            item.code,
                            style: m.text(
                              7,
                              weight: FontWeight.w500,
                              color: DynamicRxColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (item.departmentName.isNotEmpty)
                              SizedBox(height: m.d(3)),
                            optional(
                              item.departmentName,
                              lines: 1,
                              size: 8,
                              weight: FontWeight.w500,
                            ),
                            optional(item.serviceName),
                            optional(item.appointmentText),
                            optional(item.createdByText),
                          ],
                        ),
                      ),
                      SizedBox(width: m.d(2)),
                      SizedBox.square(
                        dimension: m.d(28),
                        child: Padding(
                          padding: EdgeInsets.all(m.d(4)),
                          child: Visibility(
                            visible: selected,
                            maintainState: true,
                            maintainAnimation: true,
                            maintainSize: true,
                            child: const NativeDynamicBuilderIcon(
                              DynamicBuilderGlyph.check,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (item.typeText.isNotEmpty || item.updatedText.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: m.d(2)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.typeText,
                              style: m.text(
                                7,
                                weight: FontWeight.w500,
                                color: DynamicRxColors.primary,
                              ),
                            ),
                          ),
                          if (item.updatedText.isNotEmpty) ...[
                            SizedBox(width: m.d(2)),
                            Flexible(
                              child: Text(
                                item.updatedText,
                                textAlign: TextAlign.end,
                                style: m.text(
                                  7,
                                  color: DynamicRxColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
