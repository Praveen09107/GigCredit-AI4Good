class Step4Validators {
  static String? validateSixMonthCount({required int count, required String utilityName}) {
    if (count < 6) {
      return '$utilityName requires 6 uploads.';
    }
    return null;
  }

  static bool isSameIdentifierAcrossBills(List<String> identifiers) {
    if (identifiers.isEmpty) return false;
    final first = identifiers.first.trim().toUpperCase();
    return identifiers.every((id) => id.trim().toUpperCase() == first);
  }

  static bool looksNumericAmount(String value) {
    return RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value.trim());
  }
}
