import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../auth/auth_controller.dart';
import '../../dashboard/native_dashboard_dialogs.dart';
import '../accounts_dashboard_repository.dart';
import '../accounts_loading_boundary.dart';
import '../voucher_transaction/native_voucher_controls.dart';
import '../voucher_transaction/payment_invoice_screen.dart';
import '../voucher_transaction/voucher_models.dart';
import '../voucher_transaction/voucher_read_owner.dart';
import '../voucher_transaction/voucher_report_dialog.dart';
import 'ledger_models.dart';
import 'ledger_repository.dart';
import 'native_ledger_layout.dart';
import 'native_ledger_patient_picker.dart';

class AccountLedgerScreen extends StatefulWidget {
  const AccountLedgerScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.patientLedger = false,
    this.firstDate = '',
    this.lastDate = '',
    this.accountId = '',
  });
  final AuthController auth;
  final LedgerRepository repository;
  final bool patientLedger;
  final String firstDate, lastDate, accountId;
  @override
  State<AccountLedgerScreen> createState() => _LedgerState();
}

class _LedgerState extends State<AccountLedgerScreen> {
  late final VoucherReadOwner _owner;
  late String _first, _last;
  List<LedgerAccount> _accounts = const [];
  LedgerAccount? _account;
  LedgerPatient? _patient;
  LedgerData? _data;
  String? _error, _accountError;
  bool _busy = true,
      _loaded = false,
      _navigating = false,
      _childAway = false,
      _reloadOnReturn = false,
      _rangeInvalid = false,
      _settingAccount = false,
      _disposing = false;
  final _dialogs = NativeDashboardDialogOwner();
  final _scroll = ScrollController(), _horizontal = ScrollController();
  final _accountText = TextEditingController();
  final _accountFocus = FocusNode();
  final _menu = MenuController();
  bool get _ready =>
      _owner.current &&
      _owner.foreground &&
      _loaded &&
      !_busy &&
      !_navigating &&
      !_dialogs.isOpen;
  bool get _hasSelection =>
      widget.patientLedger ? _patient != null : _account != null;

