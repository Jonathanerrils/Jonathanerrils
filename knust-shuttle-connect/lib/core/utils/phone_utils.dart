/// Normalises Ghanaian phone numbers to E.164 for Firebase phone auth.
/// Accepts local format (0XX XXX XXXX) or an already-international +233…
/// number. Returns null if the input can't be a valid number.
String? normalizeGhanaPhone(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  if (cleaned.startsWith('+')) {
    return RegExp(r'^\+\d{10,14}$').hasMatch(cleaned) ? cleaned : null;
  }
  if (RegExp(r'^0\d{9}$').hasMatch(cleaned)) {
    return '+233${cleaned.substring(1)}';
  }
  return null;
}
