import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../dashboard/native_dashboard_dialogs.dart';
import '../voucher_transaction/native_voucher_controls.dart';
import 'native_voucher_approval_layout.dart';
import 'voucher_approval_models.dart';

class NativeVoucherPicker extends StatefulWidget {
  const NativeVoucherPicker({
    super.key,
    required this.kind,
    required this.prefix,
    required this.state,
    required this.onSearch,
    required this.onClear,
  });
  final VoucherApprovalKind kind;
  final String prefix;
  final ValueListenable<VoucherPickerData> state;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  @override
  State<NativeVoucherPicker> createState() => _PickerState();
}

class _PickerState extends State<NativeVoucherPicker> {
  final _text = TextEditingController();
  String? _validation;
  void _search() {
    if (widget.state.value.busy) return;
    final validation = validateVoucherQuery(_text.text, widget.prefix);
    setState(() => _validation = validation);
    if (validation != null) return;
    FocusScope.of(context).unfocus();
    widget.onSearch(_text.text);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context),
        media = MediaQuery.of(context),
        maxHeight = math.max(
          120.0,
          media.size.height -
              media.padding.vertical -
              media.viewInsets.bottom -
              48,
        );
    return Dialog(
      key: const Key('va_picker'),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      child: SizedBox(
        width: math.min(560, media.size.width - 48),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ValueListenableBuilder<VoucherPickerData>(
            valueListenable: widget.state,
            builder:
                (context, data, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ColoredBox(
                      color: DocColors.primary,
                      child: Padding(
                        padding: EdgeInsets.all(8 * s),
                        child: Text(
                          'Select Voucher No:',
                          style: vtText(
                            13,
                            s,
                            family: 'RussoOne',
                            color: Colors.white,
                            weight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(5, 10, 5, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Material(
                                    color: vtDisabled,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(
                                        color: DocColors.primary,
                                      ),
                                    ),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minHeight: 56,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 16,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        widget.prefix,
                                        key: const Key('va_prefix'),
                                        textAlign: TextAlign.center,
                                        style: vtText(
                                          10,
                                          s,
                                          family: 'Ubuntu',
                                          color: vtCloud,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 5,
                                  child: Material(
                                    color: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(
                                        color: DocColors.primary,
                                      ),
                                    ),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 56,
                                      ),
                                      child: TextField(
                                        key: const Key('va_query'),
                                        controller: _text,
                                        enabled: !data.busy,
                                        textInputAction: TextInputAction.done,
                                        onSubmitted:
                                            (_) =>
                                                FocusScope.of(
                                                  context,
                                                ).unfocus(),
                                        style: vtText(
                                          10,
                                          s,
                                          family: 'Poppins',
                                          weight: FontWeight.w500,
                                        ),
                                        onChanged:
                                            (v) => setState(
                                              () =>
                                                  _validation =
                                                      v.startsWith('.')
                                                          ? "Invalid Character. Code should not start with '.'"
                                                          : null,
                                            ),
                                        decoration: InputDecoration(
                                          labelText: 'Write Voucher No',
                                          labelStyle: vtText(
                                            10,
                                            s,
                                            family: 'Poppins',
                                            color: const Color(0xffb2bec3),
                                            weight: FontWeight.w600,
                                          ),
                                          floatingLabelStyle: vtText(
                                            11,
                                            s,
                                            family: 'Poppins',
                                            color: const Color(0xffb2bec3),
                                            weight: FontWeight.w600,
                                          ),
                                          filled: false,
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 16,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 54,
                                  height: 56,
                                  child: ApprovalButton(
                                    key: const Key('va_search'),
                                    label: 'Search',
                                    onPressed: data.busy ? null : _search,
                                    child: Icon(
                                      Icons.search,
                                      size: 21 * s,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_validation != null)
                              Padding(
                                padding: const EdgeInsets.all(7),
                                child: Text(
                                  _validation!,
                                  key: const Key('va_validation'),
                                  style: vtText(10, s, color: Colors.red),
                                ),
                              ),
                            const SizedBox(height: 16),
                            if (data.searched)
                              // Align(
                              //   alignment: Alignment.centerRight,
                              //   child: SizedBox(
                              //     width: 84,
                              //     child: ApprovalButton(
                              //       key: const Key('va_clear'),
                              //       label: 'CLEAR',
                              //       onPressed:
                              //           data.busy
                              //               ? null
                              //               : () {
                              //                 _text.clear();
                              //                 setState(
                              //                   () => _validation = null,
                              //                 );
                              //                 widget.onClear();
                              //               },
                              //     ),
                              //   ),
                              // )
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4 * s,
                                  ),
                                  child: TextButton(
                                    key: const Key('va_clear'),
                                    onPressed:
                                        data.busy
                                            ? null
                                            : () {
                                              _text.clear();
                                              setState(
                                                () => _validation = null,
                                              );
                                              widget.onClear();
                                            },
                                    style: TextButton.styleFrom(
                                      backgroundColor: DocColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 18,
                                      ),
                                      shape: const StadiumBorder(),
                                    ),
                                    child: Text(
                                      'CLEAR',
                                      style: adminAppointmentText(
                                        10,
                                        s,
                                        family: 'PatuaOne',
                                        color: Colors.white,
                                        weight: FontWeight.bold,
                                      ).copyWith(letterSpacing: 0.8),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Text(
                                  'Latest 100 ${widget.kind.code} Voucher',
                                  key: const Key('va_latest'),
                                  style: vtText(
                                    12,
                                    s,
                                    family: 'Poppins',
                                    color: DocColors.primary,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            if (data.busy)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    key: Key('va_search_loading'),
                                  ),
                                ),
                              )
                            else if (data.failure != null)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Text(
                                      dashboardErrorMessage(data.failure!),
                                      key: const Key('va_search_error'),
                                      textAlign: TextAlign.center,
                                      style: vtText(9, s),
                                    ),
                                    TextButton(
                                      key: const Key('va_search_retry'),
                                      onPressed: _search,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            else
                              _table(
                                context,
                                data,
                                math.max(60, maxHeight - 230 * s),
                                s,
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const Key('va_picker_cancel'),
                          onPressed:
                              data.busy ? null : () => Navigator.pop(context),
                          child: Text(
                            'CANCEL',
                            style: vtText(
                              11,
                              s,
                              family: 'Poppins',
                              color: DocColors.primary,
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

  Widget _table(
    BuildContext context,
    VoucherPickerData data,
    double maxBody,
    double s,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final widths =
              [
                25,
                15,
                43,
                17,
              ].map((f) => (constraints.maxWidth - 12) * f / 100).toList(),
          header = vtText(9, s, family: 'PatuaOne', color: Colors.white),
          body = vtText(8, s, family: 'OpenSans');
      List<String> values(ApprovalVoucher v) => [
        v.number,
        v.value('vm_date'),
        v.value('vm_naration'),
        v.status,
      ];
      double height(List<String> texts, TextStyle style) => List.generate(
        4,
        (i) => voucherTextHeight(
          context,
          texts[i],
          widths[i],
          style,
          vertical: 8,
          minimum: 24,
        ),
      ).reduce(math.max);
      final heights = data.rows.map((v) => height(values(v), body)).toList(),
          bodyHeight = heights.fold(0.0, (sum, h) => sum + h + 3);
      Widget strip(
        List<String> texts,
        TextStyle style,
        Color fill,
        double h, {
        ApprovalVoucher? voucher,
      }) => Material(
        color: Colors.white,
        child: InkWell(
          key: voucher == null ? null : Key('va_choice_${voucher.id}'),
          onTap: voucher == null ? null : () => Navigator.pop(context, voucher),
          child: Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Container(
                  width: widths[i],
                  height: h,
                  color: fill,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    texts[i],
                    textAlign: TextAlign.center,
                    style:
                        i == 3 && voucher != null
                            ? style.copyWith(
                              color:
                                  voucher.approved
                                      ? DocColors.greenSea
                                      : approvalPending,
                            )
                            : style,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
      final headings = ['Voucher No', 'Date', 'Narration', 'Status'];
      return Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            strip(
              headings,
              header,
              DocColors.primary,
              height(headings, header),
            ),
            if (data.rows.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12 * s),
                child: Text(
                  'No Voucher List Found',
                  key: const Key('va_picker_empty'),
                  style: vtText(12, s, family: 'Poppins'),
                  textAlign: TextAlign.center,
                ),
              )
            else
              SizedBox(
                height: math.min(maxBody, bodyHeight),
                child: ListView.builder(
                  key: const Key('va_choices'),
                  padding: EdgeInsets.zero,
                  itemCount: data.rows.length,
                  itemBuilder:
                      (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: strip(
                          values(data.rows[i]),
                          body,
                          DocColors.clouds,
                          heights[i],
                          voucher: data.rows[i],
                        ),
                      ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
