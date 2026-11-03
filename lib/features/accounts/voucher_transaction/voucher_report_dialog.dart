import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/failure.dart';
import '../../auth/auth_controller.dart';
import '../../dashboard/native_dashboard_dialogs.dart';
import '../accounts_dashboard_repository.dart';
import '../accounts_loading_boundary.dart';
import 'native_voucher_controls.dart';
import 'native_voucher_tables.dart';
import 'voucher_models.dart';
import 'voucher_read_owner.dart';
import 'voucher_repository.dart';

class VoucherReportDialog extends StatefulWidget {
  const VoucherReportDialog({
    super.key,
    required this.auth,
    required this.repository,
    required this.number,
    this.formatAmount,
  });
  final AuthController auth;
  final VoucherRepository repository;
  final String number;
  final String Function(VtMoney)? formatAmount;
  @override
  State<VoucherReportDialog> createState() => _ReportState();
}

class _ReportState extends State<VoucherReportDialog> {
  late final VoucherReadOwner _owner;
  final _horizontal = ScrollController();
  VoucherReport? _report;
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _owner = VoucherReadOwner(
      widget.auth,
      widget.repository,
      onResume: () => unawaited(_load()),
    )..addListener(_ownerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  void _ownerChanged() {
    if (!_owner.current || !_owner.foreground) {
      _report = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (!_owner.current || !_owner.foreground) return;
    final op = _owner.begin();
    setState(() {
      _busy = true;
      _report = null;
      _error = null;
    });
    try {
      final profile = await _owner.fresh(op),
          report = await widget.repository.report(
            _owner.session!,
            profile,
            widget.number,
            isCurrent: () => _owner.alive(op),
          );
      if (!_owner.alive(op)) return;
      setState(() {
        _report = report;
        _busy = false;
      });
    } catch (failure) {
      if (!mounted || !_owner.alive(op) || failure is ObsoleteRequest) return;
      if (_owner.blockDenied(failure)) return;
      setState(() {
        _busy = false;
        _report = null;
        _error =
            failure is AccountsModuleUnavailable
                ? 'Accounts access is not available for this account.'
                : dashboardErrorMessage(failure);
      });
    }
  }

  @override
  void dispose() {
    _owner.removeListener(_ownerChanged);
    _owner.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context),
        size = MediaQuery.sizeOf(context),
        report = _report;
    Widget metadata(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: vtText(
                9,
                s,
                family: 'Poppins',
                weight: FontWeight.w500,
                color: vtCloud,
              ),
            ),
          ),
          Expanded(child: Text(':', style: vtText(9, s, color: vtCloud))),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: vtText(9, s, family: 'Poppins', weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return AccountsLoadingBoundary(
      busy: _busy,
      child: Dialog(
        key: const Key('vt_report_dialog'),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: math.max(
              100,
              size.height - MediaQuery.paddingOf(context).vertical - 48,
            ),
          ),
          child: SizedBox(
            width: math.min(560, size.width - 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: DocColors.primary,
                  child: Padding(
                    padding: EdgeInsets.all(10 * s),
                    child: Text(
                      VoucherReport(widget.number, []).title,
                      style: vtText(
                        15,
                        s,
                        family: 'Poppins',
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    key: const Key('vt_report_scroll'),
                    padding: const EdgeInsets.fromLTRB(5, 3, 5, 8),
                    child:
                        _busy || !_owner.current || !_owner.foreground
                            ? const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: CircularProgressIndicator(
                                  key: Key('vt_report_loading'),
                                ),
                              ),
                            )
                            : _error != null
                            ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _error!,
                                    key: const Key('vt_report_error'),
                                    textAlign: TextAlign.center,
                                  ),
                                  TextButton(
                                    key: const Key('vt_report_retry'),
                                    onPressed: () => unawaited(_load()),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                            : report == null || report.empty
                            ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No Voucher Details Found',
                                textAlign: TextAlign.center,
                              ),
                            )
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 2,
                                    bottom: 2,
                                  ),
                                  child: Text(
                                    widget.number,
                                    key: const Key('vt_report_number'),
                                    textAlign: TextAlign.center,
                                    style: vtText(
                                      14,
                                      s,
                                      family: 'PatuaOne',
                                      weight: FontWeight.w400,
                                      color: DocColors.greenSea,
                                    ),
                                  ),
                                ),
                                metadata('Voucher Date', report.date),
                                metadata('Bill Ref. No:', report.reference),
                                metadata(
                                  'Bill Ref. Date:',
                                  report.referenceDate,
                                ),
                                const SizedBox(height: 8),
                                NativeVoucherReportTable(
                                  report: report,
                                  horizontal: _horizontal,
                                  formatAmount: widget.formatAmount,
                                ),
                              ],
                            ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 16, 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('vt_report_ok'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed:
                          _busy || !_owner.current || !_owner.foreground
                              ? null
                              : () => Navigator.pop(context),
                      child: Text(
                        'OK',
                        style: vtText(
                          11,
                          s,
                          color: DocColors.primary,
                          family: 'Roboto',
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
