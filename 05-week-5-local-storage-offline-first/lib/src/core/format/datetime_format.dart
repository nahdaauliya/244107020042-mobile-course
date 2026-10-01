/// Format waktu tanpa dependensi `intl`.
///
/// Alasannya bukan kesederhanaan, tapi konsistensi: satu file ini adalah satu
/// sumber format untuk seluruh aplikasi, jadi screenshot, UI, dan test tidak
/// bisa_format berbeda satu sama lain.
library;

/// `01/10/2026 19:30` dalam waktu lokal.
String formatDateTime(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// Waktu relatif kasar untuk strip status: "baru saja", "12 menit lalu".
String formatRelative(DateTime? value, {DateTime? now}) {
  if (value == null) return 'belum pernah';
  final reference = (now ?? DateTime.now()).toUtc();
  final target = value.toUtc();
  final diff = reference.difference(target);

  if (diff.isNegative) return 'baru saja';
  if (diff.inSeconds < 45) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 30) return '${diff.inDays} hari lalu';
  return formatDateTime(value);
}