class Step3Validators {
  static String? validateIfsc(String value) {
    final normalized = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(normalized)) {
      return 'IFSC must match format: HDFC0001234';
    }
    return null;
  }

  static String? validateAccountNumber(String value) {
    final trimmed = value.trim();
    if (!RegExp(r'^\d{9,18}$').hasMatch(trimmed)) {
      return 'Account number must be 9 to 18 digits.';
    }
    return null;
  }

  static String normalizeIfsc(String value) => value.trim().toUpperCase();

  static String normalizeAccountNumber(String value) => value.trim();
}
