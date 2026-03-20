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

  // Backward-compatible alias used in older integration slices.
  static const String legacyApiBaseUrl = String.fromEnvironment(
    'GIGCREDIT_API_BASE_URL',
    defaultValue: '',
  );

  // Production OCR acceptance threshold. Keep consistent across OCR engine and document pipeline.
  static double get ocrConfidenceThreshold {
    const raw = String.fromEnvironment(
      'GIGCREDIT_OCR_CONFIDENCE_THRESHOLD',
      defaultValue: '0.85',
    );
    final parsed = double.tryParse(raw.trim());
    if (parsed == null || parsed.isNaN || parsed.isInfinite) {
      return 0.85;
    }
    return parsed.clamp(0.0, 1.0);
  }

  static String get resolvedBackendBaseUrl {
    final primary = backendBaseUrl.trim();
    if (primary.isNotEmpty) {
      return primary;
    }
    return legacyApiBaseUrl.trim();
  }

  static bool get backendConfigured {
    final normalized = resolvedBackendBaseUrl.toLowerCase();
    return normalized.startsWith('https://') || normalized.startsWith('http://');
  }
}
