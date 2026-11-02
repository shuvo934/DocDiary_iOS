import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../auth/auth_controller.dart';
import '../auth/profile_repository.dart';
import '../reports/native_report_icons.dart';
import 'payment_models.dart';
import 'payment_repository.dart';
import 'payment_state.dart';
import 'native_payment_controls.dart';

class PaymentConfirmationDialog extends StatefulWidget {
  const PaymentConfirmationDialog({
    super.key,
    required this.auth,
    required this.repository,
    required this.lines,
    this.initialAllocations = const [],
  });
  final AuthController auth;
  final PaymentRepository repository;
  final List<PaymentServiceLine> lines;
  final List<PaymentAllocation> initialAllocations;
  @override
  State<PaymentConfirmationDialog> createState() => _ConfirmationState();
}

class _ConfirmationState extends PaymentState<PaymentConfirmationDialog> {
  @override
  AuthController get auth => widget.auth;
  @override
  PaymentRepository get repository => widget.repository;
  final _amount = TextEditingController();
  PaymentQuote? _quote;
  PaymentChoice? _selected;
  final _saved = <PaymentAllocation>[];
  String? _amountError;
  bool _answered = false;
  @override
  void initState() {
    super.initState();
    _saved.addAll(widget.initialAllocations);
  }

  @override
  void clearPayment() {
    _quote = null;
    _selected = null;
    _saved.clear();
    _amount.clear();
  }

  @override
  Future<void> refresh(
    AccountProfile profile,
    bool Function() isCurrent,
  ) async {
    if (profile.value('is_pay_mode_active') != '1') {
      await message(
        'Payment settings changed',
        'Please reopen payment confirmation.',
      );
      if (current && foreground) await close(force: true);
      return;
    }
    if (_quote != null) return;
    final quote = await repository.quote(
      session!,
      profile,
      widget.lines,
      isCurrent: isCurrent,
    );
    if (isCurrent()) setState(() => _quote = quote);
  }

  int get _allocated => _saved.fold(0, (n, r) => n + r.cents);
  int get _remaining => (_quote?.grandTotal ?? 0) - _allocated;
  int get _pending {
    if (_selected == null || _amountError != null) return 0;
    final cents = paymentCents(_amount.text);
    return cents != null && cents > 0 && cents <= _remaining ? cents : 0;
  }

  void _change(String value) {
    final cents = paymentCents(value);
    setState(
      () =>
          _amountError =
              value.isEmpty
                  ? 'Please Provide Amount'
                  : cents == null || cents <= 0 || value.startsWith('0')
                  ? 'Invalid Amount'
                  : cents > _remaining
                  ? 'Amount is greater than need to pay'
                  : null,
    );
  }

  Future<void> _method(BuildContext field) async {
    if (_quote == null || _remaining == 0) return;
    final rows =
        _quote!.methods
            .where((m) => !_saved.any((s) => s.method.key == m.key))
            .toList();
    final selected = await choose(field, rows);
    if (!ready || selected == null) return;
    setState(() {
      _selected = selected;
      if (_amount.text.isEmpty) {
        _amount.text = paymentMoney(_remaining, fixed: true);
      }
      _amountError = null;
    });
    _change(_amount.text);
  }

  void _add() {
    if (!ready) return;
    FocusScope.of(context).unfocus();
    if (_selected == null) {
      toasts.show(context, 'Please Select Payment Method');
      return;
    }
    if (_pending == 0) {
      _change(_amount.text);
      toasts.show(context, 'Please Provide Amount');
      return;
    }
    setState(() {
      _saved.add(PaymentAllocation(_selected!, _pending));
      _selected = null;
      _amount.clear();
      _amountError = null;
    });
  }

  Future<void> _remove(int index) async {
    if (!ready || index >= _saved.length) return;
    // Native SelectedPayMethodAdapter removes directly without a second dialog.
    setState(() {
      _saved.removeAt(index);
      _selected = null;
      _amount.clear();
      _amountError = null;
    });
  }

  void _confirm() {
    if (!ready || _quote == null || _answered) return;
    if (_remaining != 0) {
      toasts.show(
        context,
        _pending > 0 && _remaining == _pending
            ? 'Please add your payment method first.'
            : 'Please provide full payment information',
      );
      return;
    }
    _answered = true;
    FocusScope.of(context).unfocus();
    Navigator.pop(
      context,
      PaymentConfirmation(_quote!, _saved, saved: widget.initialAllocations),
    );
  }

