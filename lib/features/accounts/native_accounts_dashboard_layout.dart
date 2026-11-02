import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../appointments/admin_modify/native_admin_appointment_controls.dart';
import '../profile/native_profile_icons.dart';
import 'accounts_dashboard_models.dart';
import 'accounts_dashboard_navigation.dart';
import 'native_accounts_donut.dart';

class NativeAccountsDashboardLayout extends StatelessWidget {
  const NativeAccountsDashboardLayout({
    super.key,
    required this.scaffoldKey,
    required this.scrollController,
    required this.onBack,
    required this.onDestination,
    required this.onVoucher,
    required this.onIncomeExpense,
    required this.onPeriod,
    required this.onRetry,
    required this.period,
    required this.range,
    required this.data,
    required this.waiting,
    required this.enabled,
    required this.centerApi,
    this.message,
  });
  final GlobalKey<ScaffoldState> scaffoldKey;
  final ScrollController scrollController;
  final VoidCallback onBack, onVoucher, onIncomeExpense, onRetry;
  final ValueChanged<AccountsDestination> onDestination;
  final ValueChanged<AccountsPeriod> onPeriod;
  final AccountsPeriod period;
  final AccountsRange range;
  final AccountsDashboardData? data;
  final bool waiting, enabled;
  final Uri? centerApi;
  final String? message;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context), size = MediaQuery.sizeOf(context);
    final interactive = enabled && !waiting && message == null;
    final zoom = MediaQuery.textScalerOf(context).scale(12) / 12;
    final destinations =
        centerApi == null
            ? const <AccountsDestination>[]
            : accountsDestinations(centerApi!);
    Widget title(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
      child: Text(
        text,
        style: adminAppointmentText(
          12,
          s,
          color: DocColors.primary,
          weight: FontWeight.w700,
        ),
      ),
    );
    Widget total(
      String label,
      String value,
      String key, {
      Color color = Colors.black,
    }) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: adminAppointmentText(9.5, s, weight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              key: Key(key),
              style: adminAppointmentText(
                10,
                s,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
    Widget card(String heading, Widget chart, List<Widget> totals) => Padding(
      padding: EdgeInsets.fromLTRB(3, 10 * s, 3, 5),
      child: Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 285 * s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              title(heading),
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 20, 5, 20),
                child: chart,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 50 * s),
                child: const Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 3),
              ...totals,
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
    Widget content() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 10 * s, bottom: 8 * s),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final tab in AccountsPeriod.values)
                Expanded(
                  child: Semantics(
                    selected: tab == period,
                    button: true,
                    child: InkWell(
                      key: Key('accounts_period_${tab.name}'),
                      borderRadius: BorderRadius.circular(30),
                      onTap: interactive ? () => onPeriod(tab) : null,
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 10,
                        ),
                        constraints: const BoxConstraints(minHeight: 46),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient:
                              tab == period
                                  ? const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      DocColors.primary,
                                      DocColors.greenSea,
                                    ],
                                  )
                                  : null,
                        ),
                        child: Text(
                          tab.label,
                          textAlign: TextAlign.center,
                          style: adminAppointmentText(
                            9.5,
                            s,
                            family: 'PatuaOne',
                            weight: FontWeight.w700,
                            color:
                                tab == period
                                    ? Colors.white
                                    : const Color(0xff666666),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(6 * s, 2 * s, 6 * s, 0),
          child: Text(
            range.label,
            key: const Key('accounts_date_range'),
            style: adminAppointmentText(
              12,
              s,
              family: 'Archivo',
              weight: FontWeight.w700,
              color: const Color(0xff6c6e6f),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('accounts_scroll'),
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                card(
                  'Voucher',
                  NativeAccountsDonut(
                    key: const Key('accounts_voucher_chart'),
                    title: 'Voucher',
                    slices: [
                      for (final row in data!.vouchers)
                        AccountsPieSlice(
                          row.label,
                          row.count,
                          accountsVoucherColors[row.colorIndex %
                              accountsVoucherColors.length],
                        ),
                    ],
                    onTap: interactive ? onVoucher : null,
                    scale: s,
                  ),
                  [
                    total(
                      'Total Voucher :',
                      data!.voucherCount.toString(),
                      'accounts_total_voucher',
                    ),
                    total(
                      'Amount :',
                      data!.amountLabel,
                      'accounts_amount',
                      color:
                          data!.amount.negative
                              ? const Color(0xffc23616)
                              : DocColors.greenSea,
                    ),
                  ],
                ),
                card(
                  'Income/Expense',
                  NativeAccountsDonut(
                    key: const Key('accounts_income_chart'),
                    title: 'Income/Expense',
                    slices: [
                      if (!data!.income.isZero)
                        AccountsPieSlice(
                          'Income',
                          data!.income,
                          const Color(0xff1dd1a1),
                        ),
                      if (!data!.expense.isZero)
                        AccountsPieSlice(
                          'Expense',
                          data!.expense,
                          const Color(0xffff6b6b),
                        ),
                    ],
                    onTap: interactive ? onIncomeExpense : null,
                    scale: s,
                    whiteValues: true,
                  ),
                  [
                    total(
                      'Total Income :',
                      data!.income.text,
                      'accounts_total_income',
                      color: DocColors.greenSea,
                    ),
                    total(
                      'Total Expense :',
                      data!.expense.text,
                      'accounts_total_expense',
                      color: const Color(0xffc23616),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: DocColors.primary,
        endDrawerEnableOpenDragGesture: interactive,
        endDrawer: Drawer(
          width: math.min(
            360,
            math.max(math.min(240, size.width - 40), size.width * .68),
          ),
          backgroundColor: DocColors.primary,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(12 * s),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/accounting_icon.png',
                        width: 20 * s,
                        height: 20 * s,
                        color: Colors.white,
                      ),
                      SizedBox(width: 12 * s),
                      Expanded(
                        child: Text(
                          'Accounts Menu',
                          style: adminAppointmentText(
                            14,
                            s,
                            color: Colors.white,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('accounts_drawer_close'),
                        tooltip: 'Close menu',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        color: Colors.white,
                        onPressed:
                            () => scaffoldKey.currentState?.closeEndDrawer(),
                        icon: const Icon(Icons.keyboard_double_arrow_right),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    color: Colors.white,
                    child: ListView(
                      key: const Key('accounts_menu_list'),
                      padding: EdgeInsets.only(top: 10 * s),
                      children: [
                        for (final item in destinations)
                          ListTile(
                            key: Key('accounts_menu_${item.name}'),
                            enabled: interactive,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16 * s,
                            ),
                            minLeadingWidth: 24,
                            horizontalTitleGap: 12,
                            minTileHeight: 46,
                            minVerticalPadding: 0,
                            leading: Image.asset(
                              'assets/images/${item.artwork}',
                              width: 24,
                              height: 24,
                              color: DocColors.greenSea,
                            ),
                            title: Text(
                              item.label,
                              style: adminAppointmentText(
                                10,
                                s,
                                weight: FontWeight.w600,
                                color: const Color(0xff6c6e6f),
                              ),
                            ),
                            onTap:
                                interactive
                                    ? () {
                                      scaffoldKey.currentState
                                          ?.closeEndDrawer();
                                      onDestination(item);
                                    }
                                    : null,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 19 * s,
                      child: IconButton(
                        key: const Key('accounts_back'),
                        tooltip: 'Back',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minHeight: 44),
                        onPressed: waiting ? null : onBack,
                        icon: NativeProfileIcon(
                          NativeProfileGlyph.back,
                          size: 19 * s,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Accounts Dashboard',
                        key: const Key('accounts_title'),
                        style: adminAppointmentText(
                          14,
                          s,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 19 * s,
                      child: IconButton(
                        key: const Key('accounts_menu'),
                        tooltip: 'Accounts Menu',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minHeight: 44),
                        onPressed:
                            interactive
                                ? () =>
                                    scaffoldKey.currentState?.openEndDrawer()
                                : null,
                        icon: Icon(
                          Icons.menu,
                          size: 19 * s,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      child:
                          waiting
                              ? const Center(
                                child: CircularProgressIndicator(
                                  key: Key('accounts_loading'),
                                ),
                              )
                              : message != null
                              ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    message!,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                              : data == null
                              ? Center(
                                child: TextButton(
                                  key: const Key('accounts_retry'),
                                  onPressed: onRetry,
                                  child: const Text('Retry'),
                                ),
                              )
                              : zoom > 1.7 && size.height < 400
                              ? SingleChildScrollView(
                                child: SizedBox(
                                  height: math.max(650, size.height * 2),
                                  child: content(),
                                ),
                              )
                              : content(),
                    ),
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
