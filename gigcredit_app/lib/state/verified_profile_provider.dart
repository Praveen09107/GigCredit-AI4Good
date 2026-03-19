import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/verified_profile.dart';
import '../models/enums/step_status.dart';
import '../models/enums/work_type.dart';
import '../core/session/secure_storage.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => const SecureStorage());

class VerifiedProfileNotifier extends StateNotifier<VerifiedProfile> {
    VerifiedProfileNotifier(this._secureStorage) : super(VerifiedProfile.initial()) {
        _restore();
    }

    final SecureStorage _secureStorage;

    Future<void> _restore() async {
        final saved = await _secureStorage.readProfile();
        if (saved != null) {
            state = saved;
        }
    }

    Future<void> updateBasicProfile({
        required String fullName,
        required String phoneNumber,
        required double monthlyIncome,
        required WorkType workType,
    }) async {
        state = state.copyWith(
            fullName: fullName,
            phoneNumber: phoneNumber,
            monthlyIncome: monthlyIncome,
            workType: workType,
            verificationState: {
                ...state.verificationState,
                StepId.step1Profile: StepStatus.verified,
            },
            currentStep: StepId.step2Identity,
        );
        await _secureStorage.saveProfile(state);
    }

    Future<void> setMinimumGate(bool passed) async {
        state = state.copyWith(minimumGatePassed: passed);
        await _secureStorage.saveProfile(state);
    }

    Future<void> markStep(StepId stepId, StepStatus status) async {
        final next = {...state.verificationState, stepId: status};
        state = state.copyWith(verificationState: next, currentStep: stepId);
        await _secureStorage.saveProfile(state);
    }

    Future<void> regenerateFeatures() async {
        final incomeNorm = (state.monthlyIncome / 100000).clamp(0.05, 1.0);
        final workBoost = 0.04 * state.workType.metaIndex;
        final vector = List<double>.generate(95, (index) {
            final harmonic = ((index % 10) / 10) * 0.18;
            final trend = (index / 95) * 0.12;
            final value = 0.30 + (incomeNorm * 0.42) + workBoost + harmonic + trend;
            return value.clamp(0.0, 1.0);
        });

        vector[36] = (0.70 - incomeNorm * 0.45).clamp(0.05, 0.95);

        state = state.copyWith(featureVector: vector);
        await _secureStorage.saveProfile(state);
    }

    Future<void> resetAll() async {
        state = VerifiedProfile.initial();
        await _secureStorage.clearProfile();
    }
}

final verifiedProfileProvider = StateNotifierProvider<VerifiedProfileNotifier, VerifiedProfile>((ref) {
    return VerifiedProfileNotifier(ref.read(secureStorageProvider));
});

