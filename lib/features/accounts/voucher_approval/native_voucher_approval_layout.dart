import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../voucher_transaction/native_voucher_controls.dart';
import 'voucher_approval_models.dart';

const approvalPending = Color(0xffc23616);

class ApprovalButton extends StatelessWidget {
  const ApprovalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.report = false,
    this.child,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool report;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    return Material(
      elevation: 2,
      color: DocColors.primary,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side:
            report
                ? const BorderSide(color: DocColors.greenSea)
                : BorderSide.none,
      ),
      child: InkWell(
        onTap: onPressed,
        child: Container(
          constraints: BoxConstraints(minHeight: report ? 56 : 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          alignment: Alignment.center,
          child:
              child ??
              Text(
                label,
                textAlign: TextAlign.center,
                style: vtText(
                  report ? 9 : 13,
                  s,
                  family: report ? 'RussoOne' : 'PatuaOne',
                  color: Colors.white,
                ),
              ),
        ),
      ),
    );
  }
}

class ApprovalVoucherField extends StatelessWidget {
  const ApprovalVoucherField({
    super.key,
    required this.number,
    required this.onTap,
  });
  final String number;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    return Material(
      color: Colors.white,
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: DocColors.primary),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8 * s),
          child: Row(
            children: [
              Icon(Icons.search, color: Colors.black, size: 20 * s),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Voucher No',
                      style: vtText(
                        10,
                        s,
                        family: 'Poppins',
                        weight: FontWeight.w500,
                      ),
                    ),
                    if (number.isNotEmpty)
                      Text(
                        number,
                        key: const Key('va_number'),
                        style: vtText(
                          9.5,
                          s,
                          family: 'Poppins',
                          color: Colors.black,
                          weight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NativeVoucherApprovalLayout extends StatelessWidget {
  const NativeVoucherApprovalLayout({
    super.key,
    required this.rows,
    required this.kind,
    required this.selected,
    required this.detail,
    required this.scroll,
    required this.horizontal,
    required this.onSelect,
    required this.onReport,
    required this.onAction,
  });
  final List<ApprovalVoucher> rows;
  final VoucherApprovalKind kind;
  final ApprovalVoucher? selected;
  final ApprovalVoucherDetail? detail;
  final ScrollController scroll, horizontal;
  final VoidCallback? onSelect, onReport, onAction;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context), d = detail;
    Widget count(String label, int value, Color color, String key) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 45,
            child: Text(label, style: vtText(10, s, family: 'Poppins')),
          ),
          Expanded(
            flex: 5,
            child: Text(':', style: vtText(10, s, family: 'Poppins')),
          ),
          Expanded(
            flex: 50,
            child: Text(
              '$value',
              key: Key(key),
              textAlign: TextAlign.end,
              style: vtText(11, s, family: 'Poppins', color: color),
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const Key('va_scroll'),
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: DocColors.greenSea),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        count(
                          'Voucher Pending',
                          rows.where((r) => !r.approved).length,
                          approvalPending,
                          'va_pending',
                        ),
                        count(
                          'Voucher Approved',
                          rows.where((r) => r.approved).length,
                          DocColors.greenSea,
                          'va_approved',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ApprovalVoucherField(
                        key: const Key('va_select'),
                        number: selected?.number ?? '',
                        onTap: onSelect,
                      ),
                    ),
                    if (d != null && !d.empty) ...[
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 84,
                        child: ApprovalButton(
                          key: const Key('va_report'),
                          label: 'REPORT',
                          onPressed: onReport,
                          report: true,
                        ),
                      ),
                    ],
                  ],
                ),
                if (d != null) ...[
                  const SizedBox(height: 16),
                  if (d.empty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No Voucher Details Found',
                        textAlign: TextAlign.center,
                        style: vtText(11, s, family: 'Poppins'),
                      ),
                    )
                  else
                    _detail(context, d, s),
                ],
              ],
            ),
          ),
        ),
        if (d != null && !d.empty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: ApprovalButton(
              key: const Key('va_action'),
              label: d.action.label.toUpperCase(),
              onPressed: onAction,
            ),
          ),
      ],
    );
  }

  Widget _detail(BuildContext context, ApprovalVoucherDetail d, double s) {
    Widget field(
      String label,
      String value, {
      Color fill = vtDisabled,
      String? key,
    }) => Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6 * s),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: vtText(
              9.5,
              s,
              family: 'Ubuntu',
              weight: FontWeight.w500,
              color: const Color(0xff999999),
            ),
          ),
          Text(
            value,
            key: key == null ? null : Key(key),
            style: vtText(9.5, s, family: 'Ubuntu', color: Colors.black),
          ),
        ],
      ),
    );
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 5),
        Expanded(child: b),
      ],
    );
    final v = d.voucher;
    return Material(
      key: const Key('va_detail'),
      elevation: 2,
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            pair(
              field('Date:', d.value('vm_date')),
              field('Time:', d.value('vm_time')),
            ),
            const SizedBox(height: 5),
            field('Prepared By:', d.value('vm_user')),
            const SizedBox(height: 5),
            field(
              'Status:',
              v.status,
              fill: const Color(0xffffeaa7),
              key: 'va_status',
            ),
            const SizedBox(height: 5),
            pair(
              field('Bill Ref No:', d.value('vm_bill_ref_no')),
              field('Bill Ref Date:', d.value('vm_bill_ref_date')),
            ),
            const SizedBox(height: 5),
            field(v.auditUserLabel, v.auditUser, key: 'va_audit_user'),
            const SizedBox(height: 5),
            field(v.auditTimeLabel, v.value('approved_date')),
            const SizedBox(height: 5),
            field(kind.narrationLabel, d.value('vm_naration')),
            const SizedBox(height: 10),
            NativeApprovalLedger(detail: d, horizontal: horizontal),
          ],
        ),
      ),
    );
  }
}

