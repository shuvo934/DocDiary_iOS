import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/failure.dart';
import '../../auth/auth_controller.dart';
import '../../dashboard/native_dashboard_dialogs.dart';
import '../accounts_dashboard_repository.dart';
import 'native_payment_invoice_layout.dart';
import 'native_voucher_controls.dart';
import 'voucher_models.dart';
import 'voucher_read_owner.dart';
import 'voucher_repository.dart';

class PaymentInvoiceScreen extends StatefulWidget {
  const PaymentInvoiceScreen({
    super.key,
    required this.auth,
    required this.repository,
    required this.paymentCode,
  });
  final AuthController auth;
  final VoucherRepository repository;
  final String paymentCode;
  @override
  State<PaymentInvoiceScreen> createState() => _InvoiceState();
}

class _InvoiceState extends State<PaymentInvoiceScreen> {
  late final VoucherReadOwner _owner;
  final _dialogs = NativeDashboardDialogOwner(), _scroll = ScrollController();
  PaymentInvoiceData? _data;
  bool _busy = true;
  String? _message;
  @override
  void initState() {
    super.initState();
    _owner = VoucherReadOwner(
      widget.auth,
      widget.repository,
      onResume: () => unawaited(_load()),
    )..addListener(_ownerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_owner.current && _owner.foreground) {
        unawaited(_load());
      } else if (mounted && !_owner.current) {
        setState(() {
          _busy = false;
          _message = 'Accounts access is not available for this account.';
        });
      }
    });
  }

  void _ownerChanged() {
    if (!_owner.current || !_owner.foreground) {
      _dialogs.close();
      _data = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (!_owner.current || !_owner.foreground || _dialogs.isOpen) return;
    final op = _owner.begin();
    setState(() {
      _busy = true;
      _data = null;
      _message = null;
    });
    try {
      final profile = await _owner.fresh(op);
      final invoice = await widget.repository.invoice(
        _owner.session!,
        profile,
        widget.paymentCode,
        isCurrent: () => _owner.alive(op),
      );
      if (!_owner.alive(op)) return;
      setState(() {
        _data = invoice;
        _busy = false;
      });
    } catch (failure) {
      if (!mounted || !_owner.alive(op) || failure is ObsoleteRequest) return;
      if (_owner.blockDenied(failure)) return;
      setState(() {
        _busy = false;
        _data = null;
        _message =
            failure is AccountsModuleUnavailable
                ? 'Accounts access is not available for this account.'
                : dashboardErrorMessage(failure);
      });
      final retry = await _dialogs.show<bool>(
        context,
        AlertDialog(
          key: const Key('invoice_error'),
          title: Text('Error!', style: dashboardDialogText(20)),
          content: SingleChildScrollView(
            child: Text(_message!, style: dashboardDialogText(16)),
          ),
          actions: [
            TextButton(
              key: const Key('invoice_error_exit'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Exit'),
            ),
            TextButton(
              key: const Key('invoice_error_retry'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
      if (!_owner.alive(op)) return;
      if (retry == true) {
        await _load();
      } else {
        await _back();
      }
    }
  }

  Future<void> _back() async {
    if (mounted && !_busy && !_dialogs.isOpen) {
      await Navigator.maybePop(context);
    }
  }

  @override
  void dispose() {
    _owner.removeListener(_ownerChanged);
    _owner.dispose();
    _dialogs.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: NativeVoucherShell(
      title: 'Payment Invoice',
      backKey: 'invoice_back',
      onBack: _busy ? null : () => unawaited(_back()),
      child:
          !_owner.current || !_owner.foreground || _busy
              ? const Center(
                child: CircularProgressIndicator(key: Key('invoice_loading')),
              )
              : _data == null
              ? Center(child: Text(_message ?? 'No data found'))
              : NativePaymentInvoiceLayout(invoice: _data!, scroll: _scroll),
    ),
  );
}
