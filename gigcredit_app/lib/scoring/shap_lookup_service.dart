import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/services.dart' show rootBundle;

import '../config/app_mode.dart';
import '../models/verified_profile.dart';
import 'scoring_pipeline.dart';

class ShapExplanation {
  const ShapExplanation({
    required this.positiveDriverKeys,
    required this.negativeDriverKeys,
    required this.driverImpacts,
  });

  final List<String> positiveDriverKeys;
  final List<String> negativeDriverKeys;
  /// Raw impact values for each driver key, for rendering bars etc.
  final Map<String, double> driverImpacts;
}

/// SHAP-based explainability service.
/// Loads binned feature-level SHAP tables from `assets/constants/shap_lookup.json`.
/// In production-readiness mode, fallback heuristics are not allowed.
class ShapLookupService {
  ShapLookupService({Map<String, dynamic>? lookupOverride}) {
    if (lookupOverride != null && _parseLookupSchema(lookupOverride)) {
      _loaded = true;
    }
  }

  final ScoringPipeline _scoringPipeline = const ScoringPipeline();
  Map<String, Map<String, _BinnedShap>>? _lookup;
  bool _loaded = false;

  // ── Asset loading ─────────────────────────────────────────────────────────

  Future<void> loadWeights() async {
    if (_loaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/constants/shap_lookup.json');
      final raw = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (_parseLookupSchema(raw)) {
        final featureCount = _lookup!.values.fold<int>(
          0,
          (sum, featureMap) => sum + featureMap.length,
        );
        developer.log('ShapLookupService: loaded binned SHAP lookup with $featureCount features.');
      } else {
        throw StateError('SHAP lookup schema invalid. Expected binned lookup format.');
      }
    } catch (e) {
      throw StateError('SHAP lookup asset is missing or invalid: $e');
    }
    _loaded = true;
  }

  // ── Explain ───────────────────────────────────────────────────────────────

  /// Compute explanations for a given [VerifiedProfile].
  /// Call [loadWeights] before using this method, or call [explainAsync].
  ShapExplanation explain(
    VerifiedProfile profile, {
    List<double>? featureVector95,
  }) {
    if (_lookup == null || _lookup!.isEmpty) {
      throw StateError('SHAP lookup data unavailable.');
    }
    return _explainFromBinnedLookup(
      featureVector95 ?? _scoringPipeline.buildSanitizedVector95(profile),
    );
  }

