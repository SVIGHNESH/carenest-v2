import 'package:intl/intl.dart';

/// "Sat 10 Oct, 3:00 PM". The value is IST wall-clock and is never shifted.
String whenLabel(DateTime d) => DateFormat('EEE d MMM, h:mm a', 'en').format(d);

String dayLabel(DateTime d) => DateFormat('EEE d MMM', 'en').format(d);

String shortDayParts(DateTime d, {required bool weekday}) => weekday
    ? DateFormat('EEE', 'en').format(d)
    : DateFormat('d', 'en').format(d);

/// 15 -> "3:00 PM".
String hourLabel(int hour) {
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final suffix = hour < 12 || hour == 24 ? 'AM' : 'PM';
  return '$h12:00 $suffix';
}

String timeRangeLabel(DateTime start, DateTime end) =>
    '${DateFormat('h:mm a', 'en').format(start)} - ${DateFormat('h:mm a', 'en').format(end)}';
