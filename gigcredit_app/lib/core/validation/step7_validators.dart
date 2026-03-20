class Step7Validators {
  static String? validatePolicyNumber(String value) {
    final trimmed = value.trim().toUpperCase();
    if (trimmed.isEmpty) return 'Policy number is required.';
    if (!RegExp(r'^[A-Z0-9-]{6,24}$').hasMatch(trimmed)) {
      return 'Policy number format looks invalid.';
    }
    return null;
  }

  static String? validateHolderName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Policy holder name is required.';
    }
    if (trimmed.length < 3) {
      return 'Policy holder name is too short.';
    }
    return null;
  }
}
