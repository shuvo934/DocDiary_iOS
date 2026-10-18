import 'dart:typed_data';

import 'package:docdiary_ios/core/native_json.dart';
import 'package:image/image.dart' as image;

import 'support.dart';

Uint8List profileJpeg() => image.encodeJpg(image.Image(width: 24, height: 16));
JsonMap profileDetails({String street = 'Example Road'}) => {
  'doc_village': street,
  'doc_poffice': 'Savar',
  'dd_thana_name': 'Savar',
  'dist_name': 'Dhaka',
  'doc_dd_id': '12',
  'dist_id': '1',
  'doc_cell': '01700000000',
  'doc_phone': null,
  'doc_email': 'doctor@example.invalid',
  'doc_profile_pic': null,
};
Harness profileHarness() {
  final h = Harness();
  h.doctorData.addAll({
    'desig_name': 'Consultant',
    'deptd_name': 'Physiotherapy',
    'depts_name': 'Musculoskeletal Unit',
    'doc_video_link_enable_flag': '0',
    'doc_video_link': '',
  });
  h.transport.onGet =
      (uri) async =>
          uri.path.endsWith('getDocProfile')
              ? {
                'count': 1,
                'items': [profileDetails()],
              }
              : await h.defaultGet(uri);
  return h;
}
