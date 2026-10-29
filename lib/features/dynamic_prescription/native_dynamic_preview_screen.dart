import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_toast.dart';
import '../../core/failure.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'dynamic_prescription_preview_models.dart';
import 'dynamic_prescription_preview_repository.dart';
import 'native_dynamic_preview_html.dart';
import 'native_dynamic_preview_platform.dart';
import 'native_dynamic_builder_icons.dart';
import 'native_dynamic_rx_controls.dart';

/// PrescriptionPreview.java and activity_prescription_preview.xml, on iOS.
class NativeDynamicPreviewScreen extends StatefulWidget {
  const NativeDynamicPreviewScreen({
    super.key,
    required this.auth,
    required this.repository,
    required this.rvmId,
    this.platform,
  });
  final AuthController auth;
  final DynamicPrescriptionPreviewRepository repository;
  final String rvmId;
  final DynamicPreviewPlatform? platform;
  @override
  State<NativeDynamicPreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<NativeDynamicPreviewScreen>
    with WidgetsBindingObserver {
  late final _platform = widget.platform ?? IosDynamicPreviewPlatform();
  late final AuthSession? _session = widget.auth.session;
  final _toast = AppToastOwner();
  DynamicPrescriptionPreviewData? _data;
  String _html = '', _error = '', _actionError = '';
  bool _loading = true, _ready = false, _acting = false, _foreground = true;
  bool _needsRefresh = false;
  int _operation = 0;
  Timer? _renderTimeout;
  bool get _current =>
      mounted &&
      _session != null &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;
  bool _alive(int operation) =>
      _current && _foreground && operation == _operation;
  bool get _enabled =>
      _current &&
      _foreground &&
      _ready &&
      !_acting &&
      !_loading &&
      !_needsRefresh;
  String get _subtitle =>
      _error.isNotEmpty
          ? 'Unable to prepare preview'
          : _acting
          ? 'Preparing prescription PDF...'
          : _loading
          ? 'Preparing prescription...'
          : !_ready
          ? 'Preparing prescription layout...'
          : (_data?.rvmCode.isEmpty ?? true)
          ? 'Prescription preview ready'
          : 'Prescription No: ${_data!.rvmCode}';

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) unawaited(_load());
    });
  }

  void _authChanged() {
    if (_current) return;
    ++_operation;
    _renderTimeout?.cancel();
    _platform.dispose();
    if (mounted) {
      setState(() {
        _data = null;
        _html = '';
        _ready = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_foreground) {
        _foreground = true;
        if (_current && !_acting) unawaited(_load());
      }
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _needsRefresh = true;
      ++_operation;
      _renderTimeout?.cancel();
      unawaited(_platform.suspend());
      if (mounted) setState(() {});
    }
    // iOS system save/share/print sheets may make the app inactive; they keep
    // their owner until completion. A true background transition suspends it.
  }

  Future<void> _load() async {
    if (!_current || !_foreground || _acting) return;
    final operation = ++_operation;
    _renderTimeout?.cancel();
    setState(() {
      _loading = true;
      _ready = false;
      _error = '';
      _actionError = '';
      _html = '';
      _data = null;
      _needsRefresh = false;
    });
    try {
      final profile = await widget.auth.profiles.open(
        _session!,
        recordLogin: false,
        isCurrent: () => _alive(operation),
      );
      final data = await widget.repository.load(
        _session,
        profile,
        widget.rvmId,
        isCurrent: () => _alive(operation),
      );
      if (!_alive(operation)) return;
      final html = NativeDynamicPreviewHtml.build(data);
      setState(() {
        _data = data;
        _html = html;
        _loading = false;
      });
      _renderTimeout = Timer(const Duration(seconds: 30), () {
        if (_alive(operation) && !_ready) {
          _renderFailed(
            operation,
            'Prescription layout took too long to prepare. Please try again.',
          );
        }
      });
    } catch (error) {
      if (!_alive(operation)) return;
      if (error is AccountAccessFailure) {
        widget.auth.blockAccess(error);
        return;
      }
      setState(() {
        _loading = false;
        _error =
            error is AppFailure
                ? error.message
                : 'Prescription preview could not be loaded. Please try again.';
      });
    }
  }

  void _renderFailed(int operation, String message) {
    if (!_alive(operation)) return;
    _renderTimeout?.cancel();
    setState(() {
      _ready = false;
      _error = message;
      _html = '';
      _data = null;
    });
  }

  Future<void> _perform(DynamicPreviewAction action) async {
    if (!_enabled) return;
    final operation = _operation;
    setState(() {
      _acting = true;
      _actionError = '';
    });
    try {
      // Recheck current account access before exporting private patient data.
      final profile = await widget.auth.profiles.open(
        _session!,
        recordLogin: false,
        isCurrent: () => _alive(operation),
      );
      widget.repository.prescriptions.clinical.guard(
        _session,
        profile,
        () => _alive(operation),
      );
      final done = await _platform.perform(action);
      if (mounted &&
          _alive(operation) &&
          done &&
          action == DynamicPreviewAction.download) {
        _toast.show(context, 'Prescription PDF saved successfully.');
      }
    } catch (error) {
      if (!_alive(operation)) return;
      if (error is AccountAccessFailure) {
        widget.auth.blockAccess(error);
        return;
      }
      if (error is AppFailure && error.kind == FailureKind.denied) {
        _renderFailed(operation, error.message);
        return;
      }
      setState(() {
        _actionError =
            error is AppFailure
                ? error.message
                : error is PlatformException
                ? error.message ?? 'Prescription PDF action could not finish.'
                : 'Prescription PDF action could not finish. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _acting = false);
      if (_current && _foreground && _needsRefresh) unawaited(_load());
    }
  }

  void _back() {
    if (_acting) return;
    Navigator.of(context).pop();
  }

  Widget _errorCard(DynamicRxMetrics m) => Center(
    child: SingleChildScrollView(
      child: Container(
        key: const Key('dy_preview_error'),
        margin: EdgeInsets.all(m.d(12)),
        padding: EdgeInsets.all(m.d(14)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(m.d(10)),
          border: Border.all(color: const Color(0xfff4b4ae)),
          boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 4)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Preview could not be loaded',
              style: m.text(
                10,
                weight: FontWeight.w600,
                color: const Color(0xffb42318),
              ),
            ),
            SizedBox(height: m.d(5)),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: m.text(8, color: DynamicRxColors.secondary),
            ),
            SizedBox(height: m.d(10)),
            NativeDynamicRxButton(
              label: 'RETRY',
              onPressed:
                  _current && _foreground ? () => unawaited(_load()) : null,
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context);
    final operation = _operation;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: !_acting,
        child: Scaffold(
          key: const Key('dy_preview_screen'),
          backgroundColor: DynamicRxColors.header,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: m.d(5)),
                  child: Row(
                    children: [
                      SizedBox(width: m.d(4)),
                      IconButton(
                        key: const Key('dy_preview_back'),
                        onPressed: _acting ? null : _back,
                        icon: NativeDynamicBuilderIcon(
                          DynamicBuilderGlyph.back,
                          size: m.d(20),
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: m.d(4)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prescription Preview',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: m.text(
                                14,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: m.d(3)),
                            Text(
                              _subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: m.text(8, color: const Color(0xffdff4ed)),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: m.d(8)),
                    ],
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    color: const Color(0xffeef2f5),
                    child: Stack(
                      children: [
                        if (_current && _html.isNotEmpty && _error.isEmpty)
                          Positioned.fill(
                            child: Padding(
                              padding: EdgeInsets.all(m.d(4)),
                              child: KeyedSubtree(
                                key: ValueKey(operation),
                                child: _platform.buildView(
                                  html: _html,
                                  documentName: _data!.documentName,
                                  onReady: () {
                                    if (_alive(operation)) {
                                      _renderTimeout?.cancel();
                                      setState(() => _ready = true);
                                    }
                                  },
                                  onError:
                                      (message) =>
                                          _renderFailed(operation, message),
                                ),
                              ),
                            ),
                          ),
                        if (!_current || !_foreground || _needsRefresh)
                          const Positioned.fill(
                            child: ColoredBox(color: Color(0xffeef2f5)),
                          ),
                        if (_error.isNotEmpty)
                          Positioned.fill(child: _errorCard(m)),
                        if (_current &&
                            _foreground &&
                            (_loading || (!_ready && _error.isEmpty)))
                          Positioned.fill(
                            child: ColoredBox(
                              color: const Color(0xffeef2f5),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: m.d(36),
                                      height: m.d(36),
                                      child: const CircularProgressIndicator(
                                        key: Key('dy_preview_progress'),
                                        color: DynamicRxColors.primary,
                                      ),
                                    ),
                                    SizedBox(height: m.d(10)),
                                    Text(
                                      'Preparing prescription preview...',
                                      style: m.text(
                                        8,
                                        weight: FontWeight.w500,
                                        color: DynamicRxColors.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                ColoredBox(
                  color: Colors.white,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_actionError.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.all(m.d(8)),
                            child: Text(
                              _actionError,
                              key: const Key('dy_preview_action_error'),
                              textAlign: TextAlign.center,
                              style: m.text(8, color: const Color(0xffb42318)),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: m.d(8),
                            vertical: m.d(6),
                          ),
                          child: Row(
                            children: [
                              for (final action
                                  in DynamicPreviewAction.values) ...[
                                if (action != DynamicPreviewAction.download)
                                  SizedBox(width: m.d(5)),
                                Expanded(
                                  child: Opacity(
                                    opacity: _enabled ? 1 : .45,
                                    child: NativeDynamicRxButton(
                                      label: action.name.toUpperCase(),
                                      outlined:
                                          action != DynamicPreviewAction.share,
                                      onPressed:
                                          _enabled
                                              ? () =>
                                                  unawaited(_perform(action))
                                              : null,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
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

  @override
  void dispose() {
    ++_operation;
    _renderTimeout?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.auth.removeListener(_authChanged);
    _platform.dispose();
    _toast.dispose();
    super.dispose();
  }
}
