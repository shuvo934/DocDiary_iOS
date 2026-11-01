import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/failure.dart';
import '../auth/auth_controller.dart';
import '../auth/profile_repository.dart';
import 'native_report_controls.dart';
import 'report_manager_menu.dart';
import 'report_manager_models.dart';
import 'report_manager_repository.dart';
import 'report_pdf_screen.dart';
import 'report_results_screen.dart';
import 'report_screen_state.dart';

class ReportParametersScreen extends StatefulWidget {
  const ReportParametersScreen({
    super.key,
    required this.auth,
    required this.repository,
    required this.item,
  });
  final AuthController auth;
  final ReportManagerRepository repository;
  final ReportManagerItem item;
  @override
  State<ReportParametersScreen> createState() => _ReportParametersState();
}

class _ReportParametersState extends ReportScreenState<ReportParametersScreen> {
  @override
  AuthController get auth => widget.auth;
  @override
  ReportManagerRepository get repository => widget.repository;
  @override
  ReportManagerItem get item => widget.item;
  late final _draft = ReportParameterDraft(item, repository.now());
  ReportCatalogue? _catalogue;
  final _modified = <ReportParameter, List<ReportChoice>>{};
  @override
  Future<void> loadReport(
    AccountProfile profile,
    bool Function() current,
  ) async {
    final catalogue = await repository.catalogue(
      session!,
      profile,
      item,
      isCurrent: current,
    );
    if (current()) {
      setState(() {
        _catalogue = catalogue;
      });
    }
  }

  @override
  void clearReport() {
    _catalogue = null;
    _modified.clear();
  }

  List<ReportChoice> _choices(ReportParameter p) => switch (p) {
    ReportParameter.department => _catalogue?.departments ?? const [],
    ReportParameter.unit =>
      _draft.department == null
          ? _catalogue?.units ?? const []
          : _modified[p] ?? const [],
    ReportParameter.service =>
      _draft.unit == null
          ? _catalogue?.services ?? const []
          : _modified[p] ?? const [],
    ReportParameter.doctor => _modified[p] ?? const [],
  };
  Future<void> _select(ReportParameter parameter) async {
    if (!ready || !_draft.enabled(parameter)) return;
    if (parameter == ReportParameter.doctor && _draft.unit == null) return;
    final choices = _choices(parameter);
    final choice = await dialogs.show<ReportChoice>(
      context,
      NativeReportParameterDialog(parameter: parameter, choices: choices),
    );
    if (!ready || choice == null || !choices.contains(choice)) return;
    ReportParameter? next;
    setState(() {
      next = _draft.choose(parameter, choice);
      if (parameter == ReportParameter.department) _modified.clear();
      if (parameter == ReportParameter.unit) {
        _modified.remove(ReportParameter.doctor);
        _modified.remove(ReportParameter.service);
      }
      if (parameter == ReportParameter.doctor) {
        _modified.remove(ReportParameter.service);
      }
    });
    if (next == null) return;
    final target = next!,
        parent =
            next == ReportParameter.unit
                ? _draft.department?.id ?? ''
                : _draft.unit?.id ?? '';
    await runReportTask((profile, current) async {
      final rows = await repository.choices(
        session!,
        profile,
        item,
        target,
        parentId: parent,
        isCurrent: current,
      );
      if (current()) {
        setState(() {
          _modified[target] = rows;
          _draft.loaded(target);
        });
      }
    });
  }

  Future<void> _date(bool first) async {
    if (!ready) return;
    final today = repository.now();
    final picked = await dialogs.show<DateTime>(
      context,
      DatePickerDialog(
        initialDate: (first ? _draft.begin : _draft.end) ?? today,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100, 12, 31),
        currentDate: today,
      ),
    );
    if (ready && picked != null) {
      setState(() {
        _draft.chooseDate(first, picked);
      });
    }
  }

  Future<void> _show() async {
    if (!ready || _catalogue == null) return;
    try {
      final request = _draft.snapshot(), config = _catalogue!.pdf;
      await openReport(
        item.directPdf
            ? ReportPdfScreen(
              auth: auth,
              repository: repository,
              request: request,
              config: config,
            )
            : ReportResultsScreen(
              auth: auth,
              repository: repository,
              request: request,
              config: config,
            ),
      );
    } on AppFailure catch (failure) {
      if (mounted && ready) toasts.show(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = reportScale(context),
        waiting = busy || !foreground || !current;
    Widget field(ReportParameter p) {
      final value = _draft.selected(p);
      return NativeReportFilterField(
        key: Key('report_filter_${p.name}'),
        label: value == null ? 'Select ${p.label}' : p.label,
        value: value?.name ?? '',
        enabled: _draft.enabled(p),
        onTap: ready ? () => unawaited(_select(p)) : null,
      );
    }

    return PopScope(
      canPop: !busy && !dialogs.isOpen,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && busy) toasts.show(context, 'Please wait while loading');
      },
      child: NativeReportFrame(
        title: item.title,
        parameterHeader: true,
        onClose: () => unawaited(closeReport()),
        child:
            waiting
                ? const Center(
                  child: CircularProgressIndicator(key: Key('report_loading')),
                )
                : error != null
                ? Center(child: Text(error!, textAlign: TextAlign.center))
                : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        key: const Key('report_parameter_scroll'),
                        padding: EdgeInsets.fromLTRB(
                          4 * scale,
                          8 * scale,
                          4 * scale,
                          4 * scale,
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: NativeReportFilterField(
                                    key: const Key('report_begin'),
                                    label: 'Begin Date',
                                    value: _draft.dateText(true),
                                    calendar: true,
                                    onTap:
                                        ready
                                            ? () => unawaited(_date(true))
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: NativeReportFilterField(
                                    key: const Key('report_end'),
                                    label: 'End Date',
                                    value: _draft.dateText(false),
                                    calendar: true,
                                    onTap:
                                        ready
                                            ? () => unawaited(_date(false))
                                            : null,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4 * scale),
                            if (_draft.invalidRange)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 5),
                                child: Text(
                                  'Date Range is Invalid',
                                  key: Key('report_date_invalid'),
                                  style: TextStyle(
                                    color: Color(0xffff4444),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: field(ReportParameter.department),
                                ),
                                const SizedBox(width: 5),
                                Expanded(child: field(ReportParameter.unit)),
                              ],
                            ),
                            if (item.showsDoctor)
                              Padding(
                                padding: EdgeInsets.only(top: 4 * scale),
                                child: field(ReportParameter.doctor),
                              ),
                            if (item.showsService)
                              Padding(
                                padding: EdgeInsets.only(top: 4 * scale),
                                child: field(ReportParameter.service),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8 * scale),
                      child: NativeReportGradientButton(
                        key: const Key('report_show'),
                        label: 'SHOW',
                        onPressed: ready ? () => unawaited(_show()) : null,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
