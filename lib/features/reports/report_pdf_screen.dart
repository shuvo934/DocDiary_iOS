import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/failure.dart';
import '../auth/auth_controller.dart';
import '../auth/profile_repository.dart';
import 'native_report_controls.dart';
import 'native_report_actions.dart';
import 'native_report_icons.dart';
import 'native_report_pdf_platform.dart';
import 'report_manager_menu.dart';
import 'report_manager_models.dart';
import 'report_manager_repository.dart';
import 'report_pdf_transport.dart';
import 'report_screen_state.dart';

class ReportPdfScreen extends StatefulWidget {
  const ReportPdfScreen({
    super.key,
    required this.auth,
    required this.repository,
    required this.request,
    required this.config,
    this.platform,
    this.transportFactory,
  });
  final AuthController auth;
  final ReportManagerRepository repository;
  final ReportRequest request;
  final ReportServerConfig config;
  final ReportPdfPlatform? platform;
  final ReportPdfTransport Function()? transportFactory;
  @override
  State<ReportPdfScreen> createState() => _ReportPdfState();
}

class _ReportPdfState extends ReportScreenState<ReportPdfScreen> {
  late final _platform = widget.platform ?? IosReportPdfPlatform();
  ReportPdfTransport? _download;
  Uint8List? _bytes;
  bool _pdfReady = false, _paging = false, _saving = false, _zooming = false;
  int _page = 0, _count = 0;
  @override
  AuthController get auth => widget.auth;
  @override
  ReportManagerRepository get repository => widget.repository;
  @override
  ReportManagerItem get item => widget.request.item;
  @override
  bool get isForegroundAction => _paging || _saving || _zooming;
  @override
  ReportTask get refreshOnResume => loadReport;
  bool get _active => ready && _pdfReady && !isForegroundAction;
  bool get _visible =>
      current && foreground && (ModalRoute.of(context)?.isCurrent ?? false);
  @override
  Future<void> loadReport(
    AccountProfile profile,
    bool Function() current,
  ) async {
    reportRequire(
      reportHasPdf(session!.center.baseUri),
      'PDF reports are not available for this centre.',
    );
    _download?.close();
    setState(() {
      _bytes = null;
      _pdfReady = false;
      _page = _count = 0;
    });
    final transport = widget.transportFactory?.call() ?? IoReportPdfTransport();
    _download = transport;
    final bytes = await transport.get(
      widget.config.url(widget.request),
      isCurrent: current,
    );
    repository.guard(session!, profile, item, current);
    validateReportPdf(bytes);
    if (current()) {
      setState(() {
        _bytes = bytes;
      });
    }
  }

  @override
  void clearReport() {
    _download?.close();
    _download = null;
    _bytes = null;
    _pdfReady = false;
    _page = _count = 0;
    unawaited(_platform.suspend());
  }

  @override
  void onReportBackground() => clearReport();
  Future<void> _pageTo(int index) async {
    if (!_active || index < 0 || index >= _count) return;
    setState(() {
      _paging = true;
    });
    final bytes = _bytes;
    try {
      final shown = await _platform.page(index);
      if (current && foreground && identical(bytes, _bytes)) {
        reportRequire(shown == index, 'The report page could not be opened.');
        setState(() {
          _page = index;
        });
      }
    } catch (_) {
      if (current && foreground && identical(bytes, _bytes)) {
        await runReportTask(
          loadReport,
          failure: const AppFailure(
            'The report page could not be opened. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _paging = false;
        });
      }
      if (_visible && _bytes == null && error == null) {
        unawaited(runReportTask(loadReport));
      }
    }
  }

