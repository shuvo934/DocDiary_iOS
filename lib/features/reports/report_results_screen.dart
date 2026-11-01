import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../auth/auth_controller.dart';
import '../auth/profile_repository.dart';
import 'native_report_controls.dart';
import 'native_report_table.dart';
import 'report_manager_menu.dart';
import 'report_manager_models.dart';
import 'report_manager_repository.dart';
import 'report_pdf_screen.dart';
import 'report_screen_state.dart';

class ReportResultsScreen extends StatefulWidget {
  const ReportResultsScreen({
    super.key,
    required this.auth,
    required this.repository,
    required this.request,
    required this.config,
  });
  final AuthController auth;
  final ReportManagerRepository repository;
  final ReportRequest request;
  final ReportServerConfig config;
  @override
  State<ReportResultsScreen> createState() => _ReportResultsState();
}

class _ReportResultsState extends ReportScreenState<ReportResultsScreen> {
  ReportTable? _table;
  @override
  AuthController get auth => widget.auth;
  @override
  ReportManagerRepository get repository => widget.repository;
  @override
  ReportManagerItem get item => widget.request.item;
  @override
  Future<void> loadReport(
    AccountProfile profile,
    bool Function() current,
  ) async {
    final table = await repository.table(
      session!,
      profile,
      widget.request,
      isCurrent: current,
    );
    if (current()) {
      setState(() {
        _table = table;
      });
    }
  }

  @override
  void clearReport() {
    _table = null;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && !dialogs.isOpen,
    child: NativeReportFrame(
      title: item.title,
      onClose: () => unawaited(closeReport()),
      action:
          session != null && reportHasPdf(session!.center.baseUri)
              ? TextButton(
                key: const Key('report_pdf_view'),
                onPressed:
                    ready && _table != null
                        ? () => unawaited(
                          openReport(
                            ReportPdfScreen(
                              auth: auth,
                              repository: repository,
                              request: widget.request,
                              config: widget.config,
                            ),
                          ),
                        )
                        : null,
                style: TextButton.styleFrom(
                  backgroundColor: DocColors.primary,
                  disabledBackgroundColor: const Color(0xffb2bec3),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'PDF VIEW',
                  style: reportText(
                    9,
                    reportScale(context),
                    family: 'PatuaOne',
                    color: Colors.white,
                  ),
                ),
              )
              : null,
      child:
          busy || !foreground || !current
              ? const Center(
                child: CircularProgressIndicator(key: Key('report_loading')),
              )
              : _table == null
              ? Center(child: Text(error ?? 'The report could not be loaded.'))
              : NativeReportTable(table: _table!, request: widget.request),
    ),
  );
}
