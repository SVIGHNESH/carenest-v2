String rupees(int amount) {
  final s = amount.abs().toString();
  // Indian grouping: last three digits, then pairs.
  String out;
  if (s.length <= 3) {
    out = s;
  } else {
    final head = s.substring(0, s.length - 3);
    final tail = s.substring(s.length - 3);
    final pairs = RegExp(r'(\d)(?=(\d\d)+$)');
    out = '${head.replaceAllMapped(pairs, (m) => '${m[1]},')},$tail';
  }
  return 'Rs ${amount < 0 ? '-' : ''}$out';
}
