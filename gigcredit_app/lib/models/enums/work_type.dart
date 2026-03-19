enum WorkType {
  platformWorker,
  vendor,
  tradesperson,
  freelancer,
}

extension WorkTypeX on WorkType {
  int get metaIndex {
    switch (this) {
      case WorkType.platformWorker:
        return 0;
      case WorkType.vendor:
        return 1;
      case WorkType.tradesperson:
        return 2;
      case WorkType.freelancer:
        return 3;
    }
  }

  String get label {
    switch (this) {
      case WorkType.platformWorker:
        return 'Platform Worker';
      case WorkType.vendor:
        return 'Vendor';
      case WorkType.tradesperson:
        return 'Tradesperson';
      case WorkType.freelancer:
        return 'Freelancer';
    }
  }
}
