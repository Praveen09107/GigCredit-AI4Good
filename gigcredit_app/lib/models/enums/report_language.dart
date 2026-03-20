enum ReportLanguage {
  english,
  hindi,
  tamil,
}

extension ReportLanguageX on ReportLanguage {
  String get label {
    switch (this) {
      case ReportLanguage.english:
        return 'English';
      case ReportLanguage.hindi:
        return 'Hindi';
      case ReportLanguage.tamil:
        return 'Tamil';
    }
  }

  String get code {
    switch (this) {
      case ReportLanguage.english:
        return 'en';
      case ReportLanguage.hindi:
        return 'hi';
      case ReportLanguage.tamil:
        return 'ta';
    }
  }
}
