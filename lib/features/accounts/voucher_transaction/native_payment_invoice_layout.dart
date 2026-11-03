import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import 'native_voucher_controls.dart';
import 'voucher_models.dart';

class NativePaymentInvoiceLayout extends StatelessWidget {
  const NativePaymentInvoiceLayout({
    super.key,
    required this.invoice,
    required this.scroll,
  });
  final PaymentInvoiceData invoice;
  final ScrollController scroll;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    Widget field(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: vtText(
            8,
            s,
            color: vtCloud,
            family: 'Poppins',
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(value, style: vtText(9, s, family: 'Poppins')),
      ],
    );
    Widget pair(String labelA, String keyA, String labelB, String keyB) =>
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4 * s),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field(labelA, invoice.field(keyA))),
              const SizedBox(width: 12),
              Expanded(child: field(labelB, invoice.field(keyB))),
            ],
          ),
        );
    Widget info(String label, String value, {bool outline = false, Key? key}) =>
        Container(
          key: key,
          margin: EdgeInsets.only(bottom: outline ? 4 * s : 0),
          constraints: BoxConstraints(minHeight: outline ? 34 : 24),
          padding: EdgeInsets.symmetric(
            horizontal: 5,
            vertical: outline ? 5 : 2,
          ),
          decoration:
              outline
                  ? BoxDecoration(
                    border: Border.all(color: DocColors.greenSea),
                    borderRadius: BorderRadius.circular(10),
                  )
                  : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  label,
                  style: vtText(
                    8,
                    s,
                    family: 'Poppins',
                    color: outline ? vtTextColor : vtCloud,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  ':',
                  textAlign: TextAlign.center,
                  style: vtText(8, s, color: vtCloud),
                ),
              ),
              Expanded(
                flex: 6,
                child: Text(
                  value,
                  style: vtText(
                    outline ? 10 : 9,
                    s,
                    family: 'Poppins',
                    color: outline ? DocColors.greenSea : vtTextColor,
                  ),
                ),
              ),
            ],
          ),
        );
    Widget summary(String label, VtMoney value, String key) => Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: DocColors.greenSea),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: vtText(
                9,
                s,
                family: 'Poppins',
                color: Colors.black,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(':', textAlign: TextAlign.center, style: vtText(8, s)),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value.currency,
              key: Key(key),
              textAlign: TextAlign.end,
              style: vtText(10, s, family: 'Poppins', color: Colors.black),
            ),
          ),
        ],
      ),
    );
    Widget item(InvoiceLine line, int i) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: DocColors.greenSea),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SL. No : ',
                  style: vtText(
                    9,
                    s,
                    family: 'Poppins',
                    color: Colors.black,
                    weight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${i + 1}',
                  key: Key('invoice_serial_$i'),
                  style: vtText(
                    11,
                    s,
                    family: 'Poppins',
                    color: DocColors.greenSea,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 5 * s),
        Text(
          'Payment Service Name :',
          style: vtText(8, s, family: 'Poppins', weight: FontWeight.w600),
        ),
        SizedBox(height: 4 * s),
        Text(
          line.service,
          key: Key('invoice_service_$i'),
          style: vtText(9, s, family: 'Poppins', color: Colors.black),
        ),
        SizedBox(height: 7 * s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unit Name :',
                    style: vtText(
                      8,
                      s,
                      family: 'Poppins',
                      weight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4 * s),
                  Text(
                    line.unit,
                    style: vtText(9, s, family: 'Poppins', color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Quantity :',
                    style: vtText(
                      8,
                      s,
                      family: 'Poppins',
                      weight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4 * s),
                  Text(
                    line.quantity.text,
                    style: vtText(9, s, family: 'Poppins', color: Colors.black),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 8 * s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child:
                  line.month.isEmpty
                      ? const SizedBox()
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Month For :',
                            style: vtText(
                              8,
                              s,
                              family: 'Poppins',
                              weight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4 * s),
                          Text(
                            line.month,
                            key: Key('invoice_month_$i'),
                            style: vtText(
                              9,
                              s,
                              family: 'Poppins',
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rate :',
                    style: vtText(
                      8,
                      s,
                      family: 'Poppins',
                      weight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4 * s),
                  Text(
                    line.rateLabel,
                    style: vtText(9, s, family: 'Poppins', color: Colors.black),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 7 * s),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffb2bec3), width: 1.8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Total Amount',
                  style: vtText(
                    8,
                    s,
                    family: 'Poppins',
                    color: Colors.black,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  ':',
                  textAlign: TextAlign.center,
                  style: vtText(8, s),
                ),
              ),
              Expanded(
                flex: 6,
                child: Text(
                  line.amountLabel,
                  key: Key('invoice_line_amount_$i'),
                  textAlign: TextAlign.end,
                  style: vtText(9, s, family: 'Poppins', color: Colors.black),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 18 * s, horizontal: 50 * s),
          child: const VoucherDashes(color: Color(0xff888888)),
        ),
      ],
    );
    return SingleChildScrollView(
      key: const Key('invoice_scroll'),
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          info(
            'Payment Code',
            invoice.code,
            outline: true,
            key: const Key('invoice_code'),
          ),
          info('Payment Date', invoice.field('prm_date')),
          info('Patient Name', invoice.field('pat_name')),
          pair(
            'Patient Code :',
            'pat_code',
            'Prescription Code :',
            'ph_sub_code',
          ),
          pair('Age :', 'p_age', 'Gender :', 'gender'),
          pair(
            'Marital Status :',
            'marital_status',
            'Patient Category :',
            'ph_patient_cat',
          ),
          pair('Address :', 'address', 'Phone No :', 'pat_phone'),
          SizedBox(height: 8 * s),
          Material(
            color: Colors.white,
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xffb2bec3), width: 1.8),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(12 * s, 12 * s, 12 * s, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < invoice.lines.length; i++)
                    item(invoice.lines[i], i),
                  summary('Sub Total', invoice.subTotal, 'invoice_subtotal'),
                  if (!invoice.discount.isZero)
                    summary(
                      'Discount (-)',
                      invoice.discount,
                      'invoice_discount',
                    ),
                  if (!invoice.charge.isZero)
                    summary('Service Charge', invoice.charge, 'invoice_charge'),
                  summary(
                    'Grand Total',
                    invoice.grandTotal,
                    'invoice_grandtotal',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
