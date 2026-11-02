import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../appointments/admin_modify/native_admin_appointment_controls.dart';
import '../profile/native_profile_icons.dart';
import '../reports/native_report_icons.dart';
import 'payment_models.dart';

export '../appointments/admin_modify/native_admin_appointment_controls.dart'
    show
        adminAppointmentScale,
        adminAppointmentText,
        NativeAdminAppointmentField,
        NativeAdminAppointmentButton,
        NativeAdminAppointmentTableRow;

class NativePaymentShell extends StatelessWidget {
  const NativePaymentShell({
    super.key,
    required this.child,
    required this.onBack,
    this.title = 'Payment',
    this.editor = false,
  });
  final Widget child;
  final VoidCallback onBack;
  final String title;
  final bool editor;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: editor ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: editor ? DocColors.clouds : DocColors.primary,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * s,
                  vertical: 7 * s,
                ),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('payment_back'),
                      tooltip: editor ? 'Close' : 'Back',
                      onPressed: onBack,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 40,
                      ),
                      icon:
                          editor
                              ? NativeReportIcon(
                                ReportGlyph.close,
                                size: 21 * s,
                                color: Colors.black,
                              )
                              : NativeProfileIcon(
                                NativeProfileGlyph.back,
                                size: 19 * s,
                                color: Colors.white,
                              ),
                    ),
                    SizedBox(width: 8 * s),
                    Expanded(
                      child: Text(
                        title,
                        style: adminAppointmentText(
                          14,
                          s,
                          weight: FontWeight.w700,
                          color: editor ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (editor)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: DocColors.greenSea,
                )
              else
                const SizedBox(height: 5),
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        editor
                            ? BorderRadius.zero
                            : const BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                  ),
                  child:
                      editor
                          ? child
                          : Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                            child: child,
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NativePaymentEntry extends StatelessWidget {
  const NativePaymentEntry({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.enabled = true,
    this.decimal = false,
  });
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled, decimal;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context),
        fill = enabled ? Colors.white : const Color(0xfff5f5f5);
    final color = enabled ? const Color(0xff6c6e6f) : const Color(0xff999999);
    return Material(
      color: fill,
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: DocColors.primary),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        onChanged: onChanged,
        style: adminAppointmentText(
          11,
          s,
          family: 'Archivo',
          weight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: label,
          constraints: const BoxConstraints(minHeight: 56),
          labelStyle: adminAppointmentText(
            11,
            s,
            family: 'Roboto',
            color: color,
          ),
          floatingLabelStyle: adminAppointmentText(
            11.5,
            s,
            family: 'Roboto',
            color: color,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12 * s,
            vertical: 10 * s,
          ),
          filled: true,
          fillColor: fill,
          border: InputBorder.none,
          disabledBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

class NativePaymentError extends StatelessWidget {
  const NativePaymentError(this.text, {super.key});
  final String? text;
  @override
  Widget build(BuildContext context) =>
      text == null
          ? const SizedBox.shrink()
          : Padding(
            padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
            child: Text(
              text!,
              style: adminAppointmentText(
                10,
                adminAppointmentScale(context),
                family: 'Roboto',
                weight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          );
}

class NativePaymentPill extends StatelessWidget {
  const NativePaymentPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.patua = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool patua;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: DocColors.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(84, 36),
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Text(
      label,
      style: adminAppointmentText(
        11,
        adminAppointmentScale(context),
        family: patua ? 'PatuaOne' : 'Poppins',
        weight: FontWeight.w700,
        color: Colors.white,
      ).copyWith(letterSpacing: .8),
    ),
  );
}

class NativePaymentPatientDetails extends StatelessWidget {
  const NativePaymentPatientDetails({
    super.key,
    required this.patient,
    required this.date,
    this.prescriptionCode,
  });
  final PaymentChoice patient;
  final String date;
  final String? prescriptionCode;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    Widget cell(String label, String value) => Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 5.5 * s),
      decoration: BoxDecoration(
        color: const Color(0xfff5f5f5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: adminAppointmentText(
              10,
              s,
              family: 'Roboto',
              color: const Color(0xff999999),
            ),
          ),
          Text(value, style: adminAppointmentText(10, s, family: 'Roboto')),
        ],
      ),
    );
    Widget pair(String a, String av, String b, String bv) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cell(a, av)),
            const SizedBox(width: 5),
            Expanded(child: cell(b, bv)),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (prescriptionCode != null) ...[
          cell('Prescription Code:', prescriptionCode!),
          const SizedBox(height: 4),
        ],
        cell('Patient Name:', patient.name),
        const SizedBox(height: 4),
        pair('Patient Code:', patient.value('pat_code'), 'Payment Date:', date),
        pair(
          'Age:',
          patient.value('p_age'),
          'Marital Status:',
          patient.value('marital_status'),
        ),
        pair(
          'Gender:',
          patient.value('gender'),
          'Blood Group:',
          patient.value('pat_blood'),
        ),
        pair(
          'Patient Category:',
          patient.value('ph_patient_cat'),
          'Patient Status:',
          patient.value('ph_patient_status'),
        ),
        cell('Address:', patient.value('address')),
      ],
    );
  }
}

