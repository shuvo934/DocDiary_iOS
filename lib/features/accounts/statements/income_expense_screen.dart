import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../auth/auth_controller.dart';
import '../../dashboard/native_dashboard_dialogs.dart';
import '../accounts_dashboard_repository.dart';
import '../account_ledger/account_ledger_screen.dart';
import '../account_ledger/ledger_repository.dart';
import '../native_accounts_donut.dart';
import '../voucher_transaction/native_voucher_controls.dart';
import '../voucher_transaction/voucher_models.dart';
import '../voucher_transaction/voucher_read_owner.dart';
import 'statement_models.dart';
import 'statement_repository.dart';
import 'native_statement_layout.dart';

class IncomeExpenseScreen extends StatefulWidget {
  const IncomeExpenseScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.firstDate = '',
    this.lastDate = '',
  });
  final AuthController auth;
  final StatementRepository repository;
  final String firstDate, lastDate;
  @override
  State<IncomeExpenseScreen> createState() => _StatementState();
}

class _StatementState extends State<IncomeExpenseScreen> {
  late final VoucherReadOwner _owner;
  late String _first, _last;
  StatementData? _data;
  StatementLevel _level = StatementLevel.details;
  bool _busy = true,
      _authorized = false,
      _navigating = false,
      _childAway = false,
      _reloadOnReturn = false,
      _invalidRange = false,
      _disposing = false;
  String? _error;
  final _dialogs = NativeDashboardDialogOwner();
  final _scroll = ScrollController(), _horizontal = ScrollController();
  final _menu = MenuController();
  bool get _ready =>
      _owner.current &&
      _owner.foreground &&
      _authorized &&
      !_busy &&
      !_navigating &&
      !_dialogs.isOpen;
  @override
  void initState() {
    super.initState();
    _first =
        widget.firstDate.isEmpty
            ? VoucherDates.initial('', '', widget.repository.now()).first
            : widget.firstDate;
    _last =
        widget.lastDate.isEmpty
            ? VoucherDates.initial('', '', widget.repository.now()).last
            : widget.lastDate;
    _owner = VoucherReadOwner(
      widget.auth,
      widget.repository,
      onResume: () {
        if (!_childAway) unawaited(_load());
      },
    )..addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_owner.current && _owner.foreground) {
        unawaited(_load());
      } else if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Accounts access is not available for this account.';
        });
      }
    });
  }

  void _changed() {
    _menu.close();
    if (!_owner.current) {
      _dialogs.close();
      _data = null;
      _authorized = false;
    }
    if (!_owner.foreground) {
      if (_childAway) {
        _reloadOnReturn = true;
      } else {
        _dialogs.close();
        _data = null;
        _busy = true;
      }
    }
    if (mounted) setState(() {});
  }

  void _menuChanged() {
    if (mounted && !_disposing) setState(() {});
  }

  bool _accessFailure(Object error) {
    if (_owner.blockDenied(error)) return true;
    if (error is! AccountsModuleUnavailable) return false;
    _dialogs.close();
    setState(() {
      _busy = false;
      _navigating = false;
      _authorized = false;
      _data = null;
      _error = 'Accounts access is not available for this account.';
    });
    return true;
  }

  Future<void> _load() async {
    if (!_owner.current ||
        !_owner.foreground ||
        _dialogs.isOpen ||
        _childAway) {
      return;
    }
    final op = _owner.begin();
    setState(() {
      _busy = true;
      _data = null;
      _error = null;
    });
    try {
      final profile = await _owner.fresh(op);
      StatementData? data;
      if (_first.isNotEmpty && _last.isNotEmpty) {
        data = await widget.repository.statement(
          _owner.session!,
          profile,
          VoucherDates(_first, _last),
          isCurrent: () => _owner.alive(op),
        );
      }
      if (!mounted || !_owner.alive(op)) return;
      setState(() {
        _data = data;
        _busy = false;
        _navigating = false;
        _authorized = true;
      });
    } catch (error) {
      if (!mounted ||
          !_owner.alive(op) ||
          error is ObsoleteRequest ||
          _accessFailure(error)) {
        return;
      }
      await _failed(error, op);
    }
  }

  Future<void> _failed(Object error, int op) async {
    setState(() {
      _busy = false;
      _navigating = false;
      _data = null;
      _error = dashboardErrorMessage(
        error is AppFailure
            ? error
            : const AppFailure('The statement could not be loaded.'),
      );
    });
    var answered = false;
    void answer(bool value) {
      if (!answered && _owner.alive(op) && _dialogs.isOpen) {
        answered = true;
        Navigator.pop(context, value);
      }
    }

    final retry = await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: const Key('statement_error'),
        title: Text('Error!', style: dashboardDialogText(20)),
        content: Text(_error!),
        actions: [
          TextButton(
            key: const Key('statement_error_exit'),
            onPressed: () => answer(false),
            child: const Text('Exit'),
          ),
          TextButton(
            key: const Key('statement_error_retry'),
            onPressed: () => answer(true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    if (!mounted || !_owner.alive(op)) return;
    if (retry == true) {
      await _load();
    } else {
      await _back();
    }
  }

  Future<void> _pickDate(bool begin) async {
    if (!_ready) return;
    _menu.close();
    final op = _owner.begin(),
        now = dateOnly(widget.repository.now()),
        earliest = VoucherDates.earliest(widget.repository.now());
    DateTime initial;
    try {
      initial = parseOracleDate(begin ? _first : _last);
    } catch (_) {
      initial = now;
    }
    if (initial.isBefore(earliest)) initial = earliest;
    if (initial.isAfter(DateTime(2100, 12, 31))) {
      initial = DateTime(2100, 12, 31);
    }
    final chosen = await _dialogs.show<DateTime>(
      context,
      DatePickerDialog(
        key: const Key('statement_date_picker'),
        initialDate: initial,
        firstDate: earliest,
        lastDate: DateTime(2100, 12, 31),
      ),
    );
    if (!mounted || !_owner.alive(op)) return;
    setState(() {});
    if (chosen == null) return;
    setState(() {
      if (begin) {
        _first = oracleDate(chosen);
      } else {
        _last = oracleDate(chosen);
      }
      _invalidRange = false;
      _data = null;
    });
    if (_first.isEmpty || _last.isEmpty) return;
    if (parseOracleDate(_first).isAfter(parseOracleDate(_last))) {
      setState(() {
        _invalidRange = true;
        if (begin) {
          _first = '';
        } else {
          _last = '';
        }
      });
      return;
    }
    await _load();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_horizontal.hasClients) _horizontal.jumpTo(0);
  }

  void _changeLevel(StatementLevel level) {
    if (!_ready || _data == null) return;
    _menu.close();
    setState(() => _level = level);
  }

  Future<void> _openAccount(StatementAccount account) async {
    if (!_ready ||
        _data == null ||
        account.id.isEmpty ||
        !(_data!.income.rows.contains(account) ||
            _data!.expense.rows.contains(account))) {
      return;
    }
    final op = _owner.begin(), dates = _data!.dates;
    setState(() => _navigating = true);
    try {
      await _owner.fresh(op);
      if (!mounted || !_owner.alive(op)) return;
      setState(() => _navigating = false);
      _childAway = true;
      try {
        await _dialogs.push<void>(
          context,
          AccountLedgerScreen(
            auth: widget.auth,
            repository: LedgerRepository(
              widget.repository.transport,
              now: widget.repository.now,
            ),
            firstDate: dates.first,
            lastDate: dates.last,
            accountId: account.id,
          ),
        );
      } finally {
        _childAway = false;
        if (_owner.current && _owner.foreground) {
          if (_reloadOnReturn) {
            _reloadOnReturn = false;
            await _load();
          } else {
            final check = _owner.begin();
            setState(() => _navigating = true);
            try {
              await _owner.fresh(check);
              if (_owner.alive(check)) setState(() => _navigating = false);
            } catch (error) {
              if (mounted &&
                  _owner.alive(check) &&
                  error is! ObsoleteRequest &&
                  !_accessFailure(error)) {
                await _failed(error, check);
              }
            }
          }
        }
      }
    } catch (error) {
      if (mounted &&
          _owner.alive(op) &&
          error is! ObsoleteRequest &&
          !_accessFailure(error)) {
        await _failed(error, op);
      }
    }
  }

  Future<void> _back() async {
    if (!mounted || _busy || _navigating || _dialogs.isOpen) return;
    if (_menu.isOpen) {
      _menu.close();
      return;
    }
    await Navigator.maybePop(context);
  }

  @override
  void dispose() {
    _disposing = true;
    _menu.close();
    _owner.removeListener(_changed);
    _owner.dispose();
    _dialogs.dispose();
    _scroll.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context), data = _data;
    return PopScope(
      canPop: !_busy && !_navigating && !_menu.isOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _menu.isOpen) _menu.close();
      },
      child: NativeVoucherShell(
        title: 'Income/Expense Statement',
        backKey: 'statement_back',
        onBack: _busy || _navigating ? null : () => unawaited(_back()),
        child:
            _busy || !_owner.foreground
                ? const Center(
                  child: CircularProgressIndicator(
                    key: Key('statement_loading'),
                  ),
                )
                : !_authorized
                ? Center(
                  child: Text(
                    _error ?? 'Accounts access is not available.',
                    textAlign: TextAlign.center,
                  ),
                )
                : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: VoucherDateField(
                                  key: const Key('statement_begin'),
                                  label: 'Begin Date',
                                  value: _first,
                                  onTap:
                                      _ready
                                          ? () => unawaited(_pickDate(true))
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: VoucherDateField(
                                  key: const Key('statement_end'),
                                  label: 'End Date',
                                  value: _last,
                                  onTap:
                                      _ready
                                          ? () => unawaited(_pickDate(false))
                                          : null,
                                ),
                              ),
                            ],
                          ),
                          if (_invalidRange)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Date Range is Invalid',
                                key: const Key('statement_range_error'),
                                style: vtText(11, s, color: Colors.red),
                              ),
                            ),
                          const SizedBox(height: 12),
                          NativeStatementLevelField(
                            menu: _menu,
                            level: _level,
                            enabled: _ready && data != null,
                            onSelected: _changeLevel,
                            onMenuChanged: _menuChanged,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: SingleChildScrollView(
                        key: const Key('statement_scroll'),
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                        child:
                            data == null
                                ? const SizedBox()
                                : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Material(
                                      color: Colors.white,
                                      elevation: 2,
                                      borderRadius: BorderRadius.circular(10),
                                      clipBehavior: Clip.antiAlias,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              10,
                                              8,
                                              10,
                                              4,
                                            ),
                                            child: Text(
                                              data.amountLabel,
                                              key: const Key(
                                                'statement_amount',
                                              ),
                                              style: vtText(
                                                11.5,
                                                s,
                                                family: 'Poppins',
                                                color:
                                                    data
                                                            .chartNet
                                                            .units
                                                            .isNegative
                                                        ? const Color(
                                                          0xffc23616,
                                                        )
                                                        : statementGreen,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              30,
                                              6,
                                              12,
                                              16,
                                            ),
                                            child: NativeAccountsDonut(
                                              title: 'Income/Expense',
                                              centerText: '',
                                              scale: s,
                                              pieWidthFraction: .60,
                                              whiteValues: true,
                                              allowRotation: _ready,
                                              valueLabel:
                                                  (n) =>
                                                      (n.number.units ~/
                                                              BigInt.from(
                                                                10,
                                                              ).pow(
                                                                n.number.scale,
                                                              ))
                                                          .toString(),
                                              slices: [
                                                if (!data.chartIncome.isZero)
                                                  AccountsPieSlice(
                                                    'Income',
                                                    data.chartIncome,
                                                    const Color(0xff1dd1a1),
                                                  ),
                                                if (!data.chartExpense.isZero)
                                                  AccountsPieSlice(
                                                    'Expense',
                                                    data.chartExpense,
                                                    const Color(0xffff6b6b),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    NativeStatementTables(
                                      data: data,
                                      level: _level,
                                      horizontal: _horizontal,
                                      onAccount:
                                          _ready
                                              ? (a) =>
                                                  unawaited(_openAccount(a))
                                              : null,
                                    ),
                                    NativeStatementProfit(data: data),
                                  ],
                                ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
