import 'package:dahab_app/core/text/app_controls.dart';
import 'package:dahab_app/core/text/texts_controller.dart';
import 'package:dahab_app/features/shared/listing_ui.dart';
import 'package:dahab_app/services/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Backend spec 019 US7: the switches the app reads and the words it shows for a refusal.
void main() {
  test('nothing is off until the server says so', () {
    final c = TextsController();
    expect(c.controls.stopped, isFalse);
    expect(c.controls.shows('sharing'), isTrue);
    expect(c.controls.of('gold'), isNull);
  });

  test('reads a stop, a pause and the visibility flags', () {
    final controls = AppControls.fromJson({
      'stop_everything': {
        'active': true,
        'message': {'en': 'Back soon', 'ar': 'راجعين'},
      },
      'categories': [
        {
          'category': 'diamond',
          'level': 'pause_category',
          'message': {'en': 'Paused', 'ar': 'متوقفة'},
        },
      ],
      'visibility': {'sharing': false, 'listing_stats': true},
    });

    expect(controls.stopped, isTrue);
    expect(controls.stopMessage.text(arabic: true), 'راجعين');
    expect(controls.of('diamond')!.level, 'pause_category');
    expect(controls.shows('sharing'), isFalse);
    expect(controls.shows('payout_averages'), isTrue);
  });

  test('a stop refusal shows the words staff wrote', () {
    const e = ApiException(
      status: 409,
      code: 'category_stopped',
      message: 'fallback',
      extra: {
        'details': {
          'message': {'en': 'Back on Monday.', 'ar': 'راجعين الاتنين.'},
        },
      },
    );
    expect(controlRefusalMessage(e), 'Back on Monday.');
    expect(controlRefusalMessage(const ApiException(status: 409, code: 'other', message: 'x')), isNull);
  });
}