const paymentServiceWeights = [45, 13, 17, 17, 8];

/// Header and body share the same flexes and 4dp white gutters.
class NativePaymentGrid extends StatelessWidget {
  const NativePaymentGrid({
    super.key,
    required this.cells,
    required this.weights,
    this.color = DocColors.clouds,
  });
  final List<Widget> cells;
  final List<int> weights;
  final Color color;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cells.length; i++)
          Expanded(
            flex: weights[i],
            child: Container(
              color: color,
              margin: EdgeInsets.only(
                left: i == 0 ? 0 : 2,
                right: i + 1 == cells.length ? 0 : 2,
              ),
              padding: const EdgeInsets.all(4),
              child: cells[i],
            ),
          ),
      ],
    ),
  );
}

class NativePaymentNumber extends StatelessWidget {
  const NativePaymentNumber(this.value, {super.key, required this.style});
  final String value;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(value, maxLines: 1, softWrap: false, style: style),
    ),
  );
}

class NativePaymentServices extends StatelessWidget {
  const NativePaymentServices({
    super.key,
    required this.lines,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });
  final List<PaymentServiceLine> lines;
  final VoidCallback? onAdd;
  final ValueChanged<PaymentServiceLine>? onEdit, onDelete;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    final style = adminAppointmentText(
      9.5,
      s,
      family: 'OpenSans',
      weight: FontWeight.w700,
      color: const Color(0xff6c6e6f),
    );
    Widget detail(String title, String value) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(title, style: style.copyWith(color: Colors.black)),
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
            color: DocColors.primary,
            weights: paymentServiceWeights,
            cells: [
              for (final label in [
                'Service & Unit',
                'Qty',
                'Rate',
                'Amount',
                '',
              ])
                NativePaymentNumber(
                  label,
                  style: adminAppointmentText(
                    11,
                    s,
                    family: 'PatuaOne',
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: InkWell(
                key: Key('payment_service_row_$i'),
                onTap: onEdit == null ? null : () => onEdit!(lines[i]),
                child: NativePaymentGrid(
                  weights: paymentServiceWeights,
                  cells: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        detail('Service:', lines[i].service.name),
                        const SizedBox(height: 4),
                        detail('Unit:', lines[i].unit.name),
                      ],
                    ),
                    NativePaymentNumber('${lines[i].quantity}', style: style),
                    NativePaymentNumber(
                      paymentMoney(lines[i].rate.cents),
                      style: style,
                    ),
                    NativePaymentNumber(
                      paymentMoney(lines[i].amount),
                      style: style,
                    ),
                    Center(
                      child: IconButton(
                        key: Key('payment_service_delete_$i'),
                        tooltip: 'Delete service',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 40,
                        ),
                        onPressed:
                            onDelete == null ? null : () => onDelete!(lines[i]),
                        icon: Icon(
                          Icons.cancel,
                          color: DocColors.primary,
                          size: 18 * s,
                        ),
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
                    flex: 75,
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
                    flex: 17,
                    child: Center(
                      child: Text(
                        paymentMoney(
                          lines.fold<int>(0, (n, l) => n + l.amount),
                        ),
                        key: const Key('payment_total'),
                        textAlign: TextAlign.center,
                        style: adminAppointmentText(
                          11,
                          s,
                          family: 'RussoOne',
                          color: const Color(0xff777777),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 8),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: NativePaymentPill(
                key: const Key('payment_add_service'),
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
