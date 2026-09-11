import 'package:intl/intl.dart';

String formatMoney(int cents, {String currency = 'USD', String? locale}) =>
    NumberFormat.simpleCurrency(name: currency.toUpperCase(), locale: locale)
        .format(cents / 100);

String formatDate(DateTime d, {String? locale}) =>
    DateFormat.yMMMd(locale).format(d);

String formatTime(DateTime d, {String? locale}) =>
    DateFormat.jm(locale).format(d);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