  @override
  void initState() {
    super.initState();
    try {
      final dates = initialLedgerDates(
        widget.firstDate,
        widget.lastDate,
        widget.repository.now(),
      );
      _first = dates.first;
      _last = dates.last;
    } catch (_) {
      _first = widget.firstDate;
      _last = widget.lastDate;
    }
    _accountFocus.addListener(_accountBlur);
    _owner = VoucherReadOwner(
      widget.auth,
      widget.repository,
      onResume: () {
        if (!_childAway) unawaited(_load(refreshAccounts: true));
      },
    )..addListener(_ownerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_owner.current && _owner.foreground) {
        unawaited(_load(refreshAccounts: true));
      } else if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Accounts access is not available for this account.';
        });
      }
    });
  }

  void _menuChanged() {
    if (mounted && !_disposing) setState(() {});
  }

  void _accountBlur() {
    if (!_accountFocus.hasFocus &&
        !_settingAccount &&
        !_menu.isOpen &&
        _ready) {
      unawaited(_submitAccount());
    }
  }

  void _ownerChanged() {
    _menu.close();
    _settingAccount = true;
    _accountFocus.unfocus();
    _settingAccount = false;
    if (!_owner.current) {
      _dialogs.close();
      _data = null;
      _accounts = const [];
      _account = null;
      _patient = null;
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

  bool _accessFailure(Object failure) {
    if (_owner.blockDenied(failure)) return true;
    if (failure is! AccountsModuleUnavailable) return false;
    _dialogs.close();
    setState(() {
      _data = null;
      _accounts = const [];
      _loaded = false;
      _busy = false;
      _navigating = false;
      _error = 'Accounts access is not available for this account.';
    });
    return true;
  }

  Future<void> _load({bool refreshAccounts = false}) async {
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
      if (refreshAccounts && !widget.patientLedger) {
        final accounts = await widget.repository.accounts(
          _owner.session!,
          profile,
          isCurrent: () => _owner.alive(op),
        );
        if (!_owner.alive(op)) return;
        final id = _account?.id ?? (!_loaded ? widget.accountId : '');
        _accounts = accounts;
        final matches = accounts.where((a) => a.id == id);
        _account = matches.isEmpty ? null : matches.first;
        _settingAccount = true;
        _accountText.text = _account?.name ?? '';
        _settingAccount = false;
        _accountError =
            accounts.isEmpty
                ? 'No Account List Found'
                : id.isNotEmpty && _account == null
                ? 'Invalid A/C No'
                : null;
      }
      LedgerData? data;
      if (_hasSelection && _first.isNotEmpty && _last.isNotEmpty) {
        data = await widget.repository.ledger(
          _owner.session!,
          profile,
          VoucherDates(_first, _last),
          account: _account,
          patient: _patient,
          isCurrent: () => _owner.alive(op),
        );
      }
      if (!mounted || !_owner.alive(op)) return;
      setState(() {
        _data = data;
        _busy = false;
        _navigating = false;
        _loaded = true;
      });
    } catch (failure) {
      if (!mounted ||
          !_owner.alive(op) ||
          failure is ObsoleteRequest ||
          _accessFailure(failure)) {
        return;
      }
      await _failed(failure, op, refreshAccounts: refreshAccounts);
    }
  }

  String _message(Object error) => dashboardErrorMessage(
    error is AppFailure
        ? error
        : const AppFailure(
          'Server problem or Internet not connected',
          kind: FailureKind.network,
        ),
  );
  Future<void> _failed(
    Object error,
    int op, {
    bool refreshAccounts = false,
  }) async {
    setState(() {
      _busy = false;
      _navigating = false;
      _data = null;
      _error = _message(error);
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
        key: const Key('ledger_error'),
        title: Text('Error!', style: dashboardDialogText(20)),
        content: SingleChildScrollView(
          child: Text(_error!, style: dashboardDialogText(16)),
        ),
        actions: [
          TextButton(
            key: const Key('ledger_error_exit'),
            onPressed: () => answer(false),
            child: const Text('Exit'),
          ),
          TextButton(
            key: const Key('ledger_error_retry'),
            onPressed: () => answer(true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    if (!mounted || !_owner.alive(op)) return;
    if (retry == true) {
      await _load(refreshAccounts: refreshAccounts);
    } else {
      await _back();
    }
  }

  Future<void> _chooseAccount(LedgerAccount account) async {
    if (!_ready || !_accounts.contains(account)) return;
    _settingAccount = true;
    _menu.close();
    _accountFocus.unfocus();
    _accountText.value = TextEditingValue(
      text: account.name,
      selection: TextSelection.collapsed(offset: account.name.length),
    );
    _settingAccount = false;
    setState(() {
      _account = account;
      _accountError = null;
      _data = null;
    });
    await _load();
    _resetScroll();
  }

  Future<void> _submitAccount() async {
    if (!_ready || _settingAccount) return;
    final text = _accountText.text;
    final found = _accounts.where((a) => a.name == text);
    if (found.isNotEmpty) {
      if (_account?.id != found.first.id || _data == null) {
        await _chooseAccount(found.first);
      }
    } else {
      setState(() {
        _account = null;
        _data = null;
        _accountError =
            text.isEmpty ? 'Please Select A/C No' : 'Invalid A/C No';
      });
    }
  }

  Future<void> _pickPatient() async {
    if (!_ready) return;
    final op = _owner.begin(),
        state = ValueNotifier(const LedgerPatientPickerData(busy: true));
    var opened = true, query = '';
    List<LedgerPatient> seed = const [];
    bool current() => opened && _owner.alive(op);
    Future<void> fetch(String? search) async {
      if (!current()) return;
      query = search ?? '';
      state.value = LedgerPatientPickerData(
        busy: true,
        searched: search != null,
      );
      try {
        final profile = await _owner.fresh(op);
        final rows = await widget.repository.patients(
          _owner.session!,
          profile,
          query: search,
          isCurrent: current,
        );
        if (!current()) return;
        if (search == null) seed = rows;
        state.value = LedgerPatientPickerData(
          rows: rows,
          searched: search != null,
        );
      } catch (failure) {
        if (!current() ||
            failure is ObsoleteRequest ||
            _accessFailure(failure)) {
          return;
        }
        state.value = LedgerPatientPickerData(
          searched: search != null,
          error: _message(failure),
        );
      }
    }

    unawaited(fetch(null));
    final selected = await _dialogs.show<LedgerPatient>(
      context,
      ValueListenableBuilder<LedgerPatientPickerData>(
        valueListenable: state,
        builder:
            (context, data, child) =>
                AccountsLoadingBoundary(busy: data.busy, child: child!),
        child: NativeLedgerPatientPicker(
          state: state,
          onSearch: (q) {
            if (current() && !state.value.busy) unawaited(fetch(q));
          },
          onClear: () {
            if (current() && !state.value.busy) {
              query = '';
              state.value = LedgerPatientPickerData(rows: seed);
            }
          },
          onRetry: () => unawaited(fetch(state.value.searched ? query : null)),
        ),
      ),
      barrierColor: const Color(0xcc000000),
    );
    final accept =
        current() && selected != null && state.value.rows.contains(selected);
    opened = false;
    state.dispose();
    if (!mounted || !_owner.alive(op)) return;
    if (accept) {
      setState(() => _patient = selected);
      await _load();
      _resetScroll();
    } else {
      setState(() {});
    }
  }

  Future<void> _pickDate(bool begin) async {
    if (!_ready) return;
    _settingAccount = true;
    _menu.close();
    _accountFocus.unfocus();
    _settingAccount = false;
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
        key: const Key('ledger_date_picker'),
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
      _rangeInvalid = false;
      _data = null;
    });
    if (_first.isNotEmpty &&
        _last.isNotEmpty &&
        parseOracleDate(_first).isAfter(parseOracleDate(_last))) {
      setState(() {
        _rangeInvalid = true;
        if (begin) {
          _first = '';
        } else {
          _last = '';
        }
      });
      return;
    }
    if (_first.isEmpty || _last.isEmpty) return;
    if (_hasSelection) {
      await _load();
      _resetScroll();
    }
  }

  Future<void> _openVoucher(LedgerEntry entry) async {
    if (!_ready ||
        !entry.row.actionable ||
        !(_data?.entries.contains(entry) ?? false)) {
      return;
    }
    final op = _owner.begin();
    setState(() => _navigating = true);
    try {
      await _owner.fresh(op);
      if (!mounted || !_owner.alive(op)) return;
      setState(() => _navigating = false);
      _childAway = true;
      try {
        if (entry.row.opensInvoice) {
          await _dialogs.push<void>(
            context,
            PaymentInvoiceScreen(
              auth: widget.auth,
              repository: widget.repository,
              paymentCode: entry.row.orderNo,
            ),
          );
        } else {
          await _dialogs.show<void>(
            context,
            VoucherReportDialog(
              auth: widget.auth,
              repository: widget.repository,
              number: entry.row.orderNo,
              formatAmount: ledgerAmount,
            ),
          );
        }
      } finally {
        _childAway = false;
        if (_owner.current && _owner.foreground) {
          if (_reloadOnReturn) {
            _reloadOnReturn = false;
            await _load(refreshAccounts: true);
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

  void _resetScroll() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_horizontal.hasClients) _horizontal.jumpTo(0);
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
    _owner.removeListener(_ownerChanged);
    _owner.dispose();
    _dialogs.dispose();
    _scroll.dispose();
    _horizontal.dispose();
    _accountFocus.removeListener(_accountBlur);
    _accountFocus.dispose();
    _accountText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    final waiting =
        _busy || !_owner.foreground || !_owner.current && _error == null;
    return PopScope(
      canPop: !_busy && !_navigating && !_menu.isOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _menu.isOpen) _menu.close();
      },
      child: NativeVoucherShell(
        title:
            widget.patientLedger
                ? 'Account Ledger (Patient)'
                : 'Account Ledger',
        backKey: 'ledger_back',
        onBack: _busy || _navigating ? null : () => unawaited(_back()),
        child:
            waiting
                ? const Center(
                  child: CircularProgressIndicator(key: Key('ledger_loading')),
                )
                : !_loaded
                ? Center(
                  child: Text(
                    _error ??
                        'Accounts access is not available for this account.',
                    textAlign: TextAlign.center,
                  ),
                )
                : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: VoucherDateField(
                                  key: const Key('ledger_begin'),
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
                                  key: const Key('ledger_end'),
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
                          if (_rangeInvalid)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Date Range is Invalid',
                                key: const Key('ledger_range_error'),
                                style: vtText(11, s, color: Colors.red),
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (widget.patientLedger)
                            NativeLedgerPatientField(
                              key: const Key('ledger_patient_select'),
                              patient: _patient,
                              onTap:
                                  _ready
                                      ? () => unawaited(_pickPatient())
                                      : null,
                            )
                          else
                            NativeLedgerAccountField(
                              text: _accountText,
                              focus: _accountFocus,
                              menu: _menu,
                              choices: _accounts,
                              enabled: _ready,
                              onMenuChanged: _menuChanged,
                              onChanged:
                                  (_) => setState(() {
                                    _account = null;
                                    _accountError = null;
                                    _data = null;
                                  }),
                              onSelected: (a) => unawaited(_chooseAccount(a)),
                              onSubmitted: () => unawaited(_submitAccount()),
                            ),
                          if (_accountError != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(3, 12, 3, 0),
                              child: Text(
                                _accountError!,
                                key: const Key('ledger_account_error'),
                                style: vtText(
                                  11,
                                  s,
                                  color: const Color(0xffff474c),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        key: const Key('ledger_scroll'),
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_data != null) ...[
                              NativeLedgerHeading(
                                account: _account,
                                patient: _patient,
                              ),
                              NativeLedgerTable(
                                data: _data!,
                                horizontal: _horizontal,
                                onVoucher:
                                    _ready
                                        ? (e) => unawaited(_openVoucher(e))
                                        : null,
                              ),
                            ],
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
