import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/verification_validation_engine.dart';
import '../../../config/app_mode.dart';
import '../../../core/files/document_picker.dart';
import '../../../core/security/request_signer.dart';
import '../../../core/validation/step1_validators.dart';
import '../../../core/validation/step7_validators.dart';
import '../../../models/enums/document_type.dart';
import '../../../services/backend_client.dart';
import '../../../services/document_pipeline_service.dart';
import '../../../state/verified_profile_provider.dart';
import '../../widgets/step_progress_header.dart';

class Step7InsuranceScreen extends ConsumerStatefulWidget {
  const Step7InsuranceScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  ConsumerState<Step7InsuranceScreen> createState() => _Step7InsuranceScreenState();
}

class _Step7InsuranceScreenState extends ConsumerState<Step7InsuranceScreen> {
  static final String _apiBaseUrl = AppMode.resolvedBackendBaseUrl;
  static const String _apiKey = String.fromEnvironment('GIGCREDIT_API_KEY');
  static const bool _requireProductionReadiness = AppMode.requireProductionReadiness;

  final _healthPolicyController = TextEditingController();
  final _lifePolicyController = TextEditingController();
  final _vehiclePolicyController = TextEditingController();

  final _healthHolderController = TextEditingController();
  final _lifeHolderController = TextEditingController();
  final _vehicleHolderController = TextEditingController();

  bool _healthSelected = false;
  bool _lifeSelected = false;
  bool _vehicleSelected = false;

  bool _healthUploaded = false;
  bool _lifeUploaded = false;
  bool _vehicleUploaded = false;

  String? _healthFilePath;
  String? _lifeFilePath;
  String? _vehicleFilePath;

  bool _healthOcrOk = false;
  bool _lifeOcrOk = false;
  bool _vehicleOcrOk = false;

  bool _healthVerified = false;
  bool _lifeVerified = false;
  bool _vehicleVerified = false;

  final _docPipeline = DocumentPipelineService();

