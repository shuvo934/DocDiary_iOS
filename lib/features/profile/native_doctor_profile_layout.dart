import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../auth/profile_repository.dart';
import '../dashboard/native_dashboard_icons.dart';
import 'doctor_profile_repository.dart';
import 'native_profile_icons.dart';

class NativeDoctorProfileLayout extends StatelessWidget {
  const NativeDoctorProfileLayout({
    super.key,
    required this.profile,
    required this.details,
    required this.loading,
    required this.onBack,
    required this.onPhoto,
    required this.onAddress,
    required this.onPassword,
    required this.onVideo,
  });
  final AccountProfile profile;
  final DoctorProfileDetails? details;
  final bool loading;
  final VoidCallback onBack, onPhoto, onAddress, onPassword, onVideo;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).shortestSide;
    final sdp = width < 300 ? 1.0 : (width / 30).floor() * 30 / 300;
    TextStyle text(
      double size, {
      FontWeight weight = FontWeight.w400,
      Color color = Colors.black,
      String family = 'Poppins',
    }) => TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.5,
      textBaseline: TextBaseline.alphabetic,
    );
    Widget identity(
      String key,
      String value,
      double size, {
      bool bold = false,
    }) => Text(
      value,
      key: Key(key),
      textAlign: TextAlign.center,
      style: text(size * sdp, weight: bold ? FontWeight.w700 : FontWeight.w400),
    );
    Widget field(String key, String label, String name) => Padding(
      padding: EdgeInsets.fromLTRB(5 * sdp, 0, 5 * sdp, 5 * sdp),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: text(
                10 * sdp,
                weight: FontWeight.w700,
                color: const Color(0x8A000000),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              details?.value(name) ?? '',
              key: Key(key),
              style: text(10 * sdp, color: const Color(0x8A000000)),
            ),
          ),
        ],
      ),
    );
    Widget section(String title, {bool edit = false}) => Padding(
      padding: EdgeInsets.fromLTRB(3 * sdp, 12 * sdp, 3 * sdp, 5 * sdp),
      child: Material(
        color: DocColors.clouds,
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.fromLTRB(6 * sdp, 6 * sdp, 4 * sdp, 4 * sdp),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: text(11 * sdp, weight: FontWeight.w700),
                ),
              ),
              if (edit)
                SizedBox(
                  width: 32,
                  height: 24,
                  child: IconButton(
                    key: const Key('profile_edit_address'),
                    tooltip: 'Edit address',
                    padding: EdgeInsets.zero,
                    onPressed: onAddress,
                    icon: const NativeProfileIcon(
                      NativeProfileGlyph.edit,
                      size: 24,
                      color: DocColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    Widget button(
      String key,
      String title,
      VoidCallback tap, {
      bool video = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        key: Key(key),
        onPressed: tap,
        style: ElevatedButton.styleFrom(
          backgroundColor: DocColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10 * sdp),
          ),
          textStyle: text(
            14,
            color: Colors.white,
            weight: video ? FontWeight.w400 : FontWeight.w700,
            family: video ? 'Baloo' : 'Poppins',
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (video) ...[
              const NativeProfileIcon(
                NativeProfileGlyph.video,
                size: 24,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(title, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
    final photo = details?.picture;
    Widget fallback() =>
        Image.asset('assets/images/doctor.png', fit: BoxFit.cover);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: loading ? Colors.white : DocColors.primary,
        body:
            loading
                ? const Center(
                  child: CircularProgressIndicator(
                    key: Key('profile_loading'),
                    color: DocColors.primary,
                  ),
                )
                : SafeArea(
                  child: LayoutBuilder(
                    builder:
                        (context, constraints) => Column(
                          children: [
                            SizedBox(
                              height: constraints.maxHeight * .09,
                              child: Row(
                                children: [
                                  SizedBox(width: 12 * sdp),
                                  SizedBox(
                                    width: 19 * sdp,
                                    child: OverflowBox(
                                      maxWidth: 48,
                                      maxHeight: 48,
                                      child: IconButton(
                                        key: const Key('profile_back'),
                                        tooltip: 'Back',
                                        onPressed: onBack,
                                        padding: EdgeInsets.zero,
                                        icon: NativeProfileIcon(
                                          NativeProfileGlyph.back,
                                          size: 19 * sdp,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      'Profile',
                                      style: text(
                                        14 * sdp,
                                        weight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(30),
                                ),
                                child: ColoredBox(
                                  color: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      top: 2.0,
                                      left: 6.0,
                                      right: 6.0,
                                      bottom: 6.0,
                                    ),
                                    child: SingleChildScrollView(
                                      key: const Key('profile_scroll'),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.only(
                                              top: 15 * sdp,
                                              bottom: 10 * sdp,
                                            ),
                                            child: Center(
                                              child: SizedBox.square(
                                                dimension: 104 * sdp,
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    Center(
                                                      child: Material(
                                                        elevation: 3,
                                                        shape:
                                                            const CircleBorder(),
                                                        color: Colors.white,
                                                        child: Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                2 * sdp,
                                                              ),
                                                          child: Container(
                                                            width: 100 * sdp,
                                                            height: 100 * sdp,
                                                            decoration: BoxDecoration(
                                                              shape:
                                                                  BoxShape
                                                                      .circle,
                                                              border: Border.all(
                                                                color:
                                                                    DocColors
                                                                        .greenSea,
                                                              ),
                                                            ),
                                                            child: ClipOval(
                                                              child:
                                                                  photo == null
                                                                      ? fallback()
                                                                      : Image.memory(
                                                                        photo,
                                                                        key: const Key(
                                                                          'profile_picture',
                                                                        ),
                                                                        fit:
                                                                            BoxFit.cover,
                                                                        errorBuilder:
                                                                            (
                                                                              _,
                                                                              __,
                                                                              ___,
                                                                            ) =>
                                                                                fallback(),
                                                                      ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      top: -2,
                                                      right: -2,
                                                      child: SizedBox.square(
                                                        dimension: 18 * sdp,
                                                        child: OverflowBox(
                                                          maxWidth: 44,
                                                          maxHeight: 44,
                                                          child: IconButton(
                                                            key: const Key(
                                                              'profile_change_photo',
                                                            ),
                                                            tooltip:
                                                                'Change picture',
                                                            padding:
                                                                EdgeInsets.zero,
                                                            onPressed: onPhoto,
                                                            icon: NativeDashboardIcon(
                                                              NativeDashboardGlyph
                                                                  .camera,
                                                              size: 20 * sdp,
                                                              color:
                                                                  DocColors
                                                                      .primary,
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
                                          SizedBox(height: 2),
                                          identity(
                                            'profile_name',
                                            profile.value('doc_name'),
                                            15,
                                            bold: true,
                                          ),
                                          SizedBox(height: 2),
                                          identity(
                                            'profile_code',
                                            '(${profile.value('doc_code')})',
                                            11,
                                          ),
                                          SizedBox(height: 2),
                                          identity(
                                            'profile_designation',
                                            profile.value('desig_name'),
                                            11,
                                          ),
                                          SizedBox(height: 2),
                                          identity(
                                            'profile_department',
                                            profile.value('deptd_name'),
                                            11,
                                          ),
                                          SizedBox(height: 2),
                                          identity(
                                            'profile_unit',
                                            profile.value('depts_name'),
                                            11,
                                          ),
                                          if (profile
                                              .value('doc_center_name')
                                              .isNotEmpty) ...[
                                            SizedBox(height: 2),
                                            identity(
                                              'profile_center',
                                              profile.value('doc_center_name'),
                                              11,
                                              bold: true,
                                            ),
                                          ],

                                          if (profile.value(
                                                'doc_video_link_enable_flag',
                                              ) ==
                                              '1') ...[
                                            SizedBox(height: 2),
                                            Center(
                                              child: button(
                                                'profile_video',
                                                'VIDEO CALL',
                                                onVideo,
                                                video: true,
                                              ),
                                            ),
                                          ],
                                          Padding(
                                            padding: EdgeInsets.only(
                                              top: 10 * sdp,
                                            ),
                                            child: Center(
                                              child: button(
                                                'profile_password',
                                                'CHANGE PASSWORD',
                                                onPassword,
                                              ),
                                            ),
                                          ),
                                          section('Address:', edit: true),
                                          field(
                                            'profile_street',
                                            'Street Address:',
                                            'doc_village',
                                          ),
                                          field(
                                            'profile_post_office',
                                            'Post Office:',
                                            'doc_poffice',
                                          ),
                                          field(
                                            'profile_thana',
                                            'Thana/Upazila:',
                                            'dd_thana_name',
                                          ),
                                          field(
                                            'profile_district',
                                            'District:',
                                            'dist_name',
                                          ),
                                          section('Contact Information:'),
                                          field(
                                            'profile_mobile',
                                            'Mobile:',
                                            'doc_cell',
                                          ),
                                          field(
                                            'profile_phone',
                                            'Phone (Home):',
                                            'doc_phone',
                                          ),
                                          field(
                                            'profile_email',
                                            'Email:',
                                            'doc_email',
                                          ),
                                        ],
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
    );
  }
}
