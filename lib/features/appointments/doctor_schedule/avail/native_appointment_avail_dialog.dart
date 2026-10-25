import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/failure.dart';
import '../../../dashboard/native_dashboard_dialogs.dart';
import '../native_appointment_timeline_card.dart';
import 'doctor_appointment_avail_repository.dart';

typedef DoctorAppointmentAvailSubmit =
    Future<DoctorAppointmentAvailResult> Function(
      String notes,
      bool Function() isCurrent,
    );

class NativeAppointmentAvailDialog extends StatefulWidget {
  const NativeAppointmentAvailDialog({super.key, required this.onSubmit});
  final DoctorAppointmentAvailSubmit onSubmit;

  @override
  State<NativeAppointmentAvailDialog> createState() =>
      _NativeAppointmentAvailDialogState();
}

class _NativeAppointmentAvailDialogState
    extends State<NativeAppointmentAvailDialog> {
  final _notes = TextEditingController();
  bool _working = false;
  Object? _failure;
  String? _notesError;
  int _attempt = 0;

  Future<void> _submit() async {
    if (_working) return;
    final error = DoctorAppointmentAvailRepository.notesError(_notes.text);
    if (error != null) {
      setState(() => _notesError = error);
      return;
    }
    FocusScope.of(context).unfocus();
    final attempt = ++_attempt;
    setState(() {
      _working = true;
      _failure = null;
      _notesError = null;
    });
    try {
      final result = await widget.onSubmit(
        _notes.text,
        () => mounted && attempt == _attempt,
      );
      if (!mounted || attempt != _attempt) return;
      Navigator.pop(context, result);
    } on ObsoleteRequest {
      // The owning screen closes the route on background/logout/disposal.
    } catch (failure) {
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _working = false;
        _failure = failure;
      });
    }
  }

  Widget _button(
    String label,
    String key,
    VoidCallback action,
    double sdp, {
    bool cancel = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: ElevatedButton(
      key: Key(key),
      onPressed: _working ? null : action,
      style: ElevatedButton.styleFrom(
        backgroundColor: cancel ? const Color(0xffb2bec3) : DocColors.primary,
        foregroundColor: Colors.white,
        elevation: 1,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10 * sdp),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: appointmentText(
            14,
            family: 'PatuaOne',
            color: Colors.white,
            weight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );

  void _cancel() {
    if (!_working) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sdp = appointmentScale(context);
    return Dialog(
      key: const Key('doctor_appointment_avail_dialog'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: MediaQuery.sizeOf(context).height < 500 ? 8 : 24,
      ),
      child: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child:
              _working
                  ? SizedBox(
                    height: 96 * sdp,
                    child: const Center(
                      child: CircularProgressIndicator(
                        key: Key('doctor_appointment_avail_loading'),
                      ),
                    ),
                  )
                  : _failure != null
                  ? Padding(
                    padding: EdgeInsets.all(12 * sdp),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dashboardFailureDetail(_failure!),
                          key: const Key('doctor_appointment_avail_failure'),
                          textAlign: TextAlign.center,
                          style: appointmentText(10 * sdp),
                        ),
                        const SizedBox(height: 8),
                        _button(
                          'RETRY',
                          'doctor_appointment_avail_retry',
                          _submit,
                          sdp,
                        ),
                        // Allow leaving an unrecoverable error without a forced
                        // app restart; a retry still needs an explicit tap.
                        TextButton(
                          key: const Key(
                            'doctor_appointment_avail_error_cancel',
                          ),
                          onPressed: _cancel,
                          child: const Text('CANCEL'),
                        ),
                      ],
                    ),
                  )
                  : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ColoredBox(
                        color: DocColors.primary,
                        child: Padding(
                          padding: EdgeInsets.all(10 * sdp),
                          child: Text(
                            'Avail Schedule',
                            style: appointmentText(
                              13 * sdp,
                              family: 'RussoOne',
                              weight: FontWeight.w400,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          8 * sdp,
                          10 * sdp,
                          8 * sdp,
                          4 * sdp,
                        ),
                        child: Text(
                          'Do you want to avail this schedule for the patient? This action cannot be undone.You may add comments below if needed.',
                          textAlign: TextAlign.center,
                          style: appointmentText(
                            9 * sdp,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          8 * sdp,
                          10 * sdp,
                          8 * sdp,
                          14 * sdp,
                        ),
                        child: Material(
                          color: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8 * sdp),
                            side: const BorderSide(color: DocColors.primary),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: TextField(
                            key: const Key('doctor_appointment_avail_notes'),
                            controller: _notes,
                            textInputAction: TextInputAction.done,
                            maxLines: 1,
                            autocorrect: false,
                            enableSuggestions: false,
                            smartDashesType: SmartDashesType.disabled,
                            smartQuotesType: SmartQuotesType.disabled,
                            onSubmitted:
                                (_) => FocusScope.of(context).unfocus(),
                            onChanged: (_) {
                              if (_notesError != null) {
                                setState(() => _notesError = null);
                              }
                            },
                            style: appointmentText(
                              10 * sdp,
                              weight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Notes (Optional)',
                              hintStyle: appointmentText(
                                10 * sdp,
                                color: const Color(0xffb2bec3),
                              ),
                              errorText: _notesError,
                              errorMaxLines: 5,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14 * sdp,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          8 * sdp,
                          8 * sdp,
                          8 * sdp,
                          12 * sdp,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _button(
                                'CANCEL',
                                'doctor_appointment_avail_cancel',
                                _cancel,
                                sdp,
                                cancel: true,
                              ),
                            ),
                            SizedBox(width: 8 * sdp),
                            Expanded(
                              child: _button(
                                'AVAIL',
                                'doctor_appointment_avail_submit',
                                _submit,
                                sdp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    ++_attempt;
    _notes.dispose();
    super.dispose();
  }
}
