import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/failure.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../../dashboard/native_dashboard_dialogs.dart';
import '../../reports/native_report_pdf_platform.dart';
import '../../reports/report_manager_menu.dart';
import '../../reports/report_manager_models.dart';
import '../../reports/report_manager_repository.dart';
import '../../reports/report_pdf_screen.dart';
import '../../reports/report_pdf_transport.dart';
import '../accounts_dashboard_repository.dart';
import '../accounts_dashboard_navigation.dart';
import '../voucher_transaction/native_voucher_controls.dart';
import '../voucher_transaction/voucher_models.dart';
import '../voucher_transaction/voucher_read_owner.dart';
import 'statement_repository.dart';

/// A direct Accounts report shares the existing PDF viewer, never the Report
/// Manager catalogue or its unrelated permissions/filter parameters.
class DailyStatementRequest extends ReportRequest {
  DailyStatementRequest(VoucherDates dates)
    : super(
        item: ReportManagerItem.paymentRegister,
        begin: dates.firstDay,
        end: dates.lastDay,
        beginText: dates.first,
        endText: dates.last,
      );
  @override
  String get title => 'Daily Statement';
  @override
  String get reportFile => 'DAILY_STATEMENT.rep';
  @override
  bool get dateOnlyPdf => true;
}

class DailyStatementReportRepository extends ReportManagerRepository {
  DailyStatementReportRepository(super.transport, {super.now});
  @override
  String get moduleName => 'Daily Statement';
  @override
  void guard(
    AuthSession session,
    AccountProfile profile,
    ReportManagerItem item,
    bool Function() isCurrent,
  ) {
    try {
      AccountsDashboardRepository(
        transport,
        now: now,
      ).guard(session, profile, isCurrent);
      if (!accountsDailyStatementAllowed(session.center.baseUri)) {
        throw const ReportManagerUnavailable();
      }
    } on AccountsModuleUnavailable {
      throw const ReportManagerUnavailable();
    }
  }
}

class DailyStatementScreen extends StatefulWidget {
  const DailyStatementScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.firstDate = '',
    this.lastDate = '',
    this.platform,
    this.transportFactory,
  });
  final AuthController auth;
  final StatementRepository repository;
  final String firstDate, lastDate;
  final ReportPdfPlatform? platform;
  final ReportPdfTransport Function()? transportFactory;
  @override
  State<DailyStatementScreen> createState() => _DailyState();
}

class _DailyState extends State<DailyStatementScreen> {
  late final VoucherReadOwner _owner;
  final _dialogs = NativeDashboardDialogOwner();
  ReportServerConfig? _config;
  DailyStatementRequest? _request;
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _owner = VoucherReadOwner(
      widget.auth,
      widget.repository,
      onResume: () {
        if (_config == null) unawaited(_load());
      },
    )..addListener(_changed);
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

  void _changed() {
    if (!_owner.current || !_owner.foreground && _config == null) {
      _dialogs.close();
      if (!_owner.current) _config = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (!_owner.current || !_owner.foreground || _dialogs.isOpen) return;
    final op = _owner.begin();
    setState(() {
      _busy = true;
      _error = null;
      _config = null;
    });
    try {
      final dates = VoucherDates.initial(
        widget.firstDate,
        widget.lastDate,
        widget.repository.now(),
      );
      final profile = await _owner.fresh(op),
          config = await widget.repository.dailyConfig(
            _owner.session!,
            profile,
            isCurrent: () => _owner.alive(op),
          );
      final request = DailyStatementRequest(dates);
      config.url(
        request,
      ); // Validate configuration before attaching the PDF viewer.
      if (!mounted || !_owner.alive(op)) return;
      setState(() {
        _config = config;
        _request = request;
        _busy = false;
      });
    } catch (error) {
      if (!mounted ||
          !_owner.alive(op) ||
          error is ObsoleteRequest ||
          _owner.blockDenied(error)) {
        return;
      }
      setState(() {
        _busy = false;
        _error =
            error is AccountsModuleUnavailable
                ? 'Daily Statement is not available for this account.'
                : dashboardErrorMessage(
                  error is AppFailure
                      ? error
                      : const AppFailure('The report could not be loaded.'),
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
          key: const Key('daily_error'),
          title: Text('Error!', style: dashboardDialogText(20)),
          content: Text(_error!),
          actions: [
            TextButton(
              key: const Key('daily_error_exit'),
              onPressed: () => answer(false),
              child: const Text('Exit'),
            ),
            TextButton(
              key: const Key('daily_error_retry'),
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
        await Navigator.maybePop(context);
      }
    }
  }

  @override
  void dispose() {
    _owner.removeListener(_changed);
    _owner.dispose();
    _dialogs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_config != null && _owner.current) {
      return ReportPdfScreen(
        auth: widget.auth,
        repository: DailyStatementReportRepository(
          widget.repository.transport,
          now: widget.repository.now,
        ),
        request: _request!,
        config: _config!,
        platform: widget.platform,
        transportFactory: widget.transportFactory,
      );
    }
    return PopScope(
      canPop: !_busy,
      child: NativeVoucherShell(
        title: 'Daily Statement',
        backKey: 'daily_back',
        onBack: _busy ? null : () => unawaited(Navigator.maybePop(context)),
        child:
            _busy
                ? const Center(
                  child: CircularProgressIndicator(key: Key('daily_loading')),
                )
                : Center(
                  child: Text(
                    _error ?? 'Daily Statement is not available.',
                    textAlign: TextAlign.center,
                  ),
                ),
      ),
    );
  }
}
