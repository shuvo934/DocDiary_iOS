import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../auth/auth_controller.dart';
import '../../dashboard/native_dashboard_dialogs.dart';
import '../accounts_dashboard_repository.dart';
import '../native_accounts_donut.dart';
import 'native_voucher_controls.dart';
import 'native_voucher_tables.dart';
import 'payment_invoice_screen.dart';
import 'voucher_models.dart';
import 'voucher_read_owner.dart';
import 'voucher_report_dialog.dart';
import 'voucher_repository.dart';

class VoucherTransactionScreen extends StatefulWidget {
  const VoucherTransactionScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.firstDate = '',
    this.lastDate = '',
  });
  final AuthController auth;
  final VoucherRepository repository;
  final String firstDate, lastDate;
  @override
  State<VoucherTransactionScreen> createState() => _VoucherState();
}

class _VoucherState extends State<VoucherTransactionScreen> {
  late final VoucherReadOwner _owner;
  late String _first, _last;
  VoucherDates? _appliedDates;
  VoucherData? _data;
  String _selected = '';
  String? _error;
  bool _busy = true,
      _navigating = false,
      _selecting = false,
      _childAway = false,
      _rangeInvalid = false,
      _disposing = false;
  final _dialogs = NativeDashboardDialogOwner();
  final _scroll = ScrollController(), _horizontal = ScrollController();
  final _menu = MenuController();
  bool get _ready =>
      _owner.current &&
      _owner.foreground &&
      !_busy &&
      !_navigating &&
      !_selecting &&
      !_dialogs.isOpen &&
      _data != null;
  @override
  void initState() {
    super.initState();
    final now = widget.repository.now();
    _first =
        widget.firstDate.isEmpty
            ? VoucherDates.initial('', '', now).first
            : widget.firstDate;
    _last =
        widget.lastDate.isEmpty
            ? VoucherDates.initial('', '', now).last
            : widget.lastDate;
    _owner = VoucherReadOwner(
      widget.auth,
      widget.repository,
      onResume: () {
        if (!_childAway) unawaited(_load(preserveFilter: true));
      },
    )..addListener(_ownerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_owner.current && _owner.foreground) {
        unawaited(_load());
      } else if (mounted && !_owner.current) {
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

  void _ownerChanged() {
    _menu.close();
    if (!_owner.current) {
      _dialogs.close();
      _data = null;
    }
    if (!_owner.foreground && !_childAway) {
      _dialogs.close();
      _data = null;
      _busy = true;
    }
    if (mounted) setState(() {});
  }

  Future<void> _load({bool preserveFilter = false}) async {
    if (!_owner.current ||
        !_owner.foreground ||
        _dialogs.isOpen ||
        _childAway) {
      return;
    }
    final op = _owner.begin(), oldFilter = _selected;
    setState(() {
      _busy = true;
      _data = null;
      _error = null;
      if (!preserveFilter) _selected = '';
    });
    try {
      final dates =
          preserveFilter &&
                  (_first.isEmpty || _last.isEmpty) &&
                  _appliedDates != null
              ? _appliedDates!
              : VoucherDates(_first, _last);
      final profile = await _owner.fresh(op),
          data = await widget.repository.load(
            _owner.session!,
            profile,
            dates,
            isCurrent: () => _owner.alive(op),
          );
      if (!mounted || !_owner.alive(op)) return;
      setState(() {
        _data = data;
        _appliedDates = dates;
        _busy = false;
        _selected =
            preserveFilter && data.typeOptions.contains(oldFilter)
                ? oldFilter
                : '';
      });
    } catch (failure) {
      if (!mounted || !_owner.alive(op) || failure is ObsoleteRequest) return;
      await _failed(failure, op);
    }
  }

  Future<void> _failed(Object failure, int op) async {
    if (_owner.blockDenied(failure)) return;
    setState(() {
      _busy = false;
      _navigating = false;
      _data = null;
      _error =
          failure is AccountsModuleUnavailable
              ? 'Accounts access is not available for this account.'
              : dashboardErrorMessage(failure);
    });
    final retry = await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: const Key('vt_error'),
        title: Text('Error!', style: dashboardDialogText(20)),
        content: SingleChildScrollView(
          child: Text(_error!, style: dashboardDialogText(16)),
        ),
        actions: [
          TextButton(
            key: const Key('vt_error_exit'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Exit'),
          ),
          TextButton(
            key: const Key('vt_error_retry'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    if (!mounted || !_owner.alive(op)) return;
    if (retry == true) {
      await _load(preserveFilter: true);
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
    final raw = begin ? _first : _last;
    DateTime initial;
    try {
      initial = raw.isEmpty ? now : parseOracleDate(raw);
    } catch (_) {
      initial = now;
    }
    if (initial.isBefore(earliest)) initial = earliest;
    if (initial.isAfter(DateTime(2100, 12, 31))) {
      initial = DateTime(2100, 12, 31);
    }
    setState(() => _selecting = true);
    final chosen = await _dialogs.show<DateTime>(
      context,
      DatePickerDialog(
        key: const Key('vt_date_picker'),
        initialDate: initial,
        firstDate: earliest,
        lastDate: DateTime(2100, 12, 31),
      ),
    );
    if (mounted) setState(() => _selecting = false);
    if (!_owner.alive(op) || chosen == null) return;
    setState(() {
      if (begin) {
        _first = oracleDate(chosen);
      } else {
        _last = oracleDate(chosen);
      }
      _rangeInvalid = false;
    });
    if (_first.isEmpty || _last.isEmpty) return;
    if (parseOracleDate(_first).isAfter(parseOracleDate(_last))) {
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
    await _load();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_horizontal.hasClients) _horizontal.jumpTo(0);
  }

  void _filter(String value) {
    if (!_ready || !_data!.typeOptions.contains(value)) return;
    setState(() => _selected = value == '...' ? '' : value);
  }

  Future<void> _open(VoucherEntry entry) async {
    if (!_ready ||
        !entry.actionable ||
        !_data!
            .filtered(_selected)
            .days
            .any((d) => d.entries.contains(entry))) {
      return;
    }
    _menu.close();
    final op = _owner.begin();
    setState(() => _navigating = true);
    try {
      await _owner.fresh(op);
      if (!mounted || !_owner.alive(op)) return;
      setState(() => _navigating = false);
      _childAway = true;
      try {
        if (entry.opensInvoice) {
          await _dialogs.push<void>(
            context,
            PaymentInvoiceScreen(
              auth: widget.auth,
              repository: widget.repository,
              paymentCode: entry.orderNo,
            ),
          );
        } else {
          await _dialogs.show<void>(
            context,
            VoucherReportDialog(
              auth: widget.auth,
              repository: widget.repository,
              number: entry.orderNo,
            ),
          );
        }
      } finally {
        _childAway = false;
        if (_owner.current && _owner.foreground) {
          final check = _owner.begin();
          setState(() => _navigating = true);
          try {
            await _owner.fresh(check);
            if (_owner.alive(check)) setState(() => _navigating = false);
          } catch (failure) {
            if (mounted && _owner.alive(check) && failure is! ObsoleteRequest) {
              await _failed(failure, check);
            }
          }
        }
      }
    } catch (failure) {
      if (mounted && _owner.alive(op) && failure is! ObsoleteRequest) {
        await _failed(failure, op);
      }
    }
  }

  Future<void> _back() async {
    if (!mounted || _busy || _navigating || _selecting || _dialogs.isOpen) {
      return;
    }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context),
        visible = _data?.filtered(_selected),
        zoom = MediaQuery.textScalerOf(context).scale(12) / 12;
    Widget date(bool begin) => VoucherDateField(
      key: Key(begin ? 'vt_begin' : 'vt_end'),
      label: begin ? 'Begin Date' : 'End Date',
      value: begin ? _first : _last,
      onTap: _ready ? () => unawaited(_pickDate(begin)) : null,
    );
    Widget filters() => Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (zoom > 1.4 && MediaQuery.sizeOf(context).width < 600) ...[
            date(true),
            const SizedBox(height: 8),
            date(false),
          ] else
            Row(
              children: [
                Expanded(child: date(true)),
                const SizedBox(width: 6),
                Expanded(child: date(false)),
              ],
            ),
          if (_rangeInvalid)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'Date Range is Invalid',
                key: const Key('vt_invalid_range'),
                style: vtText(10, s, color: Colors.red),
              ),
            ),
          const SizedBox(height: 12),
          VoucherTypeField(
            controller: _menu,
            selected: _selected,
            choices: _data?.typeOptions ?? [],
            enabled: _ready,
            onSelected: _filter,
            onMenuChanged: _menuChanged,
          ),
        ],
      ),
    );
    final waiting =
        _busy || !_owner.foreground || !_owner.current && _error == null;
    return PopScope(
      canPop: !_busy && !_navigating && !_selecting && !_menu.isOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _menu.isOpen) _menu.close();
      },
      child: NativeVoucherShell(
        title: 'Voucher Transaction',
        backKey: 'vt_back',
        onBack:
            _busy || _navigating || _selecting
                ? null
                : () => unawaited(_back()),
        child:
            waiting
                ? const Center(
                  child: CircularProgressIndicator(key: Key('vt_loading')),
                )
                : visible == null
                ? Center(
                  child: Text(
                    _error ?? 'No Voucher Transaction Found',
                    textAlign: TextAlign.center,
                  ),
                )
                : Column(
                  children: [
                    filters(),
                    Expanded(
                      child: SingleChildScrollView(
                        key: const Key('vt_scroll'),
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Material(
                              color: Colors.white,
                              elevation: 2,
                              borderRadius: BorderRadius.circular(10),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      6,
                                      10,
                                      0,
                                    ),
                                    child: Text(
                                      'Total Voucher : ${visible.totalCount}',
                                      key: const Key('vt_count'),
                                      style: vtText(
                                        11,
                                        s,
                                        color: DocColors.primary,
                                        family: 'Poppins',
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
                                      key: const Key('vt_chart'),
                                      title: 'Voucher',
                                      centerText: '',
                                      allowRotation: _ready,
                                      pieWidthFraction: .60,
                                      slices: [
                                        for (final c in visible.counts)
                                          if (!c.count.isZero)
                                            AccountsPieSlice(
                                              c.label,
                                              c.count,
                                              accountsVoucherColors[c
                                                      .colorIndex %
                                                  accountsVoucherColors.length],
                                            ),
                                      ],
                                      scale: s,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 12 * s,
                              ),
                              child: Text(
                                visible.dates.label,
                                key: const Key('vt_list_caption'),
                                style: vtText(
                                  10,
                                  s,
                                  family: 'Poppins',
                                  color: DocColors.greenSea,
                                ),
                              ),
                            ),
                            NativeVoucherTable(
                              data: visible,
                              horizontal: _horizontal,
                              onEntry: (e) => unawaited(_open(e)),
                              enabled: _ready,
                            ),
                            if (visible.days.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(18),
                                child: Text(
                                  'No Voucher Transaction Found',
                                  key: const Key('vt_empty'),
                                  textAlign: TextAlign.center,
                                  style: vtText(12, s, family: 'Poppins'),
                                ),
                              ),
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
