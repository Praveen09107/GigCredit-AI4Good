class Step5Validators {
  static String? validateVehicleNumber(String value) {
    final normalized = value.trim().toUpperCase();
    // Simplified Indian vehicle pattern for prototype checks.
    if (!RegExp(r'^[A-Z]{2}\d{1,2}[A-Z]{1,3}\d{4}$').hasMatch(normalized)) {
      return 'Vehicle number format looks invalid (e.g., TN09AB1234).';
    }
    return null;
  }

  static String? validateSvanidhiId(String value) {
    final trimmed = value.trim().toUpperCase();
    if (!RegExp(r'^SVN\d{6,12}$').hasMatch(trimmed)) {
      return 'SVANidhi ID format invalid (e.g., SVN12345678).';
    }
    return null;
  }

  static String? validateFssai(String value) {
    final trimmed = value.trim();
    if (!RegExp(r'^\d{14}$').hasMatch(trimmed)) {
      return 'FSSAI must be exactly 14 digits.';
    }
    return null;
  }

  static String? validateSkillCertificateId(String value) {
    final trimmed = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2,8}-\d{4}-\d{3,10}$').hasMatch(trimmed)) {
      return 'Skill certificate ID format invalid (e.g., NSDC-2023-457892).';
    }
    return null;
  }

  static bool isBackendVerificationAccepted({
    required bool requireProductionReadiness,
    required bool backendVerified,
  }) {
    return !requireProductionReadiness || backendVerified;
  }
}
