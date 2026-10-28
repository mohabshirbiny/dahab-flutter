import 'package:dahab_app/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-10-28: the backend sent an event with no detail as `[]`, and one such order (a returned piece the
/// seller collected) emptied the whole Orders tab. An event reads any detail that is not an object as none.
void main() {
  test('a timeline event whose detail is a list, null or missing reads as no detail', () {
    for (final detail in <Object?>[<Object?>[], null, 'x']) {
      final e = OrderTimelineEvent.fromJson({'event': 'return_collected', 'at': '2026-10-28T18:46:34+00:00', 'detail': detail});
      expect(e, isNotNull);
      expect(e!.detail, isEmpty);
    }
    final e = OrderTimelineEvent.fromJson({'event': 'received', 'at': '2026-10-28T18:46:34+00:00', 'detail': {'state': 'at_inspection'}});
    expect(e!.detail['state'], 'at_inspection');
  });
}
