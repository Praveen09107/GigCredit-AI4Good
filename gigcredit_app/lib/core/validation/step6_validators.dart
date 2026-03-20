class Step6Validators {
  static String? validateSvanidhiRef(String value) {
    final trimmed = value.trim().toUpperCase();
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^[A-Z0-9-]{6,24}$').hasMatch(trimmed)) {
      return 'SVANidhi reference looks invalid.';
    }
    return null;
  }

  static String? validateEShramNumber(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^\d{12}$').hasMatch(trimmed)) {
      return 'eShram number must be 12 digits.';
    }
    return null;
  }

  static String? validateUdyamNumber(String value) {
    final trimmed = value.trim().toUpperCase();
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^UDYAM-[A-Z]{2}-\d{2}-\d{7}$').hasMatch(trimmed)) {
      return 'Udyam number format invalid (e.g., UDYAM-TN-01-1234567).';
    }
    return null;
  }

  static String? validatePmSymRef(String value) {
    return _validateOptionalReference(
      value,
      pattern: RegExp(r'^[A-Z0-9-]{6,30}$'),
      message: 'PM-SYM reference looks invalid.',
    );
  }

  static String? validatePmjjbyRef(String value) {
    return _validateOptionalReference(
      value,
      pattern: RegExp(r'^[A-Z0-9-]{6,30}$'),
      message: 'PMJJBY reference looks invalid.',
    );
  }

  static String? validatePpfAccountRef(String value) {
    return _validateOptionalReference(
      value,
      pattern: RegExp(r'^[A-Z0-9-]{6,30}$'),
      message: 'PPF account reference looks invalid.',
    );
  }

  static String? _validateOptionalReference(
    String value, {
    required RegExp pattern,
    required String message,
  }) {
    final trimmed = value.trim().toUpperCase();
    if (trimmed.isEmpty) return null;
    if (!pattern.hasMatch(trimmed)) {
      return message;
    }
    return null;
  }
}
