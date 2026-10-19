import 'package:docdiary_ios/core/native_json.dart';
import 'support.dart';

JsonMap blockedSlot({
  String date = '21-OCT-26',
  String time = '09:00 AM - 10:00 AM',
  Object? total = '4',
  String id = '1',
}) => {
  'lad_id': id,
  'lad_date': date,
  'las_id': '2',
  'las_ts_id': '3',
  'las_notes': null,
  'la_id': '4',
  'la_month': 'OCT-26',
  'schedule_time': time,
  'tot_sc': total,
};
List<JsonMap> blockedSlots() => [
  blockedSlot(),
  blockedSlot(time: '11:00 AM - 12:00 PM', id: '2'),
  blockedSlot(date: '22-OCT-26', total: '2'),
  blockedSlot(
    date: '22-OCT-26',
    time: '11:00 AM - 12:00 PM',
    total: '2',
    id: '2',
  ),
  blockedSlot(date: '23-OCT-26', total: '2'),
  blockedSlot(date: '01-NOV-26', total: '1'),
  blockedSlot(date: '31-DEC-26', total: '1'),
];
Harness blockTimeHarness({DateTime? clock}) {
  final h = Harness(clock: clock ?? DateTime(2026, 10, 19, 13, 30));
  h.transport.onGet =
      (uri) async =>
          uri.path.endsWith('/leave_schedule/getTimeSchedule')
              ? {'count': blockedSlots().length, 'items': blockedSlots()}
              : await h.defaultGet(uri);
  return h;
}
