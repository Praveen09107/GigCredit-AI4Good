class Step2Validators {
  static String? validateAadhaar(String value) {
    final sanitized = value.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d{12}$').hasMatch(sanitized)) {
      return 'Aadhaar must be exactly 12 digits.';
    }
    return null;
  }

  static String? validatePan(String value) {
    final normalized = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(normalized)) {
      return 'PAN format must be ABCDE1234F.';
    }
    return null;
  }

  static String normalizePan(String value) => value.trim().toUpperCase();

  static String normalizeAadhaar(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').trim();
}