  ShapExplanation _explainFromBinnedLookup(List<double> vector95) {
    final impacts = <String, double>{};

    _lookup!.forEach((_, features) {
      features.forEach((featureKey, bins) {
        final featureIndex = _featureIndex(featureKey);
        if (featureIndex == null || featureIndex < 0 || featureIndex >= vector95.length) {
          return;
        }

        final value = vector95[featureIndex];
        final impact = bins.lookup(value);
        if (impact == 0) {
          return;
        }

        final driverKey = _driverKeyForFeature(featureKey, impact);
        impacts.update(driverKey, (existing) => existing + impact, ifAbsent: () => impact);
      });
    });

    final positives = impacts.entries.where((entry) => entry.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final negatives = impacts.entries.where((entry) => entry.value < 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return ShapExplanation(
      positiveDriverKeys: positives.take(4).map((entry) => entry.key).toList(growable: false),
      negativeDriverKeys: negatives.take(4).map((entry) => entry.key).toList(growable: false),
      driverImpacts: Map<String, double>.unmodifiable(impacts),
    );
  }

  bool _parseLookupSchema(Map<String, dynamic> raw) {
    final pillars = raw['pillars'];
    if (pillars is! Map<String, dynamic>) {
      return false;
    }

    final parsed = <String, Map<String, _BinnedShap>>{};
    for (final pillarEntry in pillars.entries) {
      final featureMapRaw = pillarEntry.value;
      if (featureMapRaw is! Map<String, dynamic>) {
        continue;
      }

      final featureMap = <String, _BinnedShap>{};
      for (final featureEntry in featureMapRaw.entries) {
        final binsRaw = featureEntry.value;
        if (binsRaw is! Map<String, dynamic>) {
          continue;
        }

        final edgesRaw = binsRaw['edges'];
        final shapRaw = binsRaw['shap'];
        if (edgesRaw is! List || shapRaw is! List || edgesRaw.length < 2 || shapRaw.isEmpty) {
          continue;
        }

        final edges = edgesRaw.whereType<num>().map((n) => n.toDouble()).toList(growable: false);
        final shap = shapRaw.whereType<num>().map((n) => n.toDouble()).toList(growable: false);
        if (edges.length < 2 || shap.isEmpty) {
          continue;
        }

        featureMap[featureEntry.key] = _BinnedShap(edges: edges, shap: shap);
      }

      if (featureMap.isNotEmpty) {
        parsed[pillarEntry.key] = featureMap;
      }
    }

    if (parsed.isEmpty) {
      return false;
    }

    _lookup = parsed;
    return true;
  }

  int? _featureIndex(String featureKey) {
    final match = RegExp(r'^f_(\d+)$').firstMatch(featureKey);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  String _driverKeyForFeature(String featureKey, double impact) {
    final direct = _featureDriverMap[featureKey];
    if (direct != null) {
      return direct;
    }

    final index = _featureIndex(featureKey);
    if (index == null) {
      return impact >= 0 ? 'bank_verified' : 'high_dti';
    }

    if (index <= 8) {
      return impact >= 0 ? 'aadhaar_verified' : 'no_face_verify';
    }
    if (index <= 25) {
      return impact >= 0 ? 'bank_verified' : 'low_transaction_depth';
    }
    if (index <= 32) {
      return impact >= 0 ? 'utility_coverage' : 'utility_coverage';
    }
    if (index <= 38) {
      return impact >= 0 ? 'work_verified' : 'no_work_proof';
    }
    if (index <= 44) {
      return impact >= 0 ? 'scheme_enrollment' : 'scheme_enrollment';
    }
    if (index <= 52) {
      return impact >= 0 ? 'insurance_verified' : 'insurance_verified';
    }
    if (index <= 62) {
      return impact >= 0 ? 'itr_verified' : 'no_tax_docs';
    }
    if (index <= 78) {
      return impact >= 0 ? 'bank_verified' : 'high_emi_burden';
    }
    return impact >= 0 ? 'bank_verified' : 'high_dti';
  }

  static const Map<String, String> _featureDriverMap = <String, String>{
    'f_01': 'aadhaar_verified',
    'f_02': 'pan_verified',
    'f_09': 'bank_verified',
    'f_10': 'low_transaction_depth',
    'f_17': 'high_dti',
    'f_34': 'work_verified',
    'f_51': 'insurance_verified',
    'f_55': 'itr_verified',
    'f_56': 'gst_verified',
    'f_68': 'high_emi_burden',
    'f_85': 'scheme_enrollment',
    'f_90': 'utility_coverage',
  };

  /// Async variant — loads weights from asset if not yet loaded.
  Future<ShapExplanation> explainAsync(
    VerifiedProfile profile, {
    List<double>? featureVector95,
  }) async {
    await loadWeights();
    return explain(profile, featureVector95: featureVector95);
  }
}

class _BinnedShap {
  const _BinnedShap({required this.edges, required this.shap});

  final List<double> edges;
  final List<double> shap;

  double lookup(double value) {
    if (value.isNaN || value.isInfinite || shap.isEmpty || edges.length < 2) {
      return 0;
    }

    var binIndex = 0;
    for (var i = 0; i < edges.length - 1; i++) {
      final low = edges[i];
      final high = edges[i + 1];
      final isLast = i == edges.length - 2;
      final inBin = isLast ? (value >= low && value <= high) : (value >= low && value < high);
      if (inBin) {
        binIndex = i;
        break;
      }

      if (value > high) {
        binIndex = i + 1;
      }
    }

    if (binIndex < 0) {
      binIndex = 0;
    }
    if (binIndex >= shap.length) {
      binIndex = shap.length - 1;
    }
    return shap[binIndex];
  }
}
