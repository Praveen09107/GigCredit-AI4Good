import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_mode.dart';
import '../../../core/files/document_picker.dart';
import '../../../core/security/request_signer.dart';
import '../../../core/validation/step5_validators.dart';
import '../../../models/enums/work_type.dart';
import '../../../services/backend_client.dart';
import '../../../services/ondevice_ocr_service.dart';
import '../../../state/verified_profile_provider.dart';
import '../../widgets/step_progress_header.dart';

class Step5WorkProofScreen extends ConsumerStatefulWidget {
  const Step5WorkProofScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  ConsumerState<Step5WorkProofScreen> createState() => _Step5WorkProofScreenState();
}

class _Step5WorkProofScreenState extends ConsumerState<Step5WorkProofScreen> {
  static final String _apiBaseUrl = AppMode.resolvedBackendBaseUrl;
  static const String _apiKey = String.fromEnvironment('GIGCREDIT_API_KEY');
  static const bool _requireProductionReadiness = AppMode.requireProductionReadiness;

  final _vehicleNumberController = TextEditingController();
  final _svanidhiController = TextEditingController();
  final _fssaiController = TextEditingController();
  final _skillCertController = TextEditingController();
  final _invoiceCountController = TextEditingController(text: '0');

  bool _platformProofUploaded = false;
  bool _platformRcUploaded = false;
  bool _platformInsuranceUploaded = false;
  bool _vendorProofUploaded = false;
  bool _tradesProofUploaded = false;
  bool _freelancerProfileUploaded = false;
  bool _freelancerInvoiceUploaded = false;
  bool _msmeProofUploaded = false;
  bool _verifyingVehicleRc = false;

  String? _platformProofPath;
  String? _platformRcPath;
  String? _platformInsurancePath;
  String? _vendorProofPath;
  String? _tradesProofPath;
  String? _freelancerProfilePath;
  String? _freelancerInvoicePath;
  String? _msmeProofPath;

  final _ocrService = const OnDeviceOcrService();

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _svanidhiController.dispose();
    _fssaiController.dispose();
    _skillCertController.dispose();
    _invoiceCountController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _uploadWorkProof(String type) async {
    final file = await DocumentPicker.pickSingle();
    if (file == null || !mounted) return;
    if (file.path == null || file.path!.trim().isEmpty) {
      _toast('Unable to access selected file locally.');
      return;
    }

    final path = file.path!;

    setState(() {
      if (type == 'platform') {
        _platformProofUploaded = true;
        _platformProofPath = path;
      }
      if (type == 'platform_rc') {
        _platformRcUploaded = true;
        _platformRcPath = path;
      }
      if (type == 'platform_insurance') {
        _platformInsuranceUploaded = true;
        _platformInsurancePath = path;
      }
      if (type == 'vendor') {
        _vendorProofUploaded = true;
        _vendorProofPath = path;
      }
      if (type == 'trades') {
        _tradesProofUploaded = true;
        _tradesProofPath = path;
      }
      if (type == 'freelancer_profile') {
        _freelancerProfileUploaded = true;
        _freelancerProfilePath = path;
      }
      if (type == 'freelancer_invoice') {
        _freelancerInvoiceUploaded = true;
        _freelancerInvoicePath = path;
      }
      if (type == 'freelancer_msme') {
        _msmeProofUploaded = true;
        _msmeProofPath = path;
      }
    });

    _toast('Selected file: ${file.name}');
  }

  void _skipStep() {
    ref.read(verifiedProfileProvider.notifier).completeStep5(
          workProofProvided: false,
          workProofVerified: false,
          vehicleOwnerMismatch: false,
        );
    widget.onContinue();
  }

  Future<bool> _verifyVehicleRc(String vehicleNumber) async {
    if (_apiBaseUrl.isEmpty || _apiKey.isEmpty) {
      return false;
    }

    try {
      final client = BackendClient(
        baseUrl: _apiBaseUrl,
        apiKey: _apiKey,
        deviceId: 'dev_b_step5_vehicle',
        signatureProvider: signatureProviderFromApiKey(_apiKey),
      );
      final resp = await client.verifyVehicleRc(vehicleNumber).timeout(const Duration(seconds: 5));
      final status = resp.status.toUpperCase();
      return status == 'SUCCESS' || status == 'FOUND' || status == 'OK' || status == 'VERIFIED';
    } catch (_) {
      return false;
    }
  }

