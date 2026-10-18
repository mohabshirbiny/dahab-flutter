import 'package:dahab_app/core/data/countries.dart';
import 'package:dahab_app/services/auth/auth_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every country has a unique ISO code, a calling code the backend takes, and both names', () {
    final isos = <String>{};
    for (final c in countries) {
      expect(isos.add(c.iso), isTrue, reason: 'duplicate ${c.iso}');
      expect(RegExp(r'^[A-Z]{2}$').hasMatch(c.iso), isTrue, reason: c.iso);
      expect(RegExp(r'^\+[1-9]\d{0,3}$').hasMatch(c.dial), isTrue, reason: '${c.iso} ${c.dial}');
      expect(c.en, isNotEmpty);
      expect(c.ar, isNotEmpty);
    }
    expect(countries.length, greaterThan(200));
    for (final iso in popularCountryIsos) {
      expect(isos, contains(iso));
    }
  });

  test('the flag is built from the ISO code', () {
    expect(countries.firstWhere((c) => c.iso == 'EG').flag, '🇪🇬');
  });

  test('a shared calling code keeps the country that was picked', () {
    expect(countryForDial('+1')!.iso, 'US');
    expect(countryForDial('+1', preferIso: 'CA')!.iso, 'CA');
    expect(countryForDial('+7')!.iso, isIn(['KZ', 'RU']));
    expect(countryForDial('+999'), isNull);
  });

  test('numbers from any country split and mask on the longest calling code', () {
    expect(splitE164('+201012344417'), ('+20', '1012344417'));
    expect(splitE164('+2348031234567'), ('+234', '8031234567'));
    expect(splitE164('+18765551234'), ('+1876', '5551234'));
    expect(toE164('+234', '0803 123 4567'), '+2348031234567');
    expect(maskPhone('+201012344417'), '+20 10 •••• 4417');
    expect(maskPhone('+491701234567'), '+49 17 •••• 4567');
  });
}
