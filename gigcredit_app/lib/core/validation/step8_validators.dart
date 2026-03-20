class Step8Validators {
  static String? validateItrAcknowledgement(String value) {
    final trimmed = value.trim().toUpperCase();
    if (trimmed.isEmpty) {
      return 'ITR acknowledgement number is required.';
    }
    if (!RegExp(r'^[A-Z0-9]{8,24}$').hasMatch(trimmed)) {
      return 'ITR acknowledgement format is invalid.';
    }
    return null;
  }

  static String? validatePan(String value) {
    final trimmed = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(trimmed)) {
      return 'PAN format invalid.';
    }
    return null;
  }

  static String? validateAnnualIncome(String value) {
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return 'Annual income must be a positive number.';
    }
    return null;
  }

  static bool withinFortyPercentTolerance({
    required double observed,
    required double baseline,
  }) {
    if (baseline <= 0) return true;
    final minAllowed = baseline * 0.60;
    final maxAllowed = baseline * 1.40;
    return observed >= minAllowed && observed <= maxAllowed;
  }
}
