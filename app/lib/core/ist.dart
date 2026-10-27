/// All booking times are Indian Standard Time wall-clock, independent of the
/// phone's own time zone. Values here are plain `DateTime`s whose fields hold
/// the IST wall-clock reading; they are never converted with toLocal/toUtc.
typedef Clock = DateTime Function();

DateTime systemClock() => DateTime.now();

const _istOffset = Duration(hours: 5, minutes: 30);

/// Current IST wall-clock, built from the instant given by [clock].
DateTime nowIst(Clock clock) {
  final t = clock().toUtc().add(_istOffset);
  return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

String _two(int v) => v.toString().padLeft(2, '0');

String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// `yyyy-MM-ddTHH:00:00` with no zone, as the API expects for slot starts.
String isoSlot(DateTime day, int hour) => '${isoDate(day)}T${_two(hour)}:00:00';

/// Parses a server timestamp as wall-clock, ignoring any zone suffix.
DateTime parseWallClock(String s) {
  final base = s.length >= 19 ? s.substring(0, 19) : s;
  return DateTime.parse(base);
}

/// Parses a real instant (hold expiry). A value with no zone is taken as UTC.
DateTime parseInstant(String s) {
  final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(s);
  return DateTime.parse(hasZone ? s : '${s}Z').toUtc();
}

/// Earliest hour (0..24) that can be booked on [day] given [now] and notice.
bool isTooSoon({
  required DateTime day,
  required int hour,
  required DateTime nowWall,
  required int minNoticeMinutes,
}) {
  final earliest = nowWall.add(Duration(minutes: minNoticeMinutes));
  return DateTime(day.year, day.month, day.day, hour).isBefore(earliest);
}