  void _cancel() {
    if (!writing && !_answered) {
      _answered = true;
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context), size = MediaQuery.sizeOf(context);
    final quote = _quote;
    Widget summary(String label, int cents, String key) => Padding(
      padding: EdgeInsets.symmetric(vertical: 6 * s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: adminAppointmentText(
                11,
                s,
                weight: FontWeight.w700,
                color: const Color(0xff6c6e6f),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  paymentMoney(cents, fixed: true),
                  key: Key('payment_confirm_$key'),
                  maxLines: 1,
                  softWrap: false,
                  style: adminAppointmentText(11, s, weight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Widget methodCard() => Material(
      color: Colors.white,
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: DocColors.primary,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Text(
                'Payment Method',
                textAlign: TextAlign.center,
                style: adminAppointmentText(
                  11,
                  s,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Builder(
                  builder:
                      (field) => NativeAdminAppointmentField(
                        key: const Key('payment_confirm_method'),
                        label: 'Select Payment Method',
                        value: _selected?.name ?? '',
                        enabled: ready && _remaining > 0,
                        onTap: () => unawaited(_method(field)),
                      ),
                ),
                SizedBox(height: 9 * s),
                NativePaymentEntry(
                  key: const Key('payment_confirm_amount'),
                  label: 'Amount',
                  controller: _amount,
                  decimal: true,
                  enabled: ready && _selected != null,
                  onChanged: _change,
                ),
                NativePaymentError(_amountError),
                SizedBox(height: 7 * s),
                Align(
                  alignment: Alignment.centerRight,
                  child: NativePaymentPill(
                    key: const Key('payment_confirm_add'),
                    label: 'ADD',
                    patua: false,
                    onPressed: ready ? _add : null,
                  ),
                ),
                SizedBox(height: 6 * s),
                Text(
                  'Selected Payment Method',
                  style: adminAppointmentText(
                    11,
                    s,
                    weight: FontWeight.w700,
                    color: DocColors.greenSea,
                  ),
                ),
                if (_saved.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 22 * s, 0, 6 * s),
                    child: Text(
                      'No Payment Method Selected',
                      textAlign: TextAlign.center,
                      style: adminAppointmentText(
                        10,
                        s,
                        weight: FontWeight.w700,
                        color: const Color(0xff777777),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < _saved.length; i++)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6 * s),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 10,
                            child: Text(
                              '${i + 1}',
                              textAlign: TextAlign.center,
                              style: adminAppointmentText(
                                9,
                                s,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 53,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _saved[i].method.name,
                                  style: adminAppointmentText(
                                    9.5,
                                    s,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 3 * s),
                                Text(
                                  _saved[i].method.value('account_name'),
                                  style: adminAppointmentText(
                                    8.5,
                                    s,
                                    weight: FontWeight.w700,
                                    color: const Color(0xff6c6e6f),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 25,
                            child: NativePaymentNumber(
                              paymentMoney(
                                _saved[i].cents,
                                fixed: _saved[i].savedId.isEmpty,
                              ),
                              style: adminAppointmentText(
                                9.5,
                                s,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 12,
                            child: IconButton(
                              key: Key('payment_confirm_delete_$i'),
                              tooltip: 'Delete payment method',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minHeight: 40,
                                minWidth: 24,
                              ),
                              onPressed:
                                  ready ? () => unawaited(_remove(i)) : null,
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
              ],
            ),
          ),
        ],
      ),
    );
    return Dialog(
      key: const Key('payment_confirmation'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      child: SizedBox(
        width: math.min(680, size.width - 48),
        height: size.height * .9,
        child: Column(
          children: [
            ColoredBox(
              color: DocColors.clouds,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * s,
                  vertical: 8 * s,
                ),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('payment_confirm_close'),
                      tooltip: 'Close',
                      onPressed: _cancel,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 40,
                      ),
                      icon: NativeReportIcon(
                        ReportGlyph.close,
                        size: 21 * s,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(width: 6 * s),
                    Expanded(
                      child: Text(
                        'Payment Confirmation',
                        style: adminAppointmentText(
                          12,
                          s,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: DocColors.greenSea),
            Expanded(
              child:
                  busy || !current || !foreground || quote == null
                      ? Center(
                        child:
                            error == null || busy
                                ? const CircularProgressIndicator()
                                : TextButton(
                                  key: const Key('payment_confirm_retry'),
                                  onPressed: () => unawaited(run(refresh)),
                                  child: const Text('Retry'),
                                ),
                      )
                      : SingleChildScrollView(
                        key: const Key('payment_confirm_scroll'),
                        padding: EdgeInsets.all(8 * s),
                        child: Column(
                          children: [
                            summary('Total Amount :', quote.total, 'total'),
                            summary('Service Charge :', quote.charge, 'charge'),
                            summary('Grand Total :', quote.grandTotal, 'grand'),
                            summary(
                              'Need To Pay :',
                              _remaining - _pending,
                              'need',
                            ),
                            summary(
                              'Paid Amount :',
                              _allocated + _pending,
                              'paid',
                            ),
                            SizedBox(height: 5 * s),
                            methodCard(),
                          ],
                        ),
                      ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(8 * s, 8 * s, 8 * s, 12 * s),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextButton(
                      key: const Key('payment_confirm_cancel'),
                      onPressed: _cancel,
                      child: Text(
                        'CANCEL',
                        style: adminAppointmentText(
                          11,
                          s,
                          weight: FontWeight.w700,
                          color: DocColors.greenSea,
                        ).copyWith(letterSpacing: 1.25),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: TextButton(
                      key: const Key('payment_confirm_commit'),
                      onPressed: ready ? _confirm : null,
                      style: TextButton.styleFrom(
                        backgroundColor: DocColors.greenSea,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.all(8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: DocColors.primary),
                        ),
                      ),
                      child: Text(
                        'CONFIRM PAYMENT',
                        textAlign: TextAlign.center,
                        style: adminAppointmentText(
                          11,
                          s,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ).copyWith(letterSpacing: 1.25),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