class NativeApprovalLedger extends StatelessWidget {
  const NativeApprovalLedger({
    super.key,
    required this.detail,
    required this.horizontal,
  });
  final ApprovalVoucherDetail detail;
  final ScrollController horizontal;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context),
        factor = math.max(
          1.0,
          MediaQuery.textScalerOf(context).scale(12) / 12 / 1.3,
        ),
        widths =
            [
              91.0,
              191.0,
              111.0,
              111.0,
              111.0,
              111.0,
            ].map((w) => w * factor).toList(),
        style = vtText(9, s),
        headerStyle = vtText(9, s, family: 'Archivo', color: Colors.white),
        totalStyle = vtText(10, s, family: 'Poppins', color: Colors.black);
    Widget row(List<String> values, {bool heading = false}) {
      final st = heading ? headerStyle : style;
      final height = List.generate(
        6,
        (i) => voucherTextHeight(
          context,
          values[i],
          widths[i],
          st,
          vertical: 4 * s,
          minimum: 24,
        ),
      ).reduce(math.max);
      return DecoratedBox(
        decoration: BoxDecoration(
          color: heading ? DocColors.greenSea : vtDisabled,
          border: Border(
            bottom: BorderSide(
              color: heading ? Colors.black : const Color(0xffd4d4d4),
            ),
          ),
        ),
        child: Row(
          children: [
            for (var i = 0; i < 6; i++)
              voucherCell(
                width: widths[i],
                height: height,
                text: values[i],
                style: st,
                border: i < 5,
                line: heading ? Colors.white : Colors.black,
              ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      key: const Key('va_horizontal'),
      controller: horizontal,
      scrollDirection: Axis.horizontal,
      child: Container(
        width: widths.reduce((a, b) => a + b) + 2,
        decoration: BoxDecoration(border: Border.all(color: Colors.black)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row([
              'A/C No',
              'A/C Details',
              'Cheque No.',
              'Cheque Date',
              'Debit',
              'Credit',
            ], heading: true),
            for (final l in detail.lines)
              row([
                l.value('ad_code'),
                l.value('ad_name'),
                l.value('vd_cheque_no'),
                l.value('vd_cheque_date'),
                l.value('vd_dr_amt'),
                l.value('vd_cr_amt'),
              ]),
            const Divider(height: 1, thickness: 1, color: Colors.black),
            Builder(
              builder: (context) {
                final debit = approvalAmount(detail.debit),
                    credit = approvalAmount(detail.credit),
                    height = math.max(
                      29.0,
                      math.max(
                        voucherTextHeight(
                          context,
                          debit,
                          widths[4],
                          totalStyle,
                        ),
                        voucherTextHeight(
                          context,
                          credit,
                          widths[5],
                          totalStyle,
                        ),
                      ),
                    );
                return Row(
                  children: [
                    voucherCell(
                      width: widths.take(4).reduce((a, b) => a + b),
                      height: height,
                      text: '',
                      style: totalStyle,
                    ),
                    voucherCell(
                      width: widths[4],
                      height: height,
                      text: debit,
                      style: totalStyle,
                      key: const Key('va_total_debit'),
                    ),
                    voucherCell(
                      width: widths[5],
                      height: height,
                      text: credit,
                      style: totalStyle,
                      key: const Key('va_total_credit'),
                      border: false,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