  Future<bool> _postVerification(String path, Map<String, dynamic> payload) async {
    if (_apiBaseUrl.isEmpty || _apiKey.isEmpty) {
      return false;
    }

    try {
      final client = BackendClient(
        baseUrl: _apiBaseUrl,
        apiKey: _apiKey,
        deviceId: 'dev_b_step5',
        signatureProvider: signatureProviderFromApiKey(_apiKey),
      );
      final resp = await client.postJson(path, payload).timeout(const Duration(seconds: 6));
      final status = resp.status.toUpperCase();
      return status == 'SUCCESS' || status == 'FOUND' || status == 'OK' || status == 'VERIFIED' || status == 'ACTIVE';
    } catch (_) {
      return false;
    }
  }

  Future<String> _extractOcrText(String? path, String label) async {
    if (path == null || path.trim().isEmpty) {
      return '';
    }
    final result = await _ocrService.extractFromFile(filePath: path, docHint: label);
    return result.rawText.trim();
  }

  String _norm(String input) {
    return input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  bool _containsToken(String haystack, String token) {
    if (token.trim().isEmpty) {
      return true;
    }
    final h = _norm(haystack);
    final t = _norm(token);
    if (h.isEmpty || t.isEmpty) {
      return false;
    }
    return h.contains(t);
  }

  bool _containsAnyKeyword(String text, List<String> keywords) {
    final normalized = text.toLowerCase();
    for (final keyword in keywords) {
      if (normalized.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  Future<void> _completeStep() async {
    final profile = ref.read(verifiedProfileProvider);
    final workType = profile.workType;

    if (workType == null) {
      _toast('Work type unavailable. Complete Step-1 first.');
      return;
    }

    bool provided = false;
    bool verified = false;
    bool vehicleOwnerMismatch = false;

    if (workType == WorkType.platformWorker) {
      provided = _vehicleNumberController.text.trim().isNotEmpty ||
          _platformProofUploaded ||
          _platformRcUploaded ||
          _platformInsuranceUploaded;
      if (!provided) {
        return _skipStep();
      }

      final vehicleNumber = _vehicleNumberController.text.trim().toUpperCase();
      final vehicleErr = Step5Validators.validateVehicleNumber(vehicleNumber);
      if (vehicleErr != null) {
        _toast(vehicleErr);
        return;
      }

      if (!_platformRcUploaded) {
        _toast('Upload RC proof for platform-driver verification.');
        return;
      }

      if (!_platformProofUploaded) {
        _toast('Upload platform screenshot proof to continue.');
        return;
      }

      if (_requireProductionReadiness && (!AppMode.backendConfigured || _apiKey.isEmpty)) {
        _toast('Vehicle RC backend verification is required in production mode. Configure backend and API key.');
        return;
      }

      setState(() => _verifyingVehicleRc = true);
      final backendVerified = await _verifyVehicleRc(vehicleNumber);
      if (!mounted) return;
      setState(() {
        _verifyingVehicleRc = false;
        _vehicleNumberController.text = vehicleNumber;
      });

      verified = Step5Validators.isBackendVerificationAccepted(
        requireProductionReadiness: _requireProductionReadiness,
        backendVerified: backendVerified,
      );

      if (!verified) {
        _toast('Vehicle RC backend verification is required in production mode.');
        return;
      }

      final rcText = await _extractOcrText(_platformRcPath, 'rc_book');
      if (rcText.isEmpty || !_containsToken(rcText, vehicleNumber)) {
        _toast('RC OCR validation failed: vehicle number not found or unreadable.');
        return;
      }

      if (_platformInsuranceUploaded) {
        final insuranceText = await _extractOcrText(_platformInsurancePath, 'vehicle_insurance');
        if (insuranceText.isEmpty || !_containsToken(insuranceText, vehicleNumber)) {
          _toast('Vehicle insurance OCR validation failed: vehicle number mismatch.');
          return;
        }
      }

      final platformText = await _extractOcrText(_platformProofPath, 'platform_screenshot');
      if (platformText.isEmpty ||
          !_containsAnyKeyword(platformText, <String>['ride', 'earning', 'order', 'payout', 'bank', 'deposit'])) {
        _toast('Platform screenshot OCR validation failed: expected earnings/payout signals missing.');
        return;
      }

      if (!profile.bankVerified) {
        _toast('Step-3 bank verification is required before platform payout cross-validation.');
        return;
      }

      // Per spec correction: owner name mismatch should not hard-fail platform workers.
      vehicleOwnerMismatch = true;
      if (backendVerified) {
        _toast('Vehicle RC verified via backend.');
      } else {
        _toast('Vehicle proof accepted in integration mode (backend unavailable).');
      }
    } else if (workType == WorkType.vendor) {
      provided = _svanidhiController.text.trim().isNotEmpty ||
          _fssaiController.text.trim().isNotEmpty ||
          _vendorProofUploaded;
      if (!provided) {
        return _skipStep();
      }

      if (_svanidhiController.text.trim().isNotEmpty) {
        final err = Step5Validators.validateSvanidhiId(_svanidhiController.text);
        if (err != null) return _toast(err);
      }

      if (_fssaiController.text.trim().isNotEmpty) {
        final err = Step5Validators.validateFssai(_fssaiController.text);
        if (err != null) return _toast(err);
      }

      if (_svanidhiController.text.trim().isNotEmpty) {
        final backend = await _postVerification('/verify/svanidhi', <String, dynamic>{
          'identifier': _svanidhiController.text.trim().toUpperCase(),
        });
        if (_requireProductionReadiness && !backend) {
          _toast('SVANidhi backend verification is required in production mode.');
          return;
        }
      }

      if (_fssaiController.text.trim().isNotEmpty) {
        final backend = await _postVerification('/verify/fssai', <String, dynamic>{
          'identifier': _fssaiController.text.trim(),
        });
        if (_requireProductionReadiness && !backend) {
          _toast('FSSAI backend verification is required in production mode.');
          return;
        }
      }

      if (_vendorProofUploaded) {
        final vendorText = await _extractOcrText(_vendorProofPath, 'vendor_proof');
        if (vendorText.isEmpty) {
          _toast('Vendor proof OCR extraction failed. Upload a clearer document.');
          return;
        }
        if (_svanidhiController.text.trim().isNotEmpty &&
            !_containsToken(vendorText, _svanidhiController.text.trim())) {
          _toast('SVANidhi ID mismatch between input and vendor document OCR.');
          return;
        }
        if (_fssaiController.text.trim().isNotEmpty &&
            !_containsToken(vendorText, _fssaiController.text.trim())) {
          _toast('FSSAI number mismatch between input and vendor document OCR.');
          return;
        }
      }

      if (!_vendorProofUploaded &&
          _svanidhiController.text.trim().isEmpty &&
          _fssaiController.text.trim().isEmpty) {
        _toast('Provide at least one vendor ID or one vendor proof document.');
        return;
      }

      verified = true;
    } else if (workType == WorkType.tradesperson) {
      provided = _skillCertController.text.trim().isNotEmpty ||
          _fssaiController.text.trim().isNotEmpty ||
          _tradesProofUploaded;
      if (!provided) {
        return _skipStep();
      }

      if (_skillCertController.text.trim().isNotEmpty) {
        final err = Step5Validators.validateSkillCertificateId(_skillCertController.text);
        if (err != null) return _toast(err);
      }

      if (_fssaiController.text.trim().isNotEmpty) {
        final err = Step5Validators.validateFssai(_fssaiController.text);
        if (err != null) return _toast(err);
      }

      if (_skillCertController.text.trim().isNotEmpty) {
        final backend = await _postVerification('/verify/skill', <String, dynamic>{
          'identifier': _skillCertController.text.trim().toUpperCase(),
        });
        if (_requireProductionReadiness && !backend) {
          _toast('Skill certificate backend verification is required in production mode.');
          return;
        }
      }

      if (_fssaiController.text.trim().isNotEmpty) {
        final backend = await _postVerification('/verify/fssai', <String, dynamic>{
          'identifier': _fssaiController.text.trim(),
        });
        if (_requireProductionReadiness && !backend) {
          _toast('FSSAI backend verification is required in production mode.');
          return;
        }
      }

      if (_tradesProofUploaded) {
        final tradesText = await _extractOcrText(_tradesProofPath, 'trades_proof');
        if (tradesText.isEmpty) {
          _toast('Trades proof OCR extraction failed. Upload a clearer document.');
          return;
        }
        if (_skillCertController.text.trim().isNotEmpty &&
            !_containsToken(tradesText, _skillCertController.text.trim())) {
          _toast('Skill certificate ID mismatch between input and trades OCR.');
          return;
        }
        if (_fssaiController.text.trim().isNotEmpty &&
            !_containsToken(tradesText, _fssaiController.text.trim())) {
          _toast('FSSAI number mismatch between input and trades OCR.');
          return;
        }
      }

      if (!_tradesProofUploaded &&
          _skillCertController.text.trim().isEmpty &&
          _fssaiController.text.trim().isEmpty) {
        _toast('Provide at least one tradesperson ID or one proof document.');
        return;
      }

      verified = true;
    } else {
      final invoiceCount = int.tryParse(_invoiceCountController.text.trim()) ?? 0;
      provided = _freelancerProfileUploaded || _freelancerInvoiceUploaded || _msmeProofUploaded;
      if (!provided) {
        return _skipStep();
      }

      if (!_freelancerProfileUploaded) {
        return _toast('Upload freelancer profile proof first.');
      }
      if (!_freelancerInvoiceUploaded || invoiceCount < 1) {
        return _toast('Upload at least one freelancer invoice proof.');
      }
      if (!_msmeProofUploaded) {
        return _toast('Upload MSME certificate for freelancer verification.');
      }

      final profileText = await _extractOcrText(_freelancerProfilePath, 'freelancer_profile');
      final invoiceText = await _extractOcrText(_freelancerInvoicePath, 'freelancer_invoice');
      final msmeText = await _extractOcrText(_msmeProofPath, 'freelancer_msme');

      if (profileText.isEmpty || invoiceText.isEmpty || msmeText.isEmpty) {
        return _toast('Freelancer document OCR extraction failed. Upload clearer files.');
      }

      if (!_containsAnyKeyword(invoiceText, <String>['invoice', 'amount', 'date', 'payment'])) {
        return _toast('Freelancer invoice OCR validation failed.');
      }

      verified = true;
    }

    final ok = ref.read(verifiedProfileProvider.notifier).completeStep5(
          workProofProvided: provided,
          workProofVerified: verified,
          vehicleOwnerMismatch: vehicleOwnerMismatch,
        );

    if (!ok) {
      _toast('Unable to complete Step-5. Verify Step-4 status and work-proof consistency.');
      return;
    }

    widget.onContinue();
  }

  Widget _platformSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _vehicleNumberController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Vehicle Number'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => _uploadWorkProof('platform_rc'),
          child: Text(_platformRcUploaded ? 'RC proof uploaded' : 'Upload RC Book'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => _uploadWorkProof('platform_insurance'),
          child: Text(_platformInsuranceUploaded
              ? 'Vehicle insurance uploaded'
              : 'Upload Vehicle Insurance (optional in Step-5)'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => _uploadWorkProof('platform'),
          child: Text(_platformProofUploaded ? 'Platform proof uploaded' : 'Upload Platform Screenshots'),
        ),
        const SizedBox(height: 6),
        const Text('Vehicle owner name mismatch is allowed per spec.'),
      ],
    );
  }

  Widget _vendorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _svanidhiController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'SVANidhi ID (optional)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _fssaiController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'FSSAI Number (optional)'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => _uploadWorkProof('vendor'),
          child: Text(_vendorProofUploaded ? 'Vendor proof uploaded' : 'Upload Vendor Work Proof'),
        ),
      ],
    );
  }

  Widget _tradesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _skillCertController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Skill Certificate ID (optional)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _fssaiController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'FSSAI Number (optional)'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => _uploadWorkProof('trades'),
          child: Text(_tradesProofUploaded ? 'Trades proof uploaded' : 'Upload Trades Work Proof'),
        ),
      ],
    );
  }

  Widget _freelancerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Upload profile proof, invoice proof, and MSME certificate.'),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => _uploadWorkProof('freelancer_profile'),
          child: Text(_freelancerProfileUploaded
              ? 'Freelancer profile proof uploaded'
              : 'Upload Freelancer Profile Proof'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => _uploadWorkProof('freelancer_invoice'),
          child: Text(_freelancerInvoiceUploaded
              ? 'Freelancer invoice proof uploaded'
              : 'Upload Freelancer Invoice Proof'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _invoiceCountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Invoice proof count'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => _uploadWorkProof('freelancer_msme'),
          child: Text(_msmeProofUploaded ? 'MSME certificate uploaded' : 'Upload MSME Certificate'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(verifiedProfileProvider);
    final workType = profile.workType;

    Widget body;
    if (workType == WorkType.platformWorker) {
      body = _platformSection();
    } else if (workType == WorkType.vendor) {
      body = _vendorSection();
    } else if (workType == WorkType.tradesperson) {
      body = _tradesSection();
    } else if (workType == WorkType.freelancer) {
      body = _freelancerSection();
    } else {
      body = const Text('Work proof module unavailable for selected work type. You can skip.');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Step 5 of 9 • Work Proof')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const StepProgressHeader(currentStep: 5),
          const SizedBox(height: 14),
          Text('Work Type: ${workType?.label ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          body,
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _skipStep,
                  child: const Text('Skip Step 5'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _verifyingVehicleRc ? null : _completeStep,
                  child: Text(_verifyingVehicleRc ? 'Verifying...' : 'Continue to Step 6'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