  Future<void> _save() async {
    if (!_active) return;
    final confirmed = await dialogs.show<bool>(
      context,
      AlertDialog(
        key: const Key('report_download_confirmation'),
        title: const Text('Download Report!'),
        content: const Text('Do you want to download this report?'),
        actions: [
          TextButton(
            key: const Key('report_download_no'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
          TextButton(
            key: const Key('report_download_yes'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('YES'),
          ),
        ],
      ),
    );
    if (!_active || confirmed != true) return;
    setState(() {
      _saving = true;
    });
    try {
      await runReportTask((profile, current) async {
        final bytes = _bytes;
        reportRequire(
          bytes != null && _pdfReady,
          'Please reopen the report PDF.',
        );
        final bool saved;
        try {
          saved = await _platform.save();
        } catch (_) {
          throw const AppFailure(
            'Unable to save the report PDF. Please try again.',
          );
        }
        repository.guard(session!, profile, item, current);
        if (!mounted) return;
        if (current() && identical(bytes, _bytes) && saved) {
          toasts.show(context, 'Report saved.');
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
      if (_visible && _bytes == null && error == null) {
        unawaited(runReportTask(loadReport));
      }
    }
  }

  Future<void> _zoom(bool zoomIn) async {
    if (!_active) return;
    final bytes = _bytes;
    setState(() {
      _zooming = true;
    });
    try {
      await _platform.zoom(zoomIn);
    } catch (_) {
      if (current && foreground && identical(bytes, _bytes)) {
        await runReportTask(
          loadReport,
          failure: const AppFailure(
            'The report zoom could not be changed. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _zooming = false;
        });
      }
      if (_visible && _bytes == null && error == null) {
        unawaited(runReportTask(loadReport));
      }
    }
  }

  void _renderError(Uint8List bytes, String _) {
    if (!current || !foreground || !identical(bytes, _bytes)) return;
    setState(() {
      _bytes = null;
      _pdfReady = false;
    });
    unawaited(
      runReportTask(
        loadReport,
        failure: const AppFailure(
          'The report PDF could not be opened. Please try again.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _download?.close();
    _platform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes, scale = reportScale(context);
    Widget navigation(bool forward) => NativeReportPageButton(
      forward: forward,
      onPressed:
          _active && (forward ? _page + 1 < _count : _page > 0)
              ? () => unawaited(_pageTo(_page + (forward ? 1 : -1)))
              : null,
    );
    return PopScope(
      canPop: !busy && !isForegroundAction && !dialogs.isOpen,
      child: NativeReportFrame(
        title: item.title,
        onClose: () => unawaited(closeReport()),
        action: IconButton(
          key: const Key('report_pdf_download'),
          tooltip: 'Download report',
          onPressed: _active ? () => unawaited(_save()) : null,
          icon: NativeReportIcon(
            ReportGlyph.download,
            size: 18 * scale,
            color: _active ? DocColors.primary : const Color(0xffb2bec3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              if (bytes != null && current && foreground)
                Column(
                  children: [
                    Expanded(
                      child: _platform.buildView(
                        bytes: bytes,
                        documentName: widget.request.documentName,
                        onLoaded: (count) {
                          if (current &&
                              foreground &&
                              identical(bytes, _bytes)) {
                            setState(() {
                              _count = count;
                              _pdfReady = count > 0;
                            });
                          }
                        },
                        onError: (message) => _renderError(bytes, message),
                      ),
                    ),
                    if (_pdfReady)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 4 * scale),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            NativeReportZoomButton(
                              zoomIn: false,
                              onPressed:
                                  _active
                                      ? () => unawaited(_zoom(false))
                                      : null,
                            ),
                            const SizedBox(width: 12),
                            navigation(false),
                            const SizedBox(width: 8),
                            navigation(true),
                            const SizedBox(width: 12),
                            NativeReportZoomButton(
                              zoomIn: true,
                              onPressed:
                                  _active ? () => unawaited(_zoom(true)) : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              if (error != null)
                Center(child: Text(error!, textAlign: TextAlign.center))
              else if (busy || !_pdfReady || !foreground || !current || _paging)
                const Center(
                  child: CircularProgressIndicator(key: Key('report_loading')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
