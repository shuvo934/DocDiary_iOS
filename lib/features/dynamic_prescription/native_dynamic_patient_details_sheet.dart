import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/failure.dart';
import '../../core/native_json.dart';
import 'dynamic_clinical_models.dart';
import 'native_dynamic_builder_layout.dart';
import 'native_dynamic_rx_controls.dart';

class NativeDynamicPatientDetailsSheet extends StatefulWidget {
  const NativeDynamicPatientDetailsSheet({
    super.key,
    required this.load,
    this.allowPatientChange = false,
  });
  final Future<JsonMap> Function() load;
  final bool allowPatientChange;
  @override
  State<NativeDynamicPatientDetailsSheet> createState() =>
      _PatientDetailsState();
}

class _PatientDetailsState extends State<NativeDynamicPatientDetailsSheet> {
  JsonMap? _data;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _data = null;
      _error = null;
    });
    try {
      final data = await widget.load();
      if (!mounted || request != _request) return;
      setState(() => _data = data);
    } on ObsoleteRequest {
      if (mounted && request == _request) Navigator.pop(context);
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(
        () =>
            _error =
                error is AppFailure
                    ? error.message
                    : 'Server Problem or Internet Not Connected',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context);
    const fields = [
      ('Patient Name', 'pat_name'),
      ('Patient Code', 'ph_sub_code'),
      ('Age', 'pat_age'),
      ('Gender', 'gender'),
      ('Marital Status', 'marital_status'),
      ('Blood Group', 'pat_blood'),
      ('Patient Category', 'pat_category_name'),
      ('Mobile Number', 'pat_cell'),
      ('Phone Number', 'pat_phone'),
      ('Address', 'address'),
      ('Registration Year', 'reg_year'),
      ("Father's Name", 'pat_fathers_name'),
      ("Mother's Name", 'pat_mothers_name'),
    ];
    Widget body;
    if (_error != null) {
      body = Center(
        child: InkWell(
          key: const Key('dy_patient_retry'),
          onTap: () => unawaited(_load()),
          child: Padding(
            padding: EdgeInsets.all(m.d(14)),
            child: Text(
              '$_error\nTap to retry',
              textAlign: TextAlign.center,
              style: m.text(
                8,
                weight: FontWeight.w500,
                color: DynamicRxColors.secondary,
              ),
            ),
          ),
        ),
      );
    } else if (_data == null) {
      body = const Center(
        child: CircularProgressIndicator(color: DynamicRxColors.primary),
      );
    } else {
      body = SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(m.d(10), m.d(8), m.d(10), m.d(10)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(m.d(8)),
            border: Border.all(color: DynamicRxColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final field in fields)
                if (dynamicRxText(_data![field.$2]).isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: m.d(10),
                      vertical: m.d(7),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          field.$1,
                          style: m.text(7, color: DynamicRxColors.secondary),
                        ),
                        SizedBox(height: m.d(1)),
                        Text(
                          dynamicRxText(_data![field.$2]),
                          style: m.text(9, weight: FontWeight.w500),
                        ),
                        SizedBox(height: m.d(6)),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: DynamicRxColors.outline,
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      );
    }
    return NativeDynamicPatientDetailsFrame(
      body: body,
      onChangePatient:
          widget.allowPatientChange ? () => Navigator.pop(context, true) : null,
    );
  }

  @override
  void dispose() {
    ++_request;
    super.dispose();
  }
}
