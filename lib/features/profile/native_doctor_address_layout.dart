import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import 'doctor_address_repository.dart';
import 'native_doctor_thana_field.dart';

InputDecoration doctorAddressDecoration(String label, {String? helper}) {
  OutlineInputBorder border(double width, Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 15, color: Color(0xFFB2BEC3)),
    floatingLabelStyle: WidgetStateTextStyle.resolveWith(
      (states) => TextStyle(
        fontSize: 15,
        color:
            states.contains(WidgetState.focused)
                ? DocColors.greenSea
                : const Color(0xFFB2BEC3),
      ),
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: border(1, const Color(0xFF9E9E9E)),
    enabledBorder: border(1, const Color(0xFF9E9E9E)),
    focusedBorder: border(2, DocColors.greenSea),
    helperText: helper == null || helper.isEmpty ? null : helper,
    helperMaxLines: 3,
    helperStyle: const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 11,
      color: Color(0xFFCC0000),
    ),
  );
}

class NativeDoctorAddressLayout extends StatelessWidget {
  const NativeDoctorAddressLayout({
    super.key,
    required this.loading,
    required this.street,
    required this.postOffice,
    required this.thana,
    required this.district,
    required this.streetFocus,
    required this.postOfficeFocus,
    required this.thanaFocus,
    required this.thanas,
    required this.streetHelper,
    required this.postOfficeHelper,
    required this.thanaHelper,
    required this.onStreetChanged,
    required this.onPostOfficeChanged,
    required this.onThanaChanged,
    required this.onThanaSelected,
    required this.onClose,
    required this.onUpdate,
  });
  final bool loading;
  final TextEditingController street, postOffice, thana, district;
  final FocusNode streetFocus, postOfficeFocus, thanaFocus;
  final List<DoctorThana> thanas;
  final String? streetHelper, postOfficeHelper, thanaHelper;
  final ValueChanged<String> onStreetChanged,
      onPostOfficeChanged,
      onThanaChanged;
  final ValueChanged<DoctorThana> onThanaSelected;
  final VoidCallback onClose, onUpdate;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).shortestSide;
    final sdp = width < 300 ? 1.0 : (width / 30).floor() * 30 / 300;
    const fieldStyle = TextStyle(
      fontFamily: 'OpenSans',
      fontSize: 15,
      color: Colors.black,
      height: 1.5,
    );
    Widget field({
      required String key,
      required String label,
      required TextEditingController controller,
      required FocusNode focus,
      required ValueChanged<String> onChanged,
      String? helper,
    }) => TextField(
      key: Key(key),
      controller: controller,
      focusNode: focus,
      decoration: doctorAddressDecoration(label, helper: helper),
      style: fieldStyle,
      cursorColor: DocColors.greenSea,
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.text,
      autocorrect: false,
      enableSuggestions: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      textCapitalization: TextCapitalization.none,
      onChanged: onChanged,
      onSubmitted: (_) => focus.unfocus(),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: DocColors.clouds,
      ),
      child: Scaffold(
        key: const Key('doctor_address_screen'),
        backgroundColor: DocColors.clouds,
        body: SafeArea(
          bottom: false,
          child: ColoredBox(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child:
                  loading
                      ? const Center(
                        child: CircularProgressIndicator(
                          key: Key('address_loading'),
                          color: DocColors.primary,
                        ),
                      )
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ColoredBox(
                            color: DocColors.clouds,
                            child: Padding(
                              padding: EdgeInsets.all(12 * sdp),
                              child: Row(
                                children: [
                                  SizedBox.square(
                                    dimension: 21 * sdp,
                                    child: IconButton(
                                      key: const Key('address_close'),
                                      tooltip: 'Close',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: Icon(
                                        Icons.close,
                                        size: 21 * sdp,
                                        color: Colors.black,
                                      ),
                                      onPressed: onClose,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Update Address',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13 * sdp,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 1,
                            child: ColoredBox(color: DocColors.greenSea),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              key: const Key('address_scroll'),
                              padding: EdgeInsets.all(4 * sdp),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 10,
                                        bottom: 4,
                                      ),
                                      child: field(
                                        key: 'address_street',
                                        label: 'Street Address/Village',
                                        controller: street,
                                        focus: streetFocus,
                                        helper: streetHelper,
                                        onChanged: onStreetChanged,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 10,
                                        bottom: 4,
                                      ),
                                      child: field(
                                        key: 'address_post_office',
                                        label: 'Post Office',
                                        controller: postOffice,
                                        focus: postOfficeFocus,
                                        helper: postOfficeHelper,
                                        onChanged: onPostOfficeChanged,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 10,
                                        bottom: 4,
                                      ),
                                      child: NativeDoctorThanaField(
                                        controller: thana,
                                        focus: thanaFocus,
                                        items: thanas,
                                        decoration: doctorAddressDecoration(
                                          'Thana/Upazila',
                                          helper: thanaHelper,
                                        ),
                                        style: fieldStyle,
                                        onChanged: onThanaChanged,
                                        onSelected: onThanaSelected,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 10,
                                        bottom: 4,
                                      ),
                                      child: TextField(
                                        key: const Key('address_district'),
                                        controller: district,
                                        readOnly: true,
                                        enabled: false,
                                        style: const TextStyle(
                                          fontFamily: 'OpenSans',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: 'District:',
                                          floatingLabelBehavior:
                                              FloatingLabelBehavior.always,
                                          labelStyle: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFFB2BEC3),
                                          ),
                                          floatingLabelStyle: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFFB2BEC3),
                                          ),
                                          filled: true,
                                          fillColor: Color(0xFFF5F5F5),
                                          contentPadding: EdgeInsets.fromLTRB(
                                            16,
                                            10,
                                            16,
                                            10,
                                          ),
                                          border: UnderlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(5),
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          disabledBorder: UnderlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(5),
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(10),
                              color: DocColors.primary,
                              child: Ink(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: const LinearGradient(
                                    colors: [
                                      DocColors.primary,
                                      DocColors.greenSea,
                                    ],
                                  ),
                                ),
                                child: InkWell(
                                  key: const Key('address_update'),
                                  onTap: onUpdate,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Semantics(
                                    button: true,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 48,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(7),
                                        child: Center(
                                          child: Text(
                                            'UPDATE',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 13 * sdp,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
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
      ),
    );
  }
}
