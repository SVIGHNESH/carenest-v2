final _mobile = RegExp(r'^[6-9]\d{9}$');

/// Reduces what the user typed to a bare 10-digit mobile, or null when invalid.
String? parseIndianMobile(String raw) {
  var d = raw.replaceAll(RegExp(r'[\s\-().]'), '');
  if (d.startsWith('+')) d = d.substring(1);
  if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
  if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
  return _mobile.hasMatch(d) ? d : null;
}

/// `+91` form sent to the API.
String? toE164(String raw) {
  final d = parseIndianMobile(raw);
  return d == null ? null : '+91$d';
}

/// 98xxxxxx10 style masking for display.
String maskPhone(String? e164) {
  if (e164 == null || e164.length < 4) return '';
  final d = e164.replaceFirst('+91', '');
  if (d.length != 10) return e164;
  return '${d.substring(0, 2)}xxxxxx${d.substring(8)}';
}

String displayPhone(String? e164) {
  if (e164 == null) return '';
  final d = e164.replaceFirst('+91', '');
  return d.length == 10 ? '+91 ${d.substring(0, 5)} ${d.substring(5)}' : e164;
}
