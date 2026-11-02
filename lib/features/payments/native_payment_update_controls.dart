import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import 'native_payment_controls.dart';
import 'payment_models.dart';
import 'payment_update_models.dart';

class NativePaymentQuantitySummary extends StatelessWidget {
  const NativePaymentQuantitySummary({
    super.key,
    required this.row,
    required this.available,
  });
  final PaymentUpdateLine row;
  final int available;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    Widget cell(String title, int value) => Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 7 * s),
      decoration: BoxDecoration(
        color: const Color(0xfff5f5f5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: adminAppointmentText(
              10,
              s,
              family: 'Roboto',
              color: const Color(0xff999999),
            ),
          ),
          Text('$value', style: adminAppointmentText(10, s, family: 'Roboto')),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cell('Schedule:', row.schedule)),
              const SizedBox(width: 5),
              Expanded(child: cell('Cancel:', row.cancel)),
              const SizedBox(width: 5),
              Expanded(child: cell('Return:', row.returned)),
            ],
          ),
        ),
        const SizedBox(height: 5),
        cell('Available Quantity:', available),
      ],
    );
  }
}

class NativePaymentAvailabilityDialog extends StatelessWidget {
  const NativePaymentAvailabilityDialog({super.key, required this.row});
  final PaymentUpdateLine row;
  @override
  Widget build(BuildContext context) {
    final lines = [
      ('Total Quantity:', row.line.quantity),
      ('Schedule Taken:', row.schedule),
      ('Cancel:', row.cancel),
      ('Return:', row.returned),
      ('Available Quantity:', row.available),
    ];
    return AlertDialog(
      key: const Key('payment_update_quantities'),
      title: Text(row.line.service.name, style: dashboardDialogText(20)),
      content: SingleChildScrollView(
        child: Text.rich(
          TextSpan(
            children: [
              for (final line in lines) ...[
                TextSpan(
                  text: '${line.$1}  ',
                  style: dashboardDialogText(
                    16,
                    color: const Color(0xff777777),
                  ),
                ),
                TextSpan(
                  text: '${line.$2}\n',
                  style: dashboardDialogText(16, weight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('payment_update_quantity_close'),
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE'),
        ),
      ],
    );
  }
}

const paymentUpdateWeights = [42, 12, 12, 16, 18];

class NativePaymentUpdateServices extends StatelessWidget {
  const NativePaymentUpdateServices({
    super.key,
    required this.lines,
    required this.onAdd,
    required this.onEdit,
    required this.onAvailability,
  });
  final List<PaymentUpdateLine> lines;
  final VoidCallback? onAdd;
  final ValueChanged<PaymentUpdateLine>? onEdit, onAvailability;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context),
        style = adminAppointmentText(
          9,
          s,
          family: 'OpenSans',
          weight: FontWeight.w700,
          color: const Color(0xff6c6e6f),
        );
    Widget detail(String label, String value) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(label, style: style.copyWith(color: Colors.black)),
        ),
        Expanded(flex: 6, child: Text(value, style: style)),
      ],
    );
    return Material(
      elevation: 2,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NativePaymentGrid(
            weights: paymentUpdateWeights,
            color: DocColors.primary,
            cells: [
              for (final label in ['Service & Unit', 'Qty', 'Rate', 'Amount'])
                NativePaymentNumber(
                  label,
                  style: adminAppointmentText(
                    10,
                    s,
                    family: 'PatuaOne',
                    color: Colors.white,
                  ),
                ),
              Center(
                child: Text(
                  'Available\nQty',
                  textAlign: TextAlign.center,
                  style: adminAppointmentText(
                    10,
                    s,
                    family: 'PatuaOne',
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: InkWell(
                key: Key('payment_update_service_row_$i'),
                onTap: onEdit == null ? null : () => onEdit!(lines[i]),
                child: NativePaymentGrid(
                  weights: paymentUpdateWeights,
                  cells: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        detail('Service:', lines[i].line.service.name),
                        const SizedBox(height: 4),
                        detail('Unit:', lines[i].line.unit.name),
                      ],
                    ),
                    NativePaymentNumber(
                      '${lines[i].line.quantity}',
                      style: style,
                    ),
                    NativePaymentNumber(
                      paymentMoney(lines[i].line.rate.cents),
                      style: style,
                    ),
                    NativePaymentNumber(
                      paymentMoney(lines[i].line.amount),
                      style: style,
                    ),
                    InkWell(
                      key: Key('payment_update_available_$i'),
                      onTap:
                          onAvailability == null
                              ? null
                              : () => onAvailability!(lines[i]),
                      child: NativePaymentNumber(
                        '${lines[i].available}',
                        style: style,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 2, thickness: 1.3, color: Colors.black),
          if (lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  Expanded(
                    flex: 66,
                    child: Text(
                      'Total Amount',
                      style: adminAppointmentText(
                        11,
                        s,
                        family: 'RussoOne',
                        color: const Color(0xff777777),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 16,
                    child: Text(
                      paymentMoney(
                        lines.fold<int>(0, (n, r) => n + r.line.amount),
                      ),
                      key: const Key('payment_update_total'),
                      textAlign: TextAlign.center,
                      style: adminAppointmentText(
                        11,
                        s,
                        family: 'RussoOne',
                        color: const Color(0xff777777),
                      ),
                    ),
                  ),
                  const Spacer(flex: 18),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: NativePaymentPill(
                key: const Key('payment_update_add_service'),
                label: 'ADD SERVICE',
                onPressed: onAdd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
