import 'package:intl/intl.dart';

final _grouped = NumberFormat('#,##0', 'en_US');

/// `Math.round(n).toLocaleString()` from the prototype.
String group(num n) => _grouped.format(n.round());

/// Money amounts, like the Dashboard's `formatMoney`: separators, and
/// piastres only when there are any, then always two digits
/// ("20,000", "109,584.75", "19,900.50").
final _whole = NumberFormat('#,##0', 'en_US');
final _piastres = NumberFormat('#,##0.00', 'en_US');

/// An amount without the currency: "109,584.75".
String amount(num n) {
  final cents = (n * 100).round();
  return cents % 100 == 0 ? _whole.format(cents ~/ 100) : _piastres.format(cents / 100);
}

/// `money(n)` — "57,472 EGP", "109,584.75 EGP".
String money(num n) => '${amount(n)} EGP';

/// `money2(n)` — signed amounts on the statement: "+ 20,000 EGP" / "- 15,000.50 EGP".
String signedMoney(num n) => '${n < 0 ? '- ' : '+ '}${amount(n.abs())} EGP';

/// Parse user-typed amounts like "56,760" (`parseAmt`).
double parseAmount(String v) => double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

/// A backend decimal string as money for display only ("11640.0000" -> "11,640 EGP").
/// The app never computes with it.
String moneyOf(String? decimal) => money(double.tryParse(decimal ?? '') ?? 0);

/// Dates follow the app's language: [LangController] sets this, so every
/// date reads in Arabic ("31 أغسطس، 19:00") when the app is in Arabic.
bool arabicDates = false;

const _monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsLong = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _monthsAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

String _month(int month, {bool long = false}) => (arabicDates ? _monthsAr : (long ? _monthsLong : _monthsShort))[month - 1];

/// "31 Aug, 19:00" — a deadline, in the device's local time.
String whenOf(DateTime at) {
  final l = at.toLocal();
  final time = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  return '${l.day} ${_month(l.month)}${arabicDates ? '،' : ','} $time';
}

/// "31 Aug", in the device's local time.
String dayMonth(DateTime at) {
  final l = at.toLocal();
  return '${l.day} ${_month(l.month)}';
}

/// "31 Aug 2026", in the device's local time.
String dayMonthYear(DateTime at) {
  final l = at.toLocal();
  return '${l.day} ${_month(l.month)} ${l.year}';
}

/// "August 2026".
String monthYear(DateTime at) {
  final l = at.toLocal();
  return '${_month(l.month, long: true)} ${l.year}';
}

/// "1st", "2nd", "3rd", "4th"… — a place in line.
String ordinal(int n) {
  final tens = n % 100;
  if (tens >= 11 && tens <= 13) return '${n}th';
  return '$n${const ['th', 'st', 'nd', 'rd'][n % 10 < 4 ? n % 10 : 0]}';
}
