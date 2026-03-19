class AppMode {
  const AppMode._();

  static const bool requireProductionReadiness = bool.fromEnvironment(
    'GIGCREDIT_REQUIRE_PRODUCTION_READINESS',
    defaultValue: false,
  );

  static const String backendBaseUrl = String.fromEnvironment(
    'GIGCREDIT_BACKEND_BASE_URL',
    defaultValue: '',
  );

  static bool get backendConfigured {
    final normalized = backendBaseUrl.trim().toLowerCase();
    return normalized.startsWith('https://') || normalized.startsWith('http://');
  }
}
