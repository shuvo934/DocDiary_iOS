import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../auth/profile_repository.dart';
import 'payment_models.dart';
import 'payment_repository.dart';
import 'payment_state.dart';
import 'native_payment_controls.dart';
import 'payment_update_models.dart';
import 'native_payment_update_controls.dart';

class PaymentServiceScreen extends StatefulWidget {
  const PaymentServiceScreen({
    super.key,
    required this.auth,
    required this.repository,
    required this.patient,
    required this.lines,
    this.editing,
    this.updateRow,
  });
  final AuthController auth;
  final PaymentRepository repository;
  final PaymentChoice patient;
  final List<PaymentServiceLine> lines;
  final PaymentServiceLine? editing;
  final PaymentUpdateLine? updateRow;
  @override
  State<PaymentServiceScreen> createState() => _ServiceState();
}

class _ServiceState extends PaymentState<PaymentServiceScreen> {
  @override
  AuthController get auth => widget.auth;
  @override
  PaymentRepository get repository => widget.repository;
  final _quantity = TextEditingController();
  List<PaymentChoice> _services = const [], _units = const [];
  PaymentChoice? _service, _unit;
  PaymentRate? _rate;
  bool _loaded = false;
  final _errors = <String, String>{};
  @override
  void initState() {
    super.initState();
    final line = widget.editing;
    if (line != null) {
      _service = line.service;
      _unit = line.unit;
      _rate = line.rate;
      _quantity.text = '${line.quantity}';
    }
  }

  @override
  void clearPayment() {
    _services = _units = const [];
    _service = _unit = null;
    _rate = null;
    _quantity.clear();
  }

  @override
  Future<void> refresh(
    AccountProfile profile,
    bool Function() isCurrent,
  ) async {
    if (widget.updateRow != null) {
      if (!_loaded && widget.updateRow!.canChangeUnit) {
        final units = await repository.units(
          session!,
          profile,
          _service!,
          isCurrent: isCurrent,
        );
        if (!isCurrent()) return;
        setState(() => _units = units);
      }
      if (isCurrent() && _unit != null && _rate == null) {
        await _rateForUnit(profile, isCurrent);
      }
      _loaded = true;
      return;
    }
    if (_loaded) {
      if (_service != null && _units.isEmpty) {
        await _unitsForService(profile, isCurrent);
      }
      if (isCurrent() && _unit != null && _rate == null) {
        await _rateForUnit(profile, isCurrent);
      }
      return;
    }
    final services = await repository.services(
      session!,
      profile,
      isCurrent: isCurrent,
    );
    if (!isCurrent()) return;
    setState(() {
      _services = services;
      if (services.isEmpty) _errors['service'] = 'No Service List Found';
    });
    if (_service != null) {
      final canonical = services.where((r) => r.id == _service!.id).firstOrNull;
      if (canonical == null) {
        setState(() {
          _service = _unit = null;
          _rate = null;
        });
      } else {
        _service = canonical;
        final units = await repository.units(
          session!,
          profile,
          canonical,
          isCurrent: isCurrent,
        );
        if (!isCurrent()) return;
        setState(() {
          _units = units;
          _unit = units.where((r) => r.id == _unit?.id).firstOrNull;
          if (_unit == null) _rate = null;
        });
      }
    }
    _loaded = true;
  }

  Future<void> _unitsForService(
    AccountProfile profile,
    bool Function() isCurrent,
  ) async {
    final service = _service!;
    final units = await repository.units(
      session!,
      profile,
      service,
      isCurrent: isCurrent,
    );
    if (!isCurrent() || _service != service) return;
    setState(() {
      _units = units;
      if (units.isEmpty) _errors['unit'] = 'No Unit List Found';
    });
  }

  Future<void> _rateForUnit(
    AccountProfile profile,
    bool Function() isCurrent,
  ) async {
    final service = _service!, unit = _unit!;
    final rate = await repository.rate(
      session!,
      profile,
      widget.patient,
      service,
      unit,
      isCurrent: isCurrent,
    );
    if (isCurrent() && _service == service && _unit == unit) {
      setState(() => _rate = rate);
    }
  }

  Future<void> _pick(BuildContext field, bool service) async {
    if (widget.updateRow != null &&
        (service || !widget.updateRow!.canChangeUnit)) {
      return;
    }
    final choice = await choose(field, service ? _services : _units);
    if (!ready || choice == null) return;
    if (service) {
      if (choice.key == _service?.key && _units.isNotEmpty) return;
      setState(() {
        _service = choice;
        _unit = null;
        _rate = null;
        _units = const [];
        _errors.clear();
      });
      await run(_unitsForService);
    } else {
      if (choice.key == _unit?.key && _rate != null) return;
      setState(() {
        _unit = choice;
        _rate = null;
        _errors.remove('unit');
        _errors.remove('rate');
      });
      await run(_rateForUnit);
    }
  }

