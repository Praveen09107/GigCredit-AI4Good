import 'dart:developer' as developer;

import '../../models/bank_transaction.dart';

/// A detected recurring EMI-like debit pattern.
class DetectedEmi {
  const DetectedEmi({
    required this.description,
    required this.normalizedAmount,
    required this.occurrences,
    required this.intervalDays,
    required this.monthlyAmount,
    required this.confidence,
  });

  /// Cleaned description of the debit narrative (e.g. "HDFC LOAN EMI")
  final String description;

  /// Median debit amount across occurrences
  final double normalizedAmount;

  /// Number of times this pattern was seen
  final int occurrences;

  /// Average days between occurrences
  final double intervalDays;

  /// Annualized monthly equivalent (normalizedAmount if monthly, or scaled)
  final double monthlyAmount;

  /// Confidence score 0–1 (1.0 = perfectly monthly recurring, at equal amounts)
  final double confidence;

  bool get isMonthly => intervalDays >= 25 && intervalDays <= 35;

  @override
  String toString() =>
      'DetectedEmi(desc=$description, amount=$normalizedAmount, occ=$occurrences, '
      'interval=${intervalDays.toStringAsFixed(1)}d, conf=${(confidence * 100).toStringAsFixed(0)}%)';
}

/// EmiDetector — finds recurring monthly debit patterns from a list of bank transactions.
///
/// Algorithm:
///   1. Filter only DEBIT transactions.
///   2. Group by normalized description key.
///   3. For each group with ≥2 occurrences:
///      a. Compute intervals between consecutive transactions.
///      b. If median interval is 25–35 days (monthly) → candidate EMI.
///      c. Compute amount variance; stable amount → higher confidence.
///   4. Rank by confidence descending.
///   5. Return EMI list above minimum confidence threshold.
class EmiDetector {
  const EmiDetector({
    this.minOccurrences = 2,
    this.minConfidence = 0.55,
    this.monthlyDaysMin = 25,
    this.monthlyDaysMax = 35,
  });

  final int minOccurrences;
  final double minConfidence;
  final double monthlyDaysMin;
  final double monthlyDaysMax;

  /// Detect recurring EMI patterns from a transaction list.
  List<DetectedEmi> detect(List<BankTransaction> transactions) {
    // Only work on debit transactions
    final debits = transactions.where((t) => t.type == 'DEBIT').toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (debits.length < minOccurrences) return const <DetectedEmi>[];

    // Group by description key
    final groups = <String, List<BankTransaction>>{};
    for (final txn in debits) {
      final key = _normalizeDescription(txn.description);
      groups.putIfAbsent(key, () => <BankTransaction>[]).add(txn);
    }

    final candidates = <DetectedEmi>[];

    for (final entry in groups.entries) {
      final key = entry.key;
      final txns = entry.value;

      if (txns.length < minOccurrences) continue;

      // Sort by date
      final sorted = txns..sort((a, b) => a.date.compareTo(b.date));

      // Compute day intervals
      final intervals = <int>[];
      for (int i = 1; i < sorted.length; i++) {
        intervals.add(sorted[i].date.difference(sorted[i - 1].date).inDays);
      }

      final medianInterval = _median(intervals.map((e) => e.toDouble()).toList());

      // Must be monthly pattern
      if (medianInterval < monthlyDaysMin || medianInterval > monthlyDaysMax) continue;

      // Amount stability
      final amounts = sorted.map((t) => t.amount).toList();
      final medianAmount = _median(amounts);
      final amountVariance = _coefficientOfVariation(amounts);

      // Confidence formula:
      // - Base from interval closeness to 30 days
      // - Penalized by amount variance
      // - Boosted by occurrence count
      final intervalScore = 1.0 - (medianInterval - 30.0).abs() / 30.0;
      final amountScore = (1.0 - amountVariance).clamp(0.0, 1.0);
      final occurrenceScore = (txns.length / 6.0).clamp(0.0, 1.0);
      final confidence = (intervalScore * 0.4 + amountScore * 0.4 + occurrenceScore * 0.2)
          .clamp(0.0, 1.0);

      if (confidence < minConfidence) continue;

      final emi = DetectedEmi(
        description: key,
        normalizedAmount: medianAmount,
        occurrences: txns.length,
        intervalDays: medianInterval,
        monthlyAmount: medianAmount, // already monthly
        confidence: confidence,
      );

      developer.log('EmiDetector: candidate → $emi');
      candidates.add(emi);
    }

    // Sort by confidence descending
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return List<DetectedEmi>.unmodifiable(candidates);
  }

  /// Total monthly obligation from all detected EMIs.
  double totalMonthlyObligation(List<DetectedEmi> emis) {
    return emis.fold<double>(0, (sum, e) => sum + e.monthlyAmount);
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Normalize description to a grouping key.
  /// Strips transaction references (numbers), keeps merchant/type signal.
  String _normalizeDescription(String raw) {
    String key = raw.toUpperCase();

    // Strip UPI reference numbers (e.g. /P2A/519739896895/)
    key = key.replaceAll(RegExp(r'/\d{10,}/'), '/REF/');
    key = key.replaceAll(RegExp(r'\b\d{9,}\b'), '');

    // Strip common noise
    key = key
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^A-Z0-9/ ]'), '')
        .trim();

    // Keep up to first meaningful words (EMI/LOAN descriptions)
    final emiKeywords = ['EMI', 'LOAN', 'NACH', 'MANDATE', 'ECS', 'LIC', 'INSURANCE', 'SIP'];
    for (final kw in emiKeywords) {
      if (key.contains(kw)) {
        // Use keyword + adjacent words as the key
        final idx = key.indexOf(kw);
        final start = idx > 0 ? (idx - 15).clamp(0, idx) : 0;
        final end = (idx + kw.length + 20).clamp(0, key.length);
        key = key.substring(start, end).trim();
        break;
      }
    }

    // Fallback: take first 50 chars
    if (key.length > 50) key = key.substring(0, 50).trim();
    return key;
  }

  double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// Coefficient of variation = stddev / mean (normalized variability 0–∞)
  double _coefficientOfVariation(List<double> values) {
    if (values.length < 2) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    if (mean == 0) return 0;
    final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
    return (variance == 0) ? 0 : (variance.abs() < 1e-10 ? 0 : (variance == 0 ? 0 : _sqrt(variance) / mean));
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}
