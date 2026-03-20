import 'dart:developer' as developer;

import '../models/verified_profile.dart';

/// Frozen 95-feature vector for GigCredit LR meta-learner.
/// Feature indices are CONTRACT-FROZEN — do not reorder.
///
/// Pillar mapping (approximate):
///   P1 – Identity:       indices 0–8
///   P2 – Bank:           indices 9–25
///   P3 – Utility:        indices 26–32
///   P4 – Work:           indices 33–38
///   P5 – Scheme (gov):   indices 39–44
///   P6 – Insurance:      indices 45–52
///   P7 – Tax/GST:        indices 53–62
///   P8 – EMI/Loan:       indices 63–78
///   Derived ratios:      indices 79–94
class FeatureEngineering {
  static const int featureCount = 95;

  /// Build the 95-feature vector from a [VerifiedProfile].
  /// Returns a mutable list so callers can further transform before scoring.
  static List<double> buildFeatureVector(VerifiedProfile p) {
    final f = List<double>.filled(featureCount, 0.0);
    int fallbacks = 0;

    // ── P1: Identity (indices 0–8) ──────────────────────────────────────────
    f[0] = _clamp(p.age.toDouble(), 18, 70);             // age
    f[1] = p.aadhaarVerified ? 1 : 0;                    // aadhaar verified
    f[2] = p.panVerified ? 1 : 0;                        // PAN verified
    f[3] = p.faceVerified ? 1 : 0;                       // face verified
    f[4] = _clamp(p.faceMatchScore, 0, 1);               // face match score (0–1)
    f[5] = p.hasVehicle == true ? 1 : 0;                 // has vehicle
    f[6] = (p.numberOfDependents > 0) ? 1 : 0;          // has dependents
    f[7] = _clamp(p.numberOfDependents.toDouble(), 0, 10); // dependent count
    f[8] = p.workType != null ? 1 : 0;                   // work type declared

    // ── P2: Bank (indices 9–25) ──────────────────────────────────────────────
    f[9]  = p.bankVerified ? 1 : 0;                      // bank verified
    f[10] = _clamp(p.transactionCount.toDouble(), 0, 500); // transaction count
    f[11] = p.emiDetected ? 1 : 0;                       // EMI detected in bank
    f[12] = p.ifscCode.isNotEmpty ? 1 : 0;               // IFSC provided
    f[13] = p.accountNumberMasked.isNotEmpty ? 1 : 0;    // account number provided
    f[14] = _clamp(p.estimatedMonthlyIncome, 0, 500000); // estimated monthly income
    f[15] = _clamp(p.selfDeclaredMonthlyIncome, 0, 500000); // self-declared income
    f[16] = _clamp(p.monthlyEmiObligation, 0, 200000);   // monthly EMI total
    f[17] = _clamp(p.debtToIncomeRatio, 0, 5);           // DTI ratio
    f[18] = p.emiCandidateCount.toDouble();               // EMI candidate count
    // Income consistency: ratio of bank-derived to self-declared income
    f[19] = _safeRatio(p.estimatedMonthlyIncome, p.selfDeclaredMonthlyIncome, fallback: 0);
    // Statement coverage (days)
    if (p.statementFrom != null && p.statementTo != null) {
      f[20] = _clamp(p.statementTo!.difference(p.statementFrom!).inDays.toDouble(), 0, 365);
    }
    f[21] = p.secondaryIncomeAmount > 0 ? 1 : 0;        // has secondary income
    f[22] = _clamp(p.secondaryIncomeAmount, 0, 100000);  // secondary income amount
    f[23] = _clamp(p.yearsInCurrentProfession.toDouble(), 0, 40); // years in profession
    f[24] = p.vehicleOwnerMismatch ? 1 : 0;              // vehicle owner mismatch flag
    // Transaction density: txn count per month
    final months = f[20] / 30.0;
    f[25] = months > 0 ? _safeRatio(f[10], months) : 0;

    // ── P3: Utility (indices 26–32) ──────────────────────────────────────────
    f[26] = p.electricityVerified ? 1 : 0;
    f[27] = p.lpgVerified ? 1 : 0;
    f[28] = p.mobileUtilityVerified ? 1 : 0;
    f[29] = p.rentVerified ? 1 : 0;
    f[30] = p.wifiVerified ? 1 : 0;
    f[31] = p.ottVerified ? 1 : 0;
    // Utility breadth score: sum of mandatory utilities (3 max)
    f[32] = (f[26] + f[27] + f[28]).clamp(0, 3);

    // ── P4: Work Proof (indices 33–38) ───────────────────────────────────────
    f[33] = p.workProofProvided ? 1 : 0;
    f[34] = p.workProofVerified ? 1 : 0;
    f[35] = _clamp(p.yearsInCurrentProfession.toDouble(), 0, 40);
    // Work type code: 0=unknown,1=gig,2=freelancer,3=small_business,4=other
    f[36] = _workTypeCode(p.workType);
    // Platform worker strength: has work proof + verified + vehicle
    f[37] = (p.workProofVerified && p.hasVehicle == true) ? 1 : 0;
    // Self-employment signal: self-declared income > bank income (often under-reported)
    f[38] = p.selfDeclaredMonthlyIncome > p.estimatedMonthlyIncome ? 1 : 0;

    // ── P5: Government Schemes (indices 39–44) ───────────────────────────────
    f[39] = p.selectedSvanidhi ? 1 : 0;
    f[40] = p.selectedEShram ? 1 : 0;
    f[41] = p.selectedUdyam ? 1 : 0;
    f[42] = p.svanidhiVerified ? 1 : 0;
    f[43] = p.eShramVerified ? 1 : 0;
    f[44] = p.udyamVerified ? 1 : 0;

    // ── P6: Insurance (indices 45–52) ────────────────────────────────────────
    f[45] = p.selectedHealthInsurance ? 1 : 0;
    f[46] = p.selectedLifeInsurance ? 1 : 0;
    f[47] = p.selectedVehicleInsurance ? 1 : 0;
    f[48] = p.healthInsuranceVerified ? 1 : 0;
    f[49] = p.lifeInsuranceVerified ? 1 : 0;
    f[50] = p.vehicleInsuranceVerified ? 1 : 0;
    // Insurance breadth: count of verified types
    f[51] = (f[48] + f[49] + f[50]).clamp(0, 3);
    // Has any policy (at least selected)
    f[52] = (f[45] + f[46] + f[47] > 0) ? 1 : 0;

    // ── P7: Tax / GST (indices 53–62) ────────────────────────────────────────
    f[53] = p.selectedItr ? 1 : 0;
    f[54] = p.selectedGst ? 1 : 0;
    f[55] = p.itrVerified ? 1 : 0;
    f[56] = p.gstVerified ? 1 : 0;
    f[57] = _clamp(p.itrAnnualIncome, 0, 10000000);
    f[58] = _clamp(p.gstAnnualIncome, 0, 10000000);
    // ITR monthly equivalent
    f[59] = _safeRatio(p.itrAnnualIncome, 12);
    // GST monthly equivalent
    f[60] = _safeRatio(p.gstAnnualIncome, 12);
    // Has both tax documents
    f[61] = (p.itrVerified && p.gstVerified) ? 1 : 0;
    // ITR income vs self-declared consistency
    final itrMonthly = p.itrAnnualIncome / 12;
    f[62] = itrMonthly > 0
        ? _clamp((itrMonthly / (p.selfDeclaredMonthlyIncome + 1)).abs(), 0, 5)
        : 0;

    // ── P8: EMI / Loan (indices 63–78) ───────────────────────────────────────
    f[63] = p.emiCandidateCount.toDouble();
    f[64] = _clamp(p.monthlyEmiObligation, 0, 200000);
    f[65] = p.loanVerificationAttempted ? 1 : 0;
    f[66] = p.loanVerificationPassed ? 1 : 0;
    f[67] = _clamp(p.debtToIncomeRatio, 0, 5);
    // EMI to income ratio
    f[68] = _safeRatio(p.monthlyEmiObligation, p.estimatedMonthlyIncome + 1);
    // Risk band encoding: LOW=0, MEDIUM=1, HIGH=2
    f[69] = _emiBandCode(p.emiRiskBand);
    // Net disposable income (income - EMI)
    final disposable = p.estimatedMonthlyIncome - p.monthlyEmiObligation;
    f[70] = _clamp(disposable, -200000, 500000);
    // Disposable income ratio
    f[71] = _safeRatio(disposable.abs(), p.estimatedMonthlyIncome + 1);
    // Over-leveraged flag: DTI > 0.5
    f[72] = p.debtToIncomeRatio > 0.5 ? 1 : 0;
    // Severely over-leveraged: DTI > 0.75
    f[73] = p.debtToIncomeRatio > 0.75 ? 1 : 0;
    // No loan declared flag
    f[74] = (p.monthlyEmiObligation == 0) ? 1 : 0;
    // EMI density: emi candidates per 6 months (normalized)
    f[75] = _clamp((p.emiCandidateCount / 6.0), 0, 10);
    // Reserved for future loan amount
    f[76] = 0;
    f[77] = 0;
    f[78] = 0;

    // ── Derived Ratios (indices 79–94) ────────────────────────────────────────
    // Overall verification breadth score (count of positive verifications / 15 possible)
    final verifiedCount = <double>[
      f[1], f[2], f[3],   // identity
      f[9],                // bank
      f[26], f[27], f[28], // utilities
      f[34],               // work proof
      f[42], f[43], f[44], // schemes
      f[48], f[49], f[50], // insurance
      f[55], f[56],        // tax
    ].where((v) => v > 0).length.toDouble();
    f[79] = verifiedCount / 16.0;

    // Income source diversity: count of income sources confirmed
    final incomeSources = <double>[
      f[14] > 0 ? 1 : 0,  // bank income
      f[57] > 0 ? 1 : 0,  // ITR income
      f[58] > 0 ? 1 : 0,  // GST income
      f[22] > 0 ? 1 : 0,  // secondary income
    ].where((v) => v > 0).length.toDouble();
    f[80] = incomeSources / 4.0;

    // Document completeness ratio (all documents uploaded and verified)
    f[81] = _clamp((f[1] + f[2] + f[9] + f[55]) / 4.0, 0, 1);

    // Age score: prime creditworthy age is 25–55
    final age = p.age;
    f[82] = (age >= 25 && age <= 55) ? 1.0 : (age >= 20 && age <= 60) ? 0.5 : 0.0;

    // Work tenure score (normalized 0–1 over 10 years)
    f[83] = _clamp(p.yearsInCurrentProfession / 10.0, 0, 1);

    // KYC completeness: aadhaar + PAN + face all verified
    f[84] = (p.aadhaarVerified && p.panVerified && p.faceVerified) ? 1 : 0;

    // Positive government scheme signal (any verified)
    f[85] = (p.svanidhiVerified || p.eShramVerified || p.udyamVerified) ? 1 : 0;

    // Transaction volume adequacy (>= 60 transactions = adequate bank history)
    f[86] = p.transactionCount >= 60 ? 1 : (p.transactionCount >= 30 ? 0.5 : 0);

    // Income-EMI sustainability (passes 40% rule: EMI < 40% of income)
    f[87] = p.debtToIncomeRatio <= 0.4 ? 1 : 0;

    // Formal income signal: either ITR or GST verified
    f[88] = (p.itrVerified || p.gstVerified) ? 1 : 0;

    // Self-employment maturity: ITR + GST + work proof all verified
    f[89] = (p.itrVerified && p.gstVerified && p.workProofVerified) ? 1 : 0;

    // Utility coverage ratio: verified utilities / 6 possible
    f[90] = _clamp((f[26] + f[27] + f[28] + f[29] + f[30] + f[31]) / 6.0, 0, 1);

    // Income growth proxy: bank income vs ITR income (>1 = income growing)
    final itrMonthlyF = p.itrAnnualIncome > 0 ? p.itrAnnualIncome / 12 : 0;
    f[91] = itrMonthlyF > 0
        ? _clamp(p.estimatedMonthlyIncome / (itrMonthlyF + 1), 0, 5)
        : 0;

    // Overall positive signal concentration
    f[92] = _clamp((f[79] + f[80] + f[81]) / 3.0, 0, 1);

    // Risk index (inverse of positive signal)
    f[93] = 1.0 - f[92];

    // Reserved for external Dev A feature injection
    f[94] = 0;

    // ── Validate and log ─────────────────────────────────────────────────────
    assert(f.length == featureCount,
        'Feature vector length mismatch: expected $featureCount, got ${f.length}');

    for (int i = 0; i < f.length; i++) {
      if (f[i].isNaN || f[i].isInfinite) {
        developer.log('FeatureEngineering: fallback for f[$i] — was ${f[i]}');
        f[i] = 0.0;
        fallbacks++;
      }
    }

    if (fallbacks > 0) {
      developer.log('FeatureEngineering: $fallbacks fallback substitutions applied.');
    }

    return f;
  }

  static double _clamp(double v, double min, double max) {
    if (v.isNaN || v.isInfinite) return 0;
    return v < min ? min : (v > max ? max : v);
  }

  static double _safeRatio(double numerator, double denominator, {double fallback = 0}) {
    if (denominator == 0 || denominator.isNaN || numerator.isNaN) return fallback;
    final r = numerator / denominator;
    return r.isInfinite ? fallback : r;
  }

  static double _workTypeCode(dynamic workType) {
    if (workType == null) return 0;
    final name = workType.toString().toLowerCase();
    if (name.contains('gig') || name.contains('platform')) return 1;
    if (name.contains('freelan')) return 2;
    if (name.contains('business') || name.contains('shop')) return 3;
    return 4;
  }

  static double _emiBandCode(String band) {
    switch (band.toUpperCase()) {
      case 'LOW': return 0;
      case 'MEDIUM': return 1;
      case 'HIGH': return 2;
      default: return 0;
    }
  }
}