  @override
  void dispose() {
    _healthPolicyController.dispose();
    _lifePolicyController.dispose();
    _vehiclePolicyController.dispose();
    _healthHolderController.dispose();
    _lifeHolderController.dispose();
    _vehicleHolderController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _validateInsuranceInputs({
    required String policyNumber,
    required String holderName,
    required String normalizedUserName,
  }) {
    final policyErr = Step7Validators.validatePolicyNumber(policyNumber);
    if (policyErr != null) return policyErr;

    final holderErr = Step7Validators.validateHolderName(holderName);
    if (holderErr != null) return holderErr;

    final holderNormalized = Step1Validators.normalizeName(holderName);
    if (holderNormalized != normalizedUserName) {
      return 'Policy holder name must match Step-1 profile name.';
    }

    return null;
  }

  Future<void> _upload(String type) async {
    final file = await DocumentPicker.pickSingle();
    if (file == null || !mounted) return;
    if (file.path == null || file.path!.isEmpty) {
      return _toast('Unable to access selected file locally.');
    }

    setState(() {
      if (type == 'health') {
        _healthUploaded = true;
        _healthFilePath = file.path;
      }
      if (type == 'life') {
        _lifeUploaded = true;
        _lifeFilePath = file.path;
      }
      if (type == 'vehicle') {
        _vehicleUploaded = true;
        _vehicleFilePath = file.path;
      }
    });

    _toast('Selected file: ${file.name}');
  }

  Future<void> _runOcr(String type, String normalizedUserName) async {
    if (type == 'health') {
      if (!_healthUploaded) return _toast('Upload health policy proof first.');
      final err = _validateInsuranceInputs(
        policyNumber: _healthPolicyController.text,
        holderName: _healthHolderController.text,
        normalizedUserName: normalizedUserName,
      );
      if (err != null) return _toast(err);
      final ok = await _extractAndValidateOcr(
        _healthFilePath,
        'health_insurance',
        expectedPolicyNumber: _healthPolicyController.text,
      );
      if (!mounted) return;
      return setState(() => _healthOcrOk = ok);
    }

    if (type == 'life') {
      if (!_lifeUploaded) return _toast('Upload life policy proof first.');
      final err = _validateInsuranceInputs(
        policyNumber: _lifePolicyController.text,
        holderName: _lifeHolderController.text,
        normalizedUserName: normalizedUserName,
      );
      if (err != null) return _toast(err);
      final ok = await _extractAndValidateOcr(
        _lifeFilePath,
        'life_insurance',
        expectedPolicyNumber: _lifePolicyController.text,
      );
      if (!mounted) return;
      return setState(() => _lifeOcrOk = ok);
    }

    if (!_vehicleUploaded) return _toast('Upload vehicle policy proof first.');
    final err = _validateInsuranceInputs(
      policyNumber: _vehiclePolicyController.text,
      holderName: _vehicleHolderController.text,
      normalizedUserName: normalizedUserName,
    );
    if (err != null) return _toast(err);
    final ok = await _extractAndValidateOcr(
      _vehicleFilePath,
      'vehicle_insurance',
      expectedPolicyNumber: _vehiclePolicyController.text,
    );
    if (!mounted) return;
    setState(() => _vehicleOcrOk = ok);
  }

  Future<bool> _extractAndValidateOcr(
    String? filePath,
    String hint, {
    required String expectedPolicyNumber,
  }) async {
    if (filePath == null || filePath.isEmpty) {
      _toast('Missing local file path for OCR. Re-upload and retry.');
      return false;
    }

    final policy = expectedPolicyNumber.trim().toUpperCase();

    final processed = await _docPipeline.processFile(
      filePath: filePath,
      documentType: DocumentType.insurance,
      validationContext: _buildValidationContext(policyNumber: policy),
    );
    final ok = processed.ocr.rawText.trim().isNotEmpty || processed.ocr.confidence >= 0.30;
    if (!ok) {
      _toast('OCR extraction failed. Please upload a clearer insurance document.');
      return false;
    }

    if (!processed.validation.passed) {
      _toast('Insurance document validation failed. Please upload a valid document.');
      return false;
    }

    final extractedPolicy = (processed.fields['policy_number'] ?? '').trim().toUpperCase();
    if (policy.isNotEmpty && extractedPolicy.isNotEmpty && extractedPolicy != 'UNKNOWN' && extractedPolicy != policy) {
      _toast('Policy number mismatch between input and OCR document.');
      return false;
    }

    _toast('Document pipeline completed successfully.');
    return true;
  }

  ValidationContext _buildValidationContext({required String policyNumber}) {
    final profile = ref.read(verifiedProfileProvider);
    final fullName = profile.fullName.trim();
    final apiFields = <String, String>{};
    if (policyNumber.isNotEmpty) {
      apiFields['policy_number'] = policyNumber;
    }

    return ValidationContext(
      stepTag: 'step7_insurance',
      requiredFields: const <String>['policy_number'],
      profile: VerifiedProfileSnapshot(
        fullName: fullName.isEmpty ? null : fullName,
      ),
      apiVerifiedFields: apiFields,
    );
  }

  Future<void> _verifyInsurance(String type) async {
    var verified = false;
    String policyNumber = '';
    var backendAttempted = false;

    if (type == 'health') {
      verified = _healthUploaded && _healthOcrOk;
      policyNumber = _healthPolicyController.text.trim().toUpperCase();
    } else if (type == 'life') {
      verified = _lifeUploaded && _lifeOcrOk;
      policyNumber = _lifePolicyController.text.trim().toUpperCase();
    } else if (type == 'vehicle') {
      verified = _vehicleUploaded && _vehicleOcrOk;
      policyNumber = _vehiclePolicyController.text.trim().toUpperCase();
    }

    if (verified && policyNumber.isNotEmpty && _apiBaseUrl.isNotEmpty && _apiKey.isNotEmpty) {
      backendAttempted = true;
      try {
        final client = BackendClient(
          baseUrl: _apiBaseUrl,
          apiKey: _apiKey,
          deviceId: 'dev_b_step7',
          signatureProvider: signatureProviderFromApiKey(_apiKey),
        );
        final resp = await client.verifyInsurance(policyNumber);
        final status = resp.status.toUpperCase();
        verified = status == 'FOUND' || status == 'OK' || status == 'VERIFIED' || status == 'ACTIVE';
      } catch (_) {
        verified = !_requireProductionReadiness;
      }
    } else if (_requireProductionReadiness && verified && policyNumber.isNotEmpty) {
      verified = false;
    }

    setState(() {
      if (type == 'health') _healthVerified = verified;
      if (type == 'life') _lifeVerified = verified;
      if (type == 'vehicle') _vehicleVerified = verified;
    });

    if (!verified) {
      if (_requireProductionReadiness && !backendAttempted) {
        _toast('Insurance backend verification is required in production mode.');
      } else {
        _toast('Insurance verification failed for $type. Check policy number and retry.');
      }
    }
  }

  void _completeStep() {
    final profile = ref.read(verifiedProfileProvider);
    final hasVehicle = profile.hasVehicle;
    final selectedVehicle = hasVehicle ? true : _vehicleSelected;

    if (hasVehicle && !selectedVehicle) {
      return _toast('Vehicle insurance is required because has_vehicle is true.');
    }

    if (_healthSelected && !_healthVerified) {
      return _toast('Complete health insurance upload, OCR and verification.');
    }
    if (_lifeSelected && !_lifeVerified) {
      return _toast('Complete life insurance upload, OCR and verification.');
    }
    if (selectedVehicle && !_vehicleVerified) {
      return _toast('Complete vehicle insurance upload, OCR and verification.');
    }

    final ok = ref.read(verifiedProfileProvider.notifier).completeStep7(
          selectedHealthInsurance: _healthSelected,
          selectedLifeInsurance: _lifeSelected,
          selectedVehicleInsurance: selectedVehicle,
          healthInsuranceVerified: _healthVerified,
          lifeInsuranceVerified: _lifeVerified,
          vehicleInsuranceVerified: _vehicleVerified,
        );

    if (!ok) {
      return _toast('Unable to complete Step-7. Check previous step status and required insurance conditions.');
    }

    widget.onContinue();
  }

  Widget _insuranceCard({
    required String type,
    required String title,
    required String subtitle,
    required bool selected,
    required ValueChanged<bool?>? onSelected,
    required TextEditingController policyController,
    required TextEditingController holderController,
    required bool uploaded,
    required bool ocrOk,
    required bool verified,
    required bool requiredByRule,
    required String normalizedUserName,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    requiredByRule ? '$title (Required)' : '$title (Optional)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Checkbox(value: selected, onChanged: onSelected),
              ],
            ),
            Text(subtitle),
            const SizedBox(height: 10),
            TextField(
              enabled: selected,
              controller: policyController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Policy Number'),
            ),
            const SizedBox(height: 10),
            TextField(
              enabled: selected,
              controller: holderController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Policy Holder Name'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton(
                  onPressed: selected ? () => _upload(type) : null,
                  child: const Text('Upload Proof'),
                ),
                OutlinedButton(
                  onPressed: selected ? () => _runOcr(type, normalizedUserName) : null,
                  child: const Text('Run OCR'),
                ),
                ElevatedButton(
                  onPressed: selected ? () => _verifyInsurance(type) : null,
                  child: const Text('Verify'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Status: Upload ${uploaded ? 'OK' : 'Pending'} | OCR ${ocrOk ? 'OK' : 'Pending'} | Verify ${verified ? 'OK' : 'Pending'}',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(verifiedProfileProvider);
    final normalizedUserName = profile.fullName.toUpperCase();
    final hasVehicle = profile.hasVehicle;
    final selectedVehicle = hasVehicle ? true : _vehicleSelected;

    return Scaffold(
      appBar: AppBar(title: const Text('Step 7 of 9 • Insurance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const StepProgressHeader(currentStep: 7),
          const SizedBox(height: 14),
          const Text('Health/Life are optional. Vehicle insurance is required when has_vehicle is true.'),
          const SizedBox(height: 12),
          _insuranceCard(
            type: 'health',
            title: 'Health Insurance',
            subtitle: 'Optional protection proof.',
            selected: _healthSelected,
            onSelected: (v) => setState(() => _healthSelected = v ?? false),
            policyController: _healthPolicyController,
            holderController: _healthHolderController,
            uploaded: _healthUploaded,
            ocrOk: _healthOcrOk,
            verified: _healthVerified,
            requiredByRule: false,
            normalizedUserName: normalizedUserName,
          ),
          _insuranceCard(
            type: 'life',
            title: 'Life Insurance',
            subtitle: 'Optional long-term protection proof.',
            selected: _lifeSelected,
            onSelected: (v) => setState(() => _lifeSelected = v ?? false),
            policyController: _lifePolicyController,
            holderController: _lifeHolderController,
            uploaded: _lifeUploaded,
            ocrOk: _lifeOcrOk,
            verified: _lifeVerified,
            requiredByRule: false,
            normalizedUserName: normalizedUserName,
          ),
          _insuranceCard(
            type: 'vehicle',
            title: 'Vehicle Insurance',
            subtitle: hasVehicle
                ? 'Mandatory because you declared vehicle ownership in Step-1.'
                : 'Optional if no vehicle ownership.',
            selected: selectedVehicle,
            onSelected: hasVehicle ? null : (v) => setState(() => _vehicleSelected = v ?? false),
            policyController: _vehiclePolicyController,
            holderController: _vehicleHolderController,
            uploaded: _vehicleUploaded,
            ocrOk: _vehicleOcrOk,
            verified: _vehicleVerified,
            requiredByRule: hasVehicle,
            normalizedUserName: normalizedUserName,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _completeStep,
            child: const Text('Continue to Step 8'),
          ),
        ],
      ),
    );
  }
}
