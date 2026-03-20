class Step1Validators {
  static String? validateFullName(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 3) return 'Full name must be at least 3 characters.';
    if (!RegExp(r'^[A-Za-z .]+$').hasMatch(trimmed)) {
      return 'Full name can only include alphabets, spaces, and dots.';
    }
    return null;
  }

  static String? validateAge(String value) {
    final age = int.tryParse(value.trim());
    if (age == null) return 'Age must be numeric.';
    if (age < 18 || age > 65) return 'Age must be between 18 and 65.';
    return null;
  }

  static DateTime? parseDob(String value) {
    String normalized = value.trim().replaceAll('-', '/').replaceAll('.', '/').replaceAll(' ', '/');
    final parts = normalized.split('/');
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;

    final parsed = DateTime.tryParse(
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
    );
    if (parsed == null) return null;
    if (parsed.day != day || parsed.month != month || parsed.year != year) return null;
    return parsed;
  }

  static int calculateAgeFromDob(DateTime dob, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    var age = now.year - dob.year;
    final hasBirthdayOccurred =
        now.month > dob.month || (now.month == dob.month && now.day >= dob.day);
    if (!hasBirthdayOccurred) {
      age -= 1;
    }
    return age;
  }

  static String? validateDateOfBirth(String value) {
    final dob = parseDob(value);
    if (dob == null) {
      return 'Date of birth must be in DD/MM/YYYY format.';
    }

    final age = calculateAgeFromDob(dob);
    if (age < 18 || age > 65) {
      return 'Age from date of birth must be between 18 and 65.';
    }
    return null;
  }

  static String? validateMobile(String value) {
    final trimmed = value.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(trimmed)) {
      return 'Mobile number must be 10 digits starting with 6 to 9.';
    }
    return null;
  }

  static String? validateStateOfResidence(String value) {
    if (value.trim().isEmpty) {
      return 'State of residence is required.';
    }
    return null;
  }

  static String? validateMonthlyIncome(String value) {
    final income = int.tryParse(value.trim());
    if (income == null || income <= 0) {
      return 'Monthly income must be a positive number.';
    }
    return null;
  }

  static String? validateYearsInCurrentProfession(String value) {
    final years = int.tryParse(value.trim());
    if (years == null) return 'Years in current profession must be numeric.';
    if (years < 0 || years > 40) return 'Years in current profession must be between 0 and 40.';
    return null;
  }

  static String? validateDependents(String value) {
    final dependents = int.tryParse(value.trim());
    if (dependents == null) return 'Number of dependents must be numeric.';
    if (dependents < 0 || dependents > 10) {
      return 'Number of dependents must be between 0 and 10.';
    }
    return null;
  }

  static String? validateSecondaryIncomeSource(String value, {required bool hasAmount}) {
    final trimmed = value.trim();
    if (hasAmount && trimmed.isEmpty) {
      return 'Enter secondary income source when amount is provided.';
    }
    return null;
  }

  static String? validateSecondaryIncomeAmount(String value, {required bool hasSource}) {
    final trimmed = value.trim();
    if (!hasSource && trimmed.isEmpty) {
      return null;
    }
    final amount = int.tryParse(trimmed);
    if (amount == null || amount <= 0) {
      return 'Secondary income amount must be a positive number.';
    }
    return null;
  }

  static String? validateAddress(String value, {required String fieldLabel}) {
    final trimmed = value.trim();
    if (trimmed.length < 10) return '$fieldLabel must be at least 10 characters.';
    return null;
  }

  static String normalizeName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z ]'), ' ');
    return cleaned.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  }

  static String normalizeAddress(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  static String? validateAddressRelationship(String currentAddress, String permanentAddress) {
    final current = normalizeAddress(currentAddress);
    final permanent = normalizeAddress(permanentAddress);

    if (current.isEmpty || permanent.isEmpty) {
      return 'Both addresses are required for relationship checks.';
    }

    if (current == permanent) {
      return null;
    }

    final currentTokens = current.split(' ').where((t) => t.isNotEmpty).toSet();
    final permanentTokens = permanent.split(' ').where((t) => t.isNotEmpty).toSet();
    final commonCount = currentTokens.intersection(permanentTokens).length;

    if (commonCount == 0) {
      return 'Current and permanent addresses appear unrelated. Please verify entries.';
    }

    return null;
  }
}
