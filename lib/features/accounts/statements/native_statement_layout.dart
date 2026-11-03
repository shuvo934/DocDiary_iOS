import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../voucher_transaction/native_voucher_controls.dart';
import 'statement_models.dart';

const statementGreen = Color(0xff16a085);

class NativeStatementLevelField extends StatelessWidget {
  const NativeStatementLevelField({
    super.key,
    required this.menu,
    required this.level,
    required this.enabled,
    required this.onSelected,
    required this.onMenuChanged,
  });
  final MenuController menu;
  final StatementLevel level;
  final bool enabled;
  final ValueChanged<StatementLevel> onSelected;
  final VoidCallback onMenuChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final s = adminAppointmentScale(context);
      return MenuAnchor(
        controller: menu,
        consumeOutsideTap: true,
        onOpen: onMenuChanged,
        onClose: onMenuChanged,
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          minimumSize: WidgetStatePropertyAll(Size(c.maxWidth, 0)),
          maximumSize: WidgetStatePropertyAll(Size(c.maxWidth, 320)),
        ),
        menuChildren: [
          for (final value in StatementLevel.values)
            MenuItemButton(
              key: Key('statement_level_${value.index + 1}'),
              onPressed: enabled ? () => onSelected(value) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  value.label,
                  style: vtText(
                    11,
                    s,
                    family: 'Poppins',
                    weight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
        ],
        builder:
            (context, controller, child) => Material(
              color: Colors.white,
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: DocColors.primary),
              ),
              child: InkWell(
                key: const Key('statement_level'),
                onTap:
                    enabled
                        ? () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        }
                        : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 50),
                  child: InputDecorator(
                    isEmpty: false,
                    decoration: InputDecoration(
                      labelText: 'A/C Level',
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
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8 * s,
                      ),
                      suffixIcon: Icon(
                        controller.isOpen
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                        color: vtTextColor,
                      ),
                    ),
                    child: Text(
                      level.label,
                      style: vtText(
                        10.5,
                        s,
                        family: 'Roboto',
                        weight: FontWeight.w400,
                        color: Colors.black,
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

class NativeStatementTables extends StatelessWidget {
  const NativeStatementTables({
    super.key,
    required this.data,
    required this.level,
    required this.horizontal,
    required this.onAccount,
  });
  final StatementData data;
  final StatementLevel level;
  final ScrollController horizontal;
  final ValueChanged<StatementAccount>? onAccount;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    return SingleChildScrollView(
      key: const Key('statement_horizontal'),
      controller: horizontal,
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(5, 0, 5, 10 * s),
            child: Text(
              'INCOME',
              style: vtText(12, s, family: 'Poppins', color: statementGreen),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 4 * s),
            child: _StatementTable(
              section: data.income,
              level: level,
              kind: 'income',
              onAccount: onAccount,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(5, 14 * s, 5, 10 * s),
            child: Text(
              'EXPENSE',
              style: vtText(12, s, family: 'Poppins', color: statementGreen),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 4 * s),
            child: _StatementTable(
              section: data.expense,
              level: level,
              kind: 'expense',
              onAccount: onAccount,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatementTable extends StatelessWidget {
  const _StatementTable({
    required this.section,
    required this.level,
    required this.kind,
    required this.onAccount,
  });
  final StatementSection section;
  final StatementLevel level;
  final String kind;
  final ValueChanged<StatementAccount>? onAccount;
  static const widths = [264.0, 111.0, 111.0, 111.0, 111.0, 111.0];
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context), lines = section.lines(level);
    final head = vtText(10, s, family: 'Archivo', color: Colors.white);
    final body = vtText(9.5, s),
        label = vtText(9.5, s, family: 'Poppins', weight: FontWeight.w500);
    final detail = label.copyWith(
      color: statementGreen,
      fontWeight: FontWeight.w600,
    );
    final footer = vtText(11, s, family: 'Poppins', color: Colors.black);
    Widget cell(
      String value,
      double w,
      double? h,
      TextStyle style, {
      bool whiteLine = false,
      Alignment align = Alignment.center,
      Key? key,
      bool border = true,
    }) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        border:
            border
                ? Border(
                  right: BorderSide(
                    color: whiteLine ? Colors.white : Colors.black,
                  ),
                )
                : null,
      ),
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Text(
        value,
        key: key,
        style: style,
        textAlign:
            align == Alignment.bottomRight ? TextAlign.right : TextAlign.center,
      ),
    );
    final tierHeight = [
      for (final value in ['Before', 'During this Period', 'Debit', 'Credit'])
        voucherTextHeight(
          context,
          value,
          value == 'During this Period' ? 222 : 111,
          head,
          vertical: 5,
        ),
    ].reduce(math.max);
    final header = Container(
      color: DocColors.primary,
      child: Row(
        children: [
          cell(
            'Head of Account',
            widths[0],
            tierHeight * 2,
            head,
            whiteLine: true,
          ),
          for (final title in ['Before', 'During this Period'])
            Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white)),
                  ),
                  child: cell(title, 222, tierHeight, head, whiteLine: true),
                ),
                Row(
                  children: [
                    cell('Debit', 111, tierHeight, head, whiteLine: true),
                    cell('Credit', 111, tierHeight, head, whiteLine: true),
                  ],
                ),
              ],
            ),
          cell(
            'Balance',
            111,
            tierHeight * 2,
            head,
            whiteLine: true,
            border: false,
          ),
        ],
      ),
    );
    Widget row(int i) {
      final line = lines[i],
          a = line.first,
          previous = i == 0 ? null : lines[i - 1].first;
      final labels = <(String, double, bool)>[];
      final newControl =
          previous == null || previous.controlCode != a.controlCode;
      final newSub = newControl || previous.subControlCode != a.subControlCode;
      if (level == StatementLevel.control) {
        labels.add((a.level1, 14, false));
      } else {
        if (newControl) labels.add((a.level1, 14, false));
        if (level == StatementLevel.subControl || newSub) {
          labels.add((a.level2, 32, false));
        }
        if (level == StatementLevel.details) {
          labels.add(('${a.level3} >>', 50, true));
        }
      }
      final amountValues = [
        for (var c = 0; c < 5; c++)
          statementAmount(
            line.amounts.columns[c],
            absolute: c == 4,
            blankZero: true,
          ),
      ];
      final groupEnd =
          i == lines.length - 1 ||
          lines[i + 1].first.controlCode != a.controlCode;
      return Container(
        key: Key('statement_${kind}_row_$i'),
        decoration: BoxDecoration(
          color: vtDisabled,
          border:
              groupEnd
                  ? const Border(bottom: BorderSide(color: Colors.black))
                  : null,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: widths[0],
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.black)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var n = 0; n < labels.length; n++)
                      Padding(
                        padding: EdgeInsets.only(left: labels[n].$2, right: 6),
                        child: InkWell(
                          key:
                              labels[n].$3
                                  ? Key('statement_${kind}_account_$i')
                                  : null,
                          onTap:
                              labels[n].$3 &&
                                      a.id.isNotEmpty &&
                                      onAccount != null
                                  ? () => onAccount!(a)
                                  : null,
                          child: Text(
                            labels[n].$1,
                            style: labels[n].$3 ? detail : label,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              for (var c = 0; c < 5; c++)
                cell(
                  amountValues[c],
                  widths[c + 1],
                  null,
                  body,
                  align: Alignment.bottomRight,
                  key: Key('statement_${kind}_row_${i}_$c'),
                  border: c < 4,
                ),
            ],
          ),
        ),
      );
    }

    final totals = [
      for (var c = 0; c < 5; c++)
        '৳ ${statementAmount(section.totals.columns[c], absolute: c == 4)}',
    ];
    final footerHeight = [
      for (var c = 0; c < 5; c++)
        voucherTextHeight(
          context,
          totals[c],
          widths[c + 1],
          footer,
          minimum: 30,
          vertical: 10,
        ),
    ].reduce(math.max);
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: widths.reduce((a, b) => a + b),
        child: Column(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black)),
              ),
              child: header,
            ),
            for (var i = 0; i < lines.length; i++) row(i),
            Row(
              children: [
                cell(
                  'Total Amount',
                  widths[0],
                  footerHeight,
                  footer,
                  align: Alignment.centerLeft,
                ),
                for (var c = 0; c < 5; c++)
                  cell(
                    totals[c],
                    widths[c + 1],
                    footerHeight,
                    footer,
                    key: Key('statement_${kind}_total_$c'),
                    align: Alignment.centerRight,
                    border: c < 4,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NativeStatementProfit extends StatelessWidget {
  const NativeStatementProfit({super.key, required this.data});
  final StatementData data;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context),
        values = [data.profit.before, data.profit.during, data.profit.balance];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(5, 14 * s, 5, 10 * s),
          child: Text(
            'NET PROFIT/LOSS',
            style: vtText(
              12,
              s,
              family: 'Poppins',
              color: const Color(0xff00a8ff),
            ),
          ),
        ),
        Material(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: statementGreen),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10 * s),
            child: Column(
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8 * s),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            ['Before', 'During this Period', 'Balance'][i],
                            style: vtText(10, s, family: 'Poppins'),
                          ),
                        ),
                        Text(':', style: vtText(11, s, family: 'Poppins')),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 6,
                          child: Text(
                            '৳ ${statementAmount(values[i], absolute: true)}',
                            key: Key('statement_profit_$i'),
                            textAlign: TextAlign.right,
                            style: vtText(
                              11,
                              s,
                              family: 'Poppins',
                              color:
                                  values[i].units.isNegative
                                      ? const Color(0xffc23616)
                                      : statementGreen,
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
      ],
    );
  }
}
