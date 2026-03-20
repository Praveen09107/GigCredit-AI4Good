class Step9Validators {
  static String? validateLender(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Lender name is required.';
    if (trimmed.length < 2) return 'Lender name is too short.';
    return null;
  }

  static String? validateMonthlyAmount(String value) {
    final amount = double.tryParse(value.trim());
    if (amount == null || amount <= 0) {
      return 'EMI amount must be a positive number.';
    }
    return null;
  }

  static bool isMonthlyRecurring({
    required DateTime previousDebitDate,
    required DateTime latestDebitDate,
  }) {
    final diff = latestDebitDate.difference(previousDebitDate).inDays.abs();
    return diff >= 24 && diff <= 40;
  }

  static String riskBandFromDti(double dti) {
    if (dti <= 0.25) return 'LOW';
    if (dti <= 0.45) return 'MEDIUM';
    return 'HIGH';
  }

  static bool fallbackLoanHookPass(String lenderName) {
    final normalized = lenderName.trim().toLowerCase();
    return normalized.length > 2 && !normalized.contains('test');
  }

  static String? strictModeLoanGateError({
    required bool requireProductionReadiness,
    required bool loanVerificationPassed,
  }) {
    if (requireProductionReadiness && !loanVerificationPassed) {
      return 'Loan backend verification is required in production mode.';
    }
    return null;
  }
}