  int? get _amount {
    if (_rate == null || _quantityError(_quantity.text) != null) {
      return null;
    }
    final n = BigInt.from(_rate!.cents) * BigInt.parse(_quantity.text);
    return n <= BigInt.from(paymentMaxCents) ? n.toInt() : null;
  }

  String? _quantityError(String value) {
    final error = paymentQuantityError(value);
    if (error != null) return error;
    final used = widget.updateRow?.used ?? 0;
    return int.parse(value) < used
        ? 'You can not provide quantity less than $used.'
        : null;
  }

  Future<void> _commit() async {
    if (!ready) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _errors.clear();
      if (_service == null) {
        _errors['service'] = 'Please Select Service';
      } else if (_unit == null) {
        _errors['unit'] = 'Please Select Unit';
      } else if (_rate == null) {
        _errors['rate'] = 'Invalid Rate. Select Unit Again';
      } else if (_quantityError(_quantity.text) != null) {
        _errors['quantity'] = _quantityError(_quantity.text)!;
      } else if (_amount == null) {
        _errors['quantity'] = 'Invalid Quantity';
      }
    });
    if (_errors.isNotEmpty) return;
    final line = PaymentServiceLine(
      service: _service!,
      unit: _unit!,
      rate: _rate!,
      quantity: int.parse(_quantity.text),
    );
    if (widget.lines.any(
      (r) => !identical(r, widget.editing) && r.key == line.key,
    )) {
      await message(
        'Duplicate Service Found!',
        'This Service is already added. Recheck again.',
      );
      return;
    }
    final editing = widget.editing != null;
    if (await confirm(
      editing ? 'Update Service!' : 'Add Service!',
      editing
          ? 'Do you want to Update this Service for patient?'
          : 'Do you want to Add Service for patient?',
      keyName: 'service_confirm',
    )) {
      if (mounted && current && foreground) Navigator.pop(context, line);
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    Widget field(
      String name,
      String label,
      String value, {
      bool enabled = true,
      bool dropdown = true,
      bool service = false,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(
          builder:
              (fieldContext) => NativeAdminAppointmentField(
                key: Key('payment_service_$name'),
                label: label,
                value: value,
                enabled: enabled,
                dropdown: dropdown,
                onTap:
                    dropdown && ready
                        ? () => unawaited(_pick(fieldContext, service))
                        : null,
              ),
        ),
        NativePaymentError(_errors[name == 'name' ? 'service' : name]),
        SizedBox(height: 12 * s),
      ],
    );
    return PopScope(
      canPop: !busy && !writing,
      child: NativePaymentShell(
        title: widget.editing == null ? 'Add Service' : 'Update Service',
        editor: true,
        onBack: () => unawaited(close()),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child:
                    busy || !current || !foreground
                        ? const Center(
                          child: CircularProgressIndicator(
                            key: Key('payment_loading'),
                          ),
                        )
                        : SingleChildScrollView(
                          key: const Key('payment_service_scroll'),
                          padding: EdgeInsets.fromLTRB(10, 12 * s, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              field(
                                'name',
                                'Service',
                                _service?.name ?? '',
                                service: true,
                                enabled: widget.updateRow == null,
                              ),
                              field(
                                'unit',
                                'Unit',
                                _unit?.name ?? '',
                                enabled:
                                    _service != null &&
                                    _units.isNotEmpty &&
                                    (widget.updateRow?.canChangeUnit ?? true),
                              ),
                              field(
                                'rate',
                                'Rate',
                                _rate == null ? '' : paymentMoney(_rate!.cents),
                                enabled: false,
                                dropdown: false,
                              ),
                              NativePaymentEntry(
                                key: const Key('payment_service_quantity'),
                                label: 'Quantity',
                                controller: _quantity,
                                onChanged:
                                    (value) => setState(() {
                                      final e = _quantityError(value);
                                      if (e == null) {
                                        _errors.remove('quantity');
                                      } else {
                                        _errors['quantity'] = e;
                                      }
                                    }),
                              ),
                              NativePaymentError(_errors['quantity']),
                              SizedBox(height: 12 * s),
                              field(
                                'amount',
                                'Total Amount',
                                _amount == null ? '' : paymentMoney(_amount!),
                                enabled: false,
                                dropdown: false,
                              ),
                              if (widget.updateRow != null)
                                NativePaymentQuantitySummary(
                                  row: widget.updateRow!,
                                  available:
                                      _quantityError(_quantity.text) == null
                                          ? int.parse(_quantity.text) -
                                              widget.updateRow!.used
                                          : 0,
                                ),
                            ],
                          ),
                        ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: NativeAdminAppointmentButton(
                  key: const Key('payment_service_commit'),
                  label: widget.editing == null ? 'ADD' : 'UPDATE',
                  onPressed: ready ? () => unawaited(_commit()) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
