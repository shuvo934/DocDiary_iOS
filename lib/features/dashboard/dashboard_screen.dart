import '../patient_search/normal_patient_search_screen.dart';
import '../patient_search/patient_search_screen.dart';
import '../patient_search/patient_search_repository.dart';
import '../patient_search/admin_patient_search_screen.dart';
import '../patient_search/admin_patient_search_repository.dart';
import '../prescription/normal_prescription_repository.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/app_toast.dart';

import '../../core/failure.dart';
import '../../core/native_dates.dart';
import '../auth/auth_controller.dart';
import '../auth/account_access.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import 'admin_chart_repository.dart';
import 'native_admin_overview.dart';
import 'dashboard_repository.dart';
import 'meeting_countdown.dart';
import 'native_dashboard_layout.dart';
import 'native_dashboard_dialogs.dart';
import 'dashboard_photo_repository.dart';
import 'dashboard_services.dart';
import 'native_camera_screen.dart';
import 'native_photo_dialogs.dart';
import 'dashboard_navigation.dart';
import '../profile/doctor_profile_repository.dart';
import '../profile/doctor_profile_screen.dart';
import '../block_time/doctor_block_time_repository.dart';
import '../block_time/doctor_block_time_screen.dart';
import '../appointments/doctor_schedule/doctor_appointment_repository.dart';
import '../appointments/doctor_schedule/doctor_appointment_screen.dart';
import '../management/management_menu_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.services = const DashboardServices(),
  });
  final AuthController auth;
  final DashboardRepository repository;
  final DashboardServices services;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final _toasts = AppToastOwner();
  late AccountProfile _profile;
  late final AuthSession _session;
  DashboardSummary? _summary;
  Uint8List? _picture;
  SummaryPeriod _period = SummaryPeriod.today;
  String? _error;
  bool _loading = false;
  bool _noticeOpen = false;
  bool _navigationAway = false;
  final _dialogs = NativeDashboardDialogOwner();
  Object? _fullFailure;
  bool _waitingAdmin = false;
  bool _holdAdminCharts = false;
  bool _warningShown = false;
  int _dialogRevision = 0;
  Future<void> Function()? _retryLoad;
  int _request = 0;
  int _overviewRevision = 0;
  MeetingTimeline? _meeting;
  MeetingSnapshot? _countdown;
  Timer? _meetingTicker;
  Timer? _expiryRefresh;
  DateTime? _expiryRefreshAt;
  bool _foreground = true;
  bool _expiryDue = false;
  bool _resumePending = false;
  bool _meetingRefreshing = false;
  bool _photoBusy = false;
  bool _photoUploading = false;
  bool _photoBackgrounded = false;
  bool _photoReloadNeeded = false;
  int _photoOperation = 0;
  Completer<void>? _photoResume;
  bool _hasFullSuccess = false;
  bool _reviewPending = false;
  bool _reviewAttempted = false;

  bool get _current =>
      mounted &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;

  @override
  void initState() {
    super.initState();
    _profile = widget.auth.profile!;
    _session = widget.auth.session!;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.auth.addListener(_authChanged);
    // Re-read access without login mutations, including a return from cancelled
    // account selection where the server may have changed the old account.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_load(refreshPicture: true));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_navigationAway) {
      _foreground = state == AppLifecycleState.resumed;
      if (!_foreground) {
        ++_request;
        _stopMeetingClock();
      }
      return;
    }
    if (_photoBusy) {
      _foreground = state == AppLifecycleState.resumed;
      if (_foreground) {
        _wakePhoto();
      } else {
        _photoBackgrounded = true;
      }
      // Camera, photo picker, cropper and permissions temporarily deactivate
      // the app. Their return cannot start a competing dashboard reload.
      return;
    }
    if (state != AppLifecycleState.resumed) {
      _foreground = false;
      _resumePending = false;
      ++_request;
      ++_dialogRevision;
      _loading = false;
      _waitingAdmin = false;
      _dialogs.close();
      _stopMeetingClock();
      return;
    }
    if (_foreground) {
      return;
    }
    _foreground = true;
    if (_current) {
      if (_fullFailure != null) {
        _queueFullError();
      } else {
        _resumePending = true;
        _reloadOnResume();
      }
    }
  }

  void _authChanged() {
    if (!_current) {
      _toasts.clear();
      ++_photoOperation;
      _wakePhoto();
      ++_request;
      ++_dialogRevision;
      _resumePending = false;
      _dialogs.close();
      _stopMeetingClock();
    }
  }

  void _cancelExpiryRefresh() {
    _expiryRefresh?.cancel();
    _expiryRefresh = null;
    _expiryRefreshAt = null;
    _expiryDue = false;
  }

  void _stopMeetingClock() {
    _meetingTicker?.cancel();
    _meetingTicker = null;
    _cancelExpiryRefresh();
  }

  void _adoptMeeting(DashboardSummary result) {
    final previous = _meeting;
    _meeting =
        _profile.isDoctor
            ? MeetingTimeline.update(
              lastTime: result.lastTime,
              nextTime: result.nextTime,
              observedAt: widget.repository.now(),
              previous: previous,
            )
            : null;
    _startMeetingClock();
  }

  void _startMeetingClock() {
    _meetingTicker?.cancel();
    _meetingTicker = null;
    _countdown = _meeting?.at(widget.repository.now());
    // Once time is up, finish the native Today refresh even if a tab request
    // returns first. Its week/month counts cannot be relabelled as Today.
    if (_expiryRefreshAt != null || _expiryDue) {
      _meetingRefreshing = true;
      return;
    }
    _meetingRefreshing = false;
    if (!_current || !_foreground || _error != null) {
      return;
    }
    final meeting = _meeting;
    if (meeting == null) {
      _cancelExpiryRefresh();
      return;
    }
    if (_countdown!.expired) {
      _meetingRefreshing = true;
      _scheduleExpiryRefresh();
      return;
    }
    _cancelExpiryRefresh();
    _meetingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_current || !_foreground) {
        _stopMeetingClock();
        return;
      }
      setState(() {
        _countdown = meeting.at(widget.repository.now());
        if (_countdown!.expired) {
          _meetingTicker?.cancel();
          _meetingTicker = null;
          // Android hides the dashboard/navigation and shows its main spinner
          // during the 3-second delay and the subsequent schedule request.
          _meetingRefreshing = true;
          _scheduleExpiryRefresh();
        }
      });
    });
  }

  void _scheduleExpiryRefresh() {
    if (_expiryDue || _expiryRefresh?.isActive == true) {
      return;
    }
    _expiryRefreshAt ??= widget.repository.now().add(
      const Duration(seconds: 3),
    );
    final delay = _expiryRefreshAt!.difference(widget.repository.now());
    _expiryRefresh = Timer(delay.isNegative ? Duration.zero : delay, () {
      _expiryRefresh = null;
      if (!_current || !_foreground) {
        return;
      }
      if (_loading) {
        // A tab/pull request already owns the connection. Drain one queued
        // Today refresh after it finishes, without overlapping requests.
        _expiryDue = true;
        return;
      }
      _reloadAfterMeeting();
    });
  }

  void _reloadAfterMeeting() {
    _cancelExpiryRefresh();
    setState(() => _period = SummaryPeriod.today);
    unawaited(_load(revalidate: false, refreshPicture: true));
  }

  void _reloadOnResume() {
    _resumePending = false;
    _stopMeetingClock();
    setState(() {
      _period = SummaryPeriod.today;
      _countdown = _meeting?.at(widget.repository.now());
      _meetingRefreshing = _profile.isDoctor && _summary != null;
    });
    // Revalidate without inserting a second login log or changing login flags.
    unawaited(_load(refreshPicture: true));
  }

  void _deny(AppFailure failure) {
    _stopMeetingClock();
    _dialogs.close();
    widget.auth.blockAccess(
      failure is AccountAccessFailure
          ? failure
          : AccountAccessFailure(
            AccountAccessReason.mobileAccess,
            failure.message,
          ),
    );
  }

  Future<void> _load({
    bool revalidate = true,
    bool refreshPicture = false,
    bool tabOnly = false,
  }) async {
    if (!_current || !_foreground || _loading || _waitingAdmin || _photoBusy) {
      return;
    }
    final session = widget.auth.session;
    if (session == null) {
      return;
    }
    final request = ++_request;
    final period = _period;
    var checkingProfile = revalidate;
    bool current() =>
        _current &&
        _foreground &&
        request == _request &&
        widget.auth.session == session;
    setState(() {
      _loading = true;
      _error = null;
      _fullFailure = null;
      if (!tabOnly) {
        _summary = null;
        _holdAdminCharts = true;
        _stopMeetingClock();
      }
    });
    try {
      final profile =
          revalidate
              ? await widget.auth.profiles.open(
                session,
                recordLogin: false,
                isCurrent: current,
              )
              : _profile;
      if (!current()) {
        return;
      }
      checkingProfile = false;
      _profile = profile;
      final result = await widget.repository.load(
        session,
        profile,
        period,
        isCurrent: current,
      );
      if (!current()) {
        return;
      }
      // Native full-load errors include the picture request. A successful empty
      // picture response uses the role placeholder; a failed request is Retry.
      final picture =
          refreshPicture
              ? await widget.repository.loadPicture(session, profile)
              : _picture;
      if (!current()) {
        return;
      }
      ProfileRepository.checkAccess(profile, widget.repository.now());
      setState(() {
        _profile = profile;
        _summary = result;
        _picture = picture;
        _holdAdminCharts = false;
        _waitingAdmin = !tabOnly && !profile.isDoctor;
        if (refreshPicture) {
          ++_overviewRevision;
        }
        _adoptMeeting(result);
      });
      if (profile.isDoctor) {
        if (!tabOnly) {
          _fullSuccess();
        }
      }
    } catch (failure) {
      if (!current()) {
        return;
      }
      if (failure is AppFailure && failure.kind == FailureKind.denied) {
        _deny(failure);
        return;
      }
      _stopMeetingClock();
      setState(() {
        _error = dashboardFailureDetail(failure);
        _waitingAdmin = false;
        _meetingRefreshing = false;
        if (!tabOnly) {
          _fullFailure = failure;
        }
      });
      final retryProfile = checkingProfile;
      _retryLoad =
          () => _load(
            revalidate: retryProfile,
            refreshPicture: refreshPicture,
            tabOnly: tabOnly,
          );
      if (tabOnly) {
        _queueTabError(failure);
      } else {
        _queueFullError();
      }
    } finally {
      if (current()) {
        setState(() {
          _loading = false;
          if (_error != null) {
            _stopMeetingClock();
            _meetingRefreshing = false;
          }
        });
        if (_foreground && _resumePending) {
          _reloadOnResume();
        } else if (_foreground && _expiryDue) {
          _reloadAfterMeeting();
        }
      }
    }
  }

  void _adminReady() {
    if (!_current || !_foreground) {
      return;
    }
    setState(() => _waitingAdmin = false);
    _fullSuccess();
  }

  void _adminFailed(Object failure) {
    if (!_current || !_foreground) {
      return;
    }
    if (failure is AppFailure && failure.kind == FailureKind.denied) {
      _deny(failure);
      return;
    }
    setState(() {
      _waitingAdmin = false;
      _fullFailure = failure;
      _error = dashboardFailureDetail(failure);
    });
    _retryLoad = () async {
      await _load(refreshPicture: true);
    };
    _queueFullError();
  }

  void _fullSuccess() {
    final returning = _hasFullSuccess;
    _hasFullSuccess = true;
    _showExpiryWarning();
    if (!returning || _reviewPending || _reviewAttempted) {
      return;
    }
    final request = _request;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current &&
          _foreground &&
          request == _request &&
          !_dialogs.isOpen &&
          !_photoBusy &&
          !_reviewAttempted &&
          _error == null &&
          !_waitingAdmin &&
          !_reviewPending) {
        unawaited(_requestReview());
      }
    });
  }

  Future<void> _requestReview() async {
    _reviewAttempted = true;
    _reviewPending = true;
    try {
      await widget.services.review.request();
    } catch (_) {
      // Rating is optional, as in the native task-completion listener.
    } finally {
      _reviewPending = false;
    }
  }

  void _showExpiryWarning() {
    if (!_current || !_foreground || _warningShown || _dialogs.isOpen) {
      return;
    }
    // first_flag=1 in the native dashboard after its first complete success.
    final warning = AccountExpiryWarning.forDate(
      _profile.expiryDate,
      widget.repository.now(),
    );
    if (warning == null) {
      _warningShown = true;
      return;
    }
    final request = _request;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current &&
          _foreground &&
          request == _request &&
          !_warningShown &&
          _fullFailure == null &&
          !_dialogs.isOpen) {
        _warningShown = true;
        unawaited(
          _dialogs.show<bool>(
            context,
            NativeDashboardMessageDialog(
              title: warning.title,
              message: warning.message,
            ),
            dismissible: true,
          ),
        );
      }
    });
  }

  void _queueTabError(Object failure) {
    final revision = ++_dialogRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground && revision == _dialogRevision) {
        unawaited(
          _dialogs.show<bool>(
            context,
            NativeDashboardMessageDialog(
              title: 'Error!',
              message: dashboardErrorMessage(failure),
            ),
          ),
        );
      }
    });
  }

  void _queueFullError() {
    final revision = ++_dialogRevision;
    _dialogs.close();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current &&
          _foreground &&
          revision == _dialogRevision &&
          _fullFailure != null) {
        unawaited(_presentFullError(revision));
      }
    });
  }

  Future<void> _presentFullError(int revision) async {
    bool current() =>
        _current &&
        _foreground &&
        revision == _dialogRevision &&
        _fullFailure != null;
    while (current()) {
      if (!mounted) {
        return;
      }
      final choice = await _dialogs.show<DashboardErrorChoice>(
        context,
        NativeDashboardErrorDialog(failure: _fullFailure!),
      );
      if (!current() || choice == null) {
        return;
      }
      switch (choice) {
        case DashboardErrorChoice.logOut:
          await widget.auth.logout();
          return;
        case DashboardErrorChoice.retry:
          final retry = _retryLoad;
          if (retry != null) {
            await retry();
          }
          return;
        case DashboardErrorChoice.exit:
          if (!mounted) {
            return;
          }
          await _dialogs.show<bool>(context, nativeDashboardExitHelp);
      }
    }
  }

  Future<void> _refresh() async {
    if (!_current || !_foreground || _loading || _waitingAdmin || _photoBusy) {
      return;
    }
    if (_error != null && _retryLoad != null) {
      await _retryLoad!();
      return;
    }
    setState(() => _period = SummaryPeriod.today);
    await _load(refreshPicture: true);
  }

  Future<void> _selectPeriod(SummaryPeriod period) async {
    if (!_current ||
        _loading ||
        _waitingAdmin ||
        _photoBusy ||
        period == _period) {
      return;
    }
    setState(() => _period = period);
    await _load(tabOnly: true);
  }

  Future<void> _logout() async {
    if (!_current || _dialogs.isOpen || _photoBusy) {
      return;
    }
    final confirmed = await _dialogs.show<bool>(
      context,
      const NativeDashboardConfirmDialog(
        title: 'Log Out!',
        message: 'Do you want to log out?',
      ),
      dismissible: true,
    );
    if (confirmed == true && _current) {
      await widget.auth.logout();
    }
    if (confirmed != true && _current && _foreground && _summary != null) {
      _showExpiryWarning();
    }
  }

  Future<void> _confirmExit() async {
    if (!_current || _dialogs.isOpen || _photoBusy) {
      return;
    }
    final confirmed = await _dialogs.show<bool>(
      context,
      const NativeDashboardConfirmDialog(
        title: 'Exit!',
        message: 'Do you want to exit?',
      ),
      dismissible: true,
    );
    if (confirmed == true && mounted && _current) {
      await _dialogs.show<bool>(context, nativeDashboardExitHelp);
    }
    if (_current && _foreground && _summary != null) {
      _showExpiryWarning();
    }
  }

  Future<void> _openDestination(DashboardDestination destination) async {
    if (!_current ||
        _loading ||
        _waitingAdmin ||
        _photoBusy ||
        _noticeOpen ||
        _dialogs.isOpen) {
      return;
    }
    if (destination == DashboardDestination.changePhoto) {
      await _changePhoto();
      return;
    }
    final route = nativeDashboardRoute(_profile, destination);
    if (route == null) {
      return;
    }
    final page =
        widget.services.destinationBuilder?.call(context, route) ??
        (route.module == DashboardModule.doctorProfile
            ? DoctorProfileScreen(
              auth: widget.auth,
              repository: DoctorProfileRepository(
                widget.repository.transport,
                now: widget.repository.now,
              ),
              media: widget.services.media,
            )
            : route.module == DashboardModule.doctorAppointments
            ? DoctorAppointmentScreen(
              auth: widget.auth,
              repository: DoctorAppointmentRepository(
                widget.repository.transport,
                now: widget.repository.now,
              ),
              destinationBuilder: widget.services.destinationBuilder,
            )
            : route.module == DashboardModule.patientSearch
            ? NormalPatientSearchScreen(
              auth: widget.auth,
              destinationBuilder: widget.services.destinationBuilder,
              repository: NormalPrescriptionRepository(
                DoctorAppointmentRepository(
                  widget.repository.transport,
                  now: widget.repository.now,
                ),
              ),
            )
            : route.module == DashboardModule.patientSearchPrescription
            ? PatientSearchScreen(
              auth: widget.auth,
              repository: PatientSearchRepository(
                DoctorAppointmentRepository(
                  widget.repository.transport,
                  now: widget.repository.now,
                ),
              ),
              destinationBuilder: widget.services.destinationBuilder,
            )
            : route.module == DashboardModule.adminPatients
            ? AdminPatientSearchScreen(
              auth: widget.auth,
              repository: AdminPatientSearchRepository(
                DoctorAppointmentRepository(
                  widget.repository.transport,
                  now: widget.repository.now,
                ),
              ),
              destinationBuilder: widget.services.destinationBuilder,
            )
            : route.module == DashboardModule.doctorBlockTime
            ? DoctorBlockTimeScreen(
              auth: widget.auth,
              repository: DoctorBlockTimeRepository(
                widget.repository.transport,
                now: widget.repository.now,
              ),
            )
            : route.module == DashboardModule.hrAccounts ||
                route.module == DashboardModule.reports
            ? ManagementMenuScreen(
              auth: widget.auth,
              entry:
                  route.module == DashboardModule.hrAccounts
                      ? ManagementEntry.portal
                      : ManagementEntry.reports,
              destinationBuilder: widget.services.destinationBuilder,
            )
            : null);
    if (page != null) {
      _noticeOpen = true;
      _navigationAway = true;
      _stopMeetingClock();
      try {
        await _dialogs.push<void>(context, page);
      } finally {
        _noticeOpen = false;
        _navigationAway = false;
        if (_current && _foreground) {
          // Flutter routes do not trigger Android Activity.onResume. Explicitly
          // refresh on return so the new appointment/profile data becomes live.
          setState(() => _period = SummaryPeriod.today);
          await _load(refreshPicture: true);
        }
      }
      return;
    }
    _noticeOpen = true;
    final label = switch (destination) {
      DashboardDestination.profile => 'Profile',
      DashboardDestination.appointment => 'Appointment',
      DashboardDestination.leave => 'Block Time',
      DashboardDestination.patients => 'Patient',
      DashboardDestination.payment => 'Payment',
      DashboardDestination.management =>
        nativeDashboardMenu(
          _profile,
        ).firstWhere((item) => item.destination == destination).label,
      DashboardDestination.unitAppointment => 'Unit Appointment',
      DashboardDestination.allAppointment => 'All Appointment',
      DashboardDestination.reports => 'Report Manager',
      DashboardDestination.changePhoto => 'Profile picture',
    };
    try {
      await _dialogs.show<bool>(
        context,
        AlertDialog(
          title: Text(label),
          content: const Text(
            'This screen is not available in this development build.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
        dismissible: true,
      );
    } finally {
      _noticeOpen = false;
    }
  }

  void _wakePhoto() {
    final waiting = _photoResume;
    _photoResume = null;
    if (waiting != null && !waiting.isCompleted) {
      waiting.complete();
    }
  }

  bool _photoCurrent(int operation) => _current && operation == _photoOperation;

  Future<bool> _photoReady(int operation) async {
    while (_photoCurrent(operation) && !_foreground) {
      final waiting = _photoResume ??= Completer<void>();
      await waiting.future;
    }
    return _photoCurrent(operation);
  }

  Future<String?> _capturePhoto(int operation) async {
    if (!await _photoReady(operation) || !mounted) {
      return null;
    }
    return await _dialogs.push<String>(context, const NativeCameraScreen());
  }

  Future<bool> _photoRetry(Object failure, int operation) async {
    if (!await _photoReady(operation) || !mounted) {
      return false;
    }
    setState(() => _photoUploading = false);
    return await _dialogs.show<bool>(
              context,
              NativePhotoRetryDialog(failure: failure),
            ) ==
            true &&
        _photoCurrent(operation);
  }

  void _adoptPhotoProfile(AccountProfile fresh) {
    final changedScope =
        _profile.adminFilter != fresh.adminFilter ||
        _profile.value('all_access_flag') != fresh.value('all_access_flag') ||
        _profile.value('is_pay_appoint_type_active') !=
            fresh.value('is_pay_appoint_type_active');
    setState(() {
      _profile = fresh;
      if (changedScope) {
        _photoReloadNeeded = true;
        _summary = null;
        _holdAdminCharts = true;
      }
    });
  }

  /// The server, old picture and chart filters remain intact on cancel/error.
  /// Selected bytes stay in memory only for the current account's manual Retry.
  Future<void> _changePhoto() async {
    if (!_current || !_foreground || _profile.isDoctor || _photoBusy) {
      return;
    }
    final operation = ++_photoOperation;
    bool current() => _photoCurrent(operation);
    setState(() {
      _photoBusy = true;
      _photoUploading = false;
      _photoBackgrounded = false;
      _photoReloadNeeded = false;
    });
    var accessVerified = false;
    try {
      final source = await _dialogs.show<DashboardPhotoSource>(
        context,
        const NativePhotoChoiceDialog(),
      );
      if (source == null || !await _photoReady(operation)) {
        return;
      }
      Uint8List? selected;
      do {
        setState(() => _photoUploading = true);
        try {
          selected = await widget.services.media.select(
            source,
            capture: () async => await _capturePhoto(operation),
            ready: () async => await _photoReady(operation),
          );
          break;
        } catch (failure) {
          if (!await _photoRetry(failure, operation)) {
            return;
          }
        }
      } while (current());
      if (selected == null || !await _photoReady(operation)) {
        return;
      }
      // Keep exactly the same immutable payload across explicit upload retries.
      final jpeg = Uint8List.fromList(selected);
      var uploaded = false;
      while (await _photoReady(operation)) {
        setState(() => _photoUploading = true);
        try {
          var fresh = await widget.auth.profiles.open(
            _session,
            recordLogin: false,
            isCurrent: () => current() && _foreground,
          );
          if (!current()) {
            return;
          }
          if (!uploaded) {
            _photoBackgrounded = false;
            await DashboardPhotoRepository(
              widget.repository.transport,
              now: widget.repository.now,
            ).upload(
              _session,
              fresh,
              jpeg,
              isCurrent: current,
              isForeground: () => _foreground,
            );
            uploaded = true;
          }
          if (!await _photoReady(operation)) {
            return;
          }
          // A successful POST completed in the background: re-read access, but
          // never upload again merely because the app was deactivated.
          if (_photoBackgrounded) {
            fresh = await widget.auth.profiles.open(
              _session,
              recordLogin: false,
              isCurrent: () => current() && _foreground,
            );
          }
          if (!current()) {
            return;
          }
          ProfileRepository.checkAccess(fresh, widget.repository.now());
          accessVerified = true;
          _adoptPhotoProfile(fresh);
          setState(() {
            _picture = jpeg;
          });
          if (!mounted) {
            return;
          }
          _toasts.show(context, 'Picture Uploaded');
          return;
        } catch (failure) {
          if (!current()) {
            return;
          }
          if (failure is AppFailure && failure.kind == FailureKind.denied) {
            _deny(failure);
            return;
          }
          final reason =
              failure is ObsoleteRequest
                  ? const AppFailure(
                    'The app was paused. Please retry when ready.',
                  )
                  : failure;
          if (!await _photoRetry(reason, operation)) {
            return;
          }
        }
      }
    } finally {
      // Cancel after Camera/Gallery still checks revoked access without resetting
      // successful chart selections, adding login logs or sending image bytes.
      if (current() &&
          _photoBackgrounded &&
          !accessVerified &&
          await _photoReady(operation)) {
        try {
          final fresh = await widget.auth.profiles.open(
            _session,
            recordLogin: false,
            isCurrent: () => current() && _foreground,
          );
          if (current()) {
            _adoptPhotoProfile(fresh);
          }
        } catch (failure) {
          if (current()) {
            if (failure is AppFailure && failure.kind == FailureKind.denied) {
              _deny(failure);
            } else {
              setState(() {
                _fullFailure = failure;
                _error = dashboardFailureDetail(failure);
              });
              _retryLoad = () async {
                await _load(refreshPicture: true);
              };
              _queueFullError();
            }
          }
        }
      }
      if (mounted && operation == _photoOperation) {
        setState(() {
          _photoBusy = false;
          _photoUploading = false;
        });
        if (_photoReloadNeeded && _current && _foreground) {
          _photoReloadNeeded = false;
          await _load(refreshPicture: true);
        }
      }
    }
  }

  @override
  void dispose() {
    _toasts.dispose();
    ++_request;
    ++_photoOperation;
    _wakePhoto();
    _stopMeetingClock();
    _dialogs.dispose();
    widget.auth.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_fullFailure != null) {
      return const NativeDashboardGateBackground();
    }
    final body = NativeDashboardLayout(
      profile: _profile,
      summary: _summary,
      picture: _picture,
      period: _period,
      now: _summary?.asOf ?? widget.repository.now(),
      countdown: _countdown,
      meetingRefreshing: _meetingRefreshing,
      adminOverview:
          _profile.isDoctor || _holdAdminCharts
              ? null
              : NativeAdminOverview(
                key: ValueKey(
                  'overview:${_session.center.baseUri}:${_session.account.key}',
                ),
                auth: widget.auth,
                profile: _profile,
                repository: AdminChartRepository(
                  widget.repository.transport,
                  now: widget.repository.now,
                ),
                refreshRevision: _overviewRevision,
                onDashboardFailure: _adminFailed,
                onDashboardReady: _adminReady,
                sdp:
                    MediaQuery.sizeOf(context).shortestSide < 300
                        ? 1
                        : (MediaQuery.sizeOf(context).shortestSide / 30)
                                .floor() *
                            30 /
                            300,
              ),
      loading: _loading,
      error: _error,
      showSwitch: widget.auth.canSwitch,
      onSwitch: widget.auth.beginSwitch,
      onLogout: _logout,
      onPeriod: _selectPeriod,
      onRefresh: _refresh,
      onDestination: _openDestination,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_confirmExit());
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: _waitingAdmin || (_loading && _summary == null),
            child: body,
          ),
          if (_photoUploading ||
              _waitingAdmin ||
              (_loading && _summary == null))
            const Positioned.fill(
              child: NativeDashboardGateBackground(loading: true),
            ),
        ],
      ),
    );
  }
}
