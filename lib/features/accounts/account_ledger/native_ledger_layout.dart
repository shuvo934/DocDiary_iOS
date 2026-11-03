import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../voucher_transaction/native_voucher_controls.dart';
import 'ledger_models.dart';

class NativeLedgerPatientField extends StatelessWidget {
  const NativeLedgerPatientField({
    super.key,
    required this.patient,
    required this.onTap,
  });
  final LedgerPatient? patient;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context), value = patient?.name ?? '';
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: patient == null ? 'Select Patient' : 'Patient Name: $value',
      child: Material(
        color: Colors.white,
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: DocColors.primary),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: InputDecorator(
              isEmpty: value.isEmpty,
              decoration: InputDecoration(
                labelText: patient == null ? 'Select Patient' : 'Patient Name',
                labelStyle: vtText(
                  10,
                  s,
                  family: 'Poppins',
                  weight: FontWeight.w500,
                ),
                floatingLabelStyle: vtText(
                  11.5,
                  s,
                  family: 'Poppins',
                  weight: FontWeight.w500,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.black),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10 * s,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              child: Text(
                value,
                style: vtText(
                  11,
                  s,
                  family: 'Poppins',
                  weight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NativeLedgerAccountField extends StatelessWidget {
  const NativeLedgerAccountField({
    super.key,
    required this.text,
    required this.focus,
    required this.menu,
    required this.choices,
    required this.enabled,
    required this.onChanged,
    required this.onSelected,
    required this.onSubmitted,
    required this.onMenuChanged,
  });
  final TextEditingController text;
  final FocusNode focus;
  final MenuController menu;
  final List<LedgerAccount> choices;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<LedgerAccount> onSelected;
  final VoidCallback onSubmitted, onMenuChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final s = adminAppointmentScale(context);
      final query = text.text.toLowerCase();
      final exact = choices.any((a) => a.name == text.text);
      final filtered =
          choices
              .where(
                (a) =>
                    exact ||
                    query.isEmpty ||
                    a.name.toLowerCase().contains(query) ||
                    a.code.toLowerCase().contains(query),
              )
              .toList();
      return MenuAnchor(
        controller: menu,
        consumeOutsideTap: true,
        onOpen: onMenuChanged,
        onClose: onMenuChanged,
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
          maximumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 300)),
        ),
        menuChildren: [
          for (final a in filtered)
            MenuItemButton(
              key: Key('ledger_account_${a.id}'),
              onPressed: enabled ? () => onSelected(a) : null,
              child: SizedBox(
                width: math.max(1, constraints.maxWidth - 32),
                child: Text(
                  a.name,
                  style: vtText(
                    10,
                    s,
                    family: 'Poppins',
                    weight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          if (filtered.isEmpty)
            MenuItemButton(
              onPressed: null,
              child: Text('No Account List Found', style: vtText(10, s)),
            ),
        ],
        builder:
            (context, controller, child) => Material(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: DocColors.primary),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: TextField(
                  key: const Key('ledger_account'),
                  controller: text,
                  focusNode: focus,
                  enabled: enabled,
                  textInputAction: TextInputAction.done,
                  onTap: enabled ? controller.open : null,
                  onChanged: (v) {
                    onChanged(v);
                    if (!controller.isOpen) controller.open();
                  },
                  onSubmitted: (_) {
                    controller.close();
                    onSubmitted();
                  },
                  style: vtText(
                    10,
                    s,
                    family: 'Poppins',
                    weight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: 'A/C No',
                    labelStyle: vtText(
                      10,
                      s,
                      family: 'Poppins',
                      weight: FontWeight.w400,
                    ),
                    floatingLabelStyle: vtText(
                      11,
                      s,
                      family: 'Poppins',
                      weight: FontWeight.w400,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12 * s,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    suffixIcon: IconButton(
                      key: const Key('ledger_account_dropdown'),
                      tooltip: 'Select A/C No',
                      onPressed:
                          enabled
                              ? () {
                                if (controller.isOpen) {
                                  controller.close();
                                } else {
                                  FocusScope.of(context).unfocus();
                                  controller.open();
                                }
                              }
                              : null,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: vtTextColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
      );
    },
  );
}

class NativeLedgerHeading extends StatelessWidget {
  const NativeLedgerHeading({super.key, this.account, this.patient});
  final LedgerAccount? account;
  final LedgerPatient? patient;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context), a = account, p = patient;
    final green = vtText(
      12,
      s,
      family: 'Poppins',
      color: const Color(0xff16a085),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 6 * s, 10, 10 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            a?.name ?? p!.name,
            key: const Key('ledger_heading'),
            style: green,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            '(${a?.code ?? p!.prescriptionCode})',
            key: const Key('ledger_code'),
            style: vtText(
              10,
              s,
              family: 'Poppins',
              color: const Color(0xff16a085),
            ),
            textAlign: TextAlign.center,
          ),
          if (a != null) ...[
            const SizedBox(height: 5),
            Text(
              a.category,
              style: vtText(10, s, family: 'Poppins'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              a.group,
              style: vtText(10, s, family: 'Poppins'),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class NativeLedgerTable extends StatelessWidget {
  const NativeLedgerTable({
    super.key,
    required this.data,
    required this.horizontal,
    required this.onVoucher,
  });
  final LedgerData data;
  final ScrollController horizontal;
  final ValueChanged<LedgerEntry>? onVoucher;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    // Native 60/100/200/100/100/100 dp plus its side margins/dividers.
    final widths = [74.0, 111.0, 211.0, 111.0, 111.0, 111.0];
    final body = vtText(9.5, s),
        black = vtText(9.5, s, family: 'Archivo', color: Colors.black);
    Widget line(
      List<String> values, {
      required String key,
      Color color = vtDisabled,
      TextStyle? style,
      bool header = false,
      bool link = false,
      VoidCallback? onTap,
    }) {
      final styles = [
        for (var i = 0; i < values.length; i++)
          !header && i == 1 && link
              ? body.copyWith(color: const Color(0xff16a085))
              : style ?? body,
      ];
      final h = [
        for (var i = 0; i < values.length; i++)
          voucherTextHeight(
            context,
            values[i],
            widths[i],
            styles[i],
            vertical: header ? 5 : 8,
            minimum: header ? 24 : 24,
          ),
      ].reduce(math.max);
      return Container(
        key: Key(key),
        decoration: BoxDecoration(
          color: color,
          border: const Border(bottom: BorderSide(color: Colors.black)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < values.length; i++)
              voucherCell(
                width: widths[i],
                height: h,
                text: values[i],
                style: styles[i],
                line: header ? Colors.white : Colors.black,
                border: i < values.length - 1,
                onTap: i == 1 ? onTap : null,
                key: Key('${key}_$i'),
              ),
          ],
        ),
      );
    }

    Widget merged({required bool opening}) {
      final amounts =
          opening
              ? [
                ledgerAmount(data.openingDebit),
                ledgerAmount(data.openingCredit),
                '',
              ]
              : [
                ledgerAmount(data.debit),
                ledgerAmount(data.credit),
                ledgerAmount(data.closingBalance),
              ];
      final style =
          opening
              ? black
              : vtText(
                10.5,
                s,
                family: 'Poppins',
                weight: FontWeight.w600,
                color: Colors.black,
              );
      final h = [
        for (var i = 0; i < 3; i++)
          voucherTextHeight(context, amounts[i], widths[i + 3], style),
      ].reduce(math.max);
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.black)),
        ),
        child: Row(
          children: [
            if (opening) ...[
              voucherCell(
                width: widths[0],
                height: h,
                text: data.dates.first,
                style: body,
              ),
              Container(
                width: widths[1] + widths[2],
                height: h,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.black)),
                ),
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(left: widths[1] * .28),
                child: Text('Opening', style: black),
              ),
            ] else
              Container(
                width: widths.take(3).reduce((a, b) => a + b),
                height: h,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.black)),
                ),
                padding: const EdgeInsets.only(left: 24),
                alignment: Alignment.centerLeft,
                child: Text('Turn Over This Period', style: style),
              ),
            for (var i = 0; i < 3; i++)
              voucherCell(
                width: widths[i + 3],
                height: h,
                text: amounts[i],
                style: style,
                border: i < 2,
                key: Key(opening ? 'ledger_opening_$i' : 'ledger_total_$i'),
              ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        key: const Key('ledger_horizontal'),
        controller: horizontal,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: widths.reduce((a, b) => a + b),
          child: Column(
            children: [
              line(
                [
                  'Date',
                  'Voucher No',
                  'Particulars',
                  'Debit',
                  'Credit',
                  'Balance',
                ],
                key: 'ledger_header',
                header: true,
                color: DocColors.primary,
                style: vtText(
                  10,
                  s,
                  family: 'Archivo',
                  color: Colors.white,
                  weight: FontWeight.bold,
                ),
              ),
              merged(opening: true),
              for (var i = 0; i < data.entries.length; i++)
                line(
                  [
                    data.entries[i].row.date,
                    data.entries[i].row.number,
                    data.entries[i].row.particulars,
                    ledgerAmount(data.entries[i].row.debit, parentheses: false),
                    ledgerAmount(
                      data.entries[i].row.credit,
                      parentheses: false,
                    ),
                    ledgerAmount(data.entries[i].balance),
                  ],
                  key: 'ledger_row_$i',
                  link: data.entries[i].row.actionable,
                  onTap:
                      data.entries[i].row.actionable && onVoucher != null
                          ? () => onVoucher!(data.entries[i])
                          : null,
                ),
              merged(opening: false),
            ],
          ),
        ),
      ),
    );
  }
}
