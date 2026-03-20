import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bank/bank_statement_parser.dart';
import '../../../core/bank/emi_detector.dart';
import '../../../core/files/document_picker.dart';
import '../../../core/security/request_signer.dart';
import '../../../core/validation/step3_validators.dart';
import '../../../config/app_mode.dart';
import '../../../models/enums/document_type.dart';
import '../../../models/bank_transaction.dart';
import '../../../ai/verification_validation_engine.dart';
import '../../../services/backend_client.dart';
import '../../../services/document_pipeline_service.dart';
import '../../../state/offline_sync_service.dart';
import '../../../state/verified_profile_provider.dart';
import '../../widgets/step_progress_header.dart';

class Step3BankScreen extends ConsumerStatefulWidget {
  const Step3BankScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  ConsumerState<Step3BankScreen> createState() => _Step3BankScreenState();
}

class _Step3BankScreenState extends ConsumerState<Step3BankScreen> {
  static final String _apiBaseUrl = AppMode.resolvedBackendBaseUrl;
  static const String _apiKey = String.fromEnvironment('GIGCREDIT_API_KEY');
  static const bool _requireProductionReadiness = AppMode.requireProductionReadiness;

  final _bankNameController = TextEditingController();
  final _holderController = TextEditingController();
  final _branchController = TextEditingController();
  final _ifscController = TextEditingController();
  final _accountController = TextEditingController();
  final _micrController = TextEditingController();

  bool _enableSecondaryAccount = false;
  final _secondaryBankNameController = TextEditingController();
  final _secondaryHolderController = TextEditingController();
  final _secondaryBranchController = TextEditingController();
  final _secondaryIfscController = TextEditingController();
  final _secondaryAccountController = TextEditingController();
  final _secondaryMicrController = TextEditingController();

  String? _upiPlatform;
  bool _upiStatementUploaded = false;
  static const List<String> _upiPlatforms = <String>[
    'PhonePe',
    'Google Pay',
    'Paytm',
    'BHIM',
    'Other',
  ];

  final _parser = BankStatementParser();
  final _emiDetector = const EmiDetector();
  final _docPipeline = DocumentPipelineService();

  DateTime? _fromDate;
  DateTime? _toDate;
  DateTime? _secondaryFromDate;
  DateTime? _secondaryToDate;

  bool _ifscVerified = false;
  bool _accountVerified = false;
  bool _secondaryIfscVerified = false;
  bool _secondaryAccountVerified = false;

  bool _statementUploaded = false;
  bool _secondaryStatementUploaded = false;
  int _primaryTransactionCount = 0;
  int _secondaryTransactionCount = 0;
  int _transactionCount = 0;

  List<BankTransaction> _primaryTransactions = const <BankTransaction>[];
  List<BankTransaction> _secondaryTransactions = const <BankTransaction>[];
  List<DetectedEmi> _detectedEmis = const [];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(verifiedProfileProvider);
    if (profile.ifscCode.trim().isNotEmpty) {
      _ifscController.text = profile.ifscCode.trim().toUpperCase();
    }
    if (profile.fullName.trim().isNotEmpty) {
      _holderController.text = profile.fullName.trim();
    }
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _holderController.dispose();
    _branchController.dispose();
    _ifscController.dispose();
    _accountController.dispose();
    _micrController.dispose();
    _secondaryBankNameController.dispose();
    _secondaryHolderController.dispose();
    _secondaryBranchController.dispose();
    _secondaryIfscController.dispose();
    _secondaryAccountController.dispose();
    _secondaryMicrController.dispose();
    super.dispose();
  }

  Future<void> _verifyIfsc() async {
    final err = Step3Validators.validateIfsc(_ifscController.text);
    if (err != null) return _toast(err);

    final normalizedIfsc = Step3Validators.normalizeIfsc(_ifscController.text);
    final verifiedOnline = await _verifyOrQueue(
      path: '/verify/ifsc',
      body: <String, dynamic>{
        'identifier': normalizedIfsc,
      },
    );
    if (!mounted) return;

    setState(() {
      _ifscController.text = normalizedIfsc;
      _ifscVerified = verifiedOnline;
    });
    if (verifiedOnline) {
      _toast('IFSC verified via backend.');
    } else if (_requireProductionReadiness) {
      _toast('IFSC backend verification is required in production mode.');
    } else {
      _toast('IFSC verification queued (offline/mock fallback).');
    }
  }

  Future<void> _verifySecondaryIfsc() async {
    final err = Step3Validators.validateIfsc(_secondaryIfscController.text);
    if (err != null) return _toast(err);

    final normalizedIfsc = Step3Validators.normalizeIfsc(_secondaryIfscController.text);
    final verifiedOnline = await _verifyOrQueue(
      path: '/verify/ifsc',
      body: <String, dynamic>{
        'identifier': normalizedIfsc,
      },
    );
    if (!mounted) return;

    setState(() {
      _secondaryIfscController.text = normalizedIfsc;
      _secondaryIfscVerified = verifiedOnline;
    });
    if (verifiedOnline) {
      _toast('Secondary IFSC verified via backend.');
    } else if (_requireProductionReadiness) {
      _toast('Secondary IFSC backend verification is required in production mode.');
    } else {
      _toast('Secondary IFSC verification queued (offline/mock fallback).');
    }
  }

  Future<void> _verifyAccount() async {
    final err = Step3Validators.validateAccountNumber(_accountController.text);
    if (err != null) return _toast(err);

    final normalizedAccount = Step3Validators.normalizeAccountNumber(_accountController.text);
    final verifiedOnline = await _verifyOrQueue(
      path: '/verify/bank/account',
      body: <String, dynamic>{
        'identifier': normalizedAccount,
      },
    );
    if (!mounted) return;

    setState(() {
      _accountController.text = normalizedAccount;
      _accountVerified = verifiedOnline;
    });
    if (verifiedOnline) {
      _toast('Account verified via backend.');
    } else if (_requireProductionReadiness) {
      _toast('Account backend verification is required in production mode.');
    } else {
      _toast('Account verification queued (offline/mock fallback).');
    }
  }

  Future<void> _verifySecondaryAccount() async {
    final err = Step3Validators.validateAccountNumber(_secondaryAccountController.text);
    if (err != null) return _toast(err);

    final normalizedAccount = Step3Validators.normalizeAccountNumber(_secondaryAccountController.text);
    final verifiedOnline = await _verifyOrQueue(
      path: '/verify/bank/account',
      body: <String, dynamic>{
        'identifier': normalizedAccount,
      },
    );
    if (!mounted) return;

    setState(() {
      _secondaryAccountController.text = normalizedAccount;
      _secondaryAccountVerified = verifiedOnline;
    });
    if (verifiedOnline) {
      _toast('Secondary account verified via backend.');
    } else if (_requireProductionReadiness) {
      _toast('Secondary account backend verification is required in production mode.');
    } else {
      _toast('Secondary account verification queued (offline/mock fallback).');
    }
  }

  Future<bool> _verifyOrQueue({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    if (_apiBaseUrl.isNotEmpty && _apiKey.isNotEmpty) {
      try {
        final client = BackendClient(
          baseUrl: _apiBaseUrl,
          apiKey: _apiKey,
          deviceId: 'dev_b_bank',
          signatureProvider: signatureProviderFromApiKey(_apiKey),
        );
        final response = await client.postJson(path, body).timeout(const Duration(seconds: 4));
        final status = response.status.toUpperCase();
        if (status == 'SUCCESS' || status == 'FOUND' || status == 'OK' || status == 'VERIFIED') {
          return true;
        }
      } catch (_) {
        // Fall through to offline queue.
      }
    }

    await ref.read(offlineSyncServiceProvider).queueVerification(path: path, body: body);
    return false;
  }

  Future<void> _pickDate({required bool isFrom, required bool isSecondary}) async {
    final now = DateTime.now();
    final initial = isSecondary
        ? (isFrom
            ? (_secondaryFromDate ?? now.subtract(const Duration(days: 190)))
            : (_secondaryToDate ?? now.subtract(const Duration(days: 5))))
        : (isFrom
            ? (_fromDate ?? now.subtract(const Duration(days: 190)))
            : (_toDate ?? now.subtract(const Duration(days: 5))));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2010),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      if (isSecondary) {
        if (isFrom) {
          _secondaryFromDate = picked;
        } else {
          _secondaryToDate = picked;
        }
      } else {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      }
    });
  }

  Future<void> _uploadStatement({required bool isSecondary}) async {
    final ifscVerified = isSecondary ? _secondaryIfscVerified : _ifscVerified;
    final accountVerified = isSecondary ? _secondaryAccountVerified : _accountVerified;
    if (!(ifscVerified && accountVerified)) {
      return _toast('Verify IFSC and account first.');
    }
    final fromDate = isSecondary ? _secondaryFromDate : _fromDate;
    final toDate = isSecondary ? _secondaryToDate : _toDate;
    if (fromDate == null || toDate == null) {
      return _toast('Select statement from/to dates.');
    }

    final file = await DocumentPicker.pickSingle(pdfOnly: true);
    if (file == null || !mounted) return;
    if (file.path == null || file.path!.isEmpty) {
      return _toast('Unable to read file from local storage. Please retry.');
    }

    final profile = ref.read(verifiedProfileProvider);
    final expectedIfsc = (isSecondary ? _secondaryIfscController.text : _ifscController.text)
        .trim()
        .toUpperCase();
    final expectedHolder = (isSecondary ? _secondaryHolderController.text : _holderController.text)
        .trim();

    final processed = await _docPipeline.processFile(
      filePath: file.path!,
      documentType: DocumentType.bankStatement,
      validationContext: ValidationContext(
        stepTag: isSecondary ? 'step3_bank_statement_secondary' : 'step3_bank_statement_primary',
        requiredFields: const <String>['statement_id', 'ifsc_code', 'account_holder_name'],
        profile: VerifiedProfileSnapshot(
          fullName: profile.fullName,
          bankIfsc: profile.ifscCode.isEmpty ? null : profile.ifscCode,
          bankAccountHolder: expectedHolder.isEmpty ? null : expectedHolder,
        ),
        apiVerifiedFields: <String, String>{
          if (expectedIfsc.isNotEmpty) 'ifsc_code': expectedIfsc,
          if (expectedHolder.isNotEmpty) 'account_holder_name': expectedHolder,
        },
      ),
    );
    if (!processed.validation.passed) {
      return _toast('Document validation failed for bank statement. Please re-upload a valid statement.');
    }

    final rawText = processed.ocr.rawText;
    if (rawText.trim().isEmpty) {
      return _toast('OCR could not extract statement text. Please upload a clearer statement.');
    }

    final parsed = _parser.parseText(
      rawText: rawText,
      bankName: isSecondary ? _secondaryBankNameController.text : _bankNameController.text,
    );

    if (!parsed.supported) {
      return _toast(parsed.errorMessage ?? 'Unsupported statement format.');
    }

    if (!_parser.isStatementPeriodValid(
      fromDate: fromDate,
      toDate: toDate,
      currentDate: DateTime.now(),
    )) {
      return _toast('Statement must cover >= 6 months and end within last 30 days.');
    }

    final statementVerified = await _verifyOrQueue(
      path: '/verify/bank_statement',
      body: <String, dynamic>{
        'identifier': (isSecondary ? _secondaryAccountController.text : _accountController.text).trim(),
        'context': <String, dynamic>{
          'transaction_count': parsed.transactionCount,
          'from_date': fromDate.toIso8601String(),
          'to_date': toDate.toIso8601String(),
        },
      },
    );
    if (!statementVerified && _requireProductionReadiness) {
      return _toast('Bank statement backend verification failed. Please retry with a compliant statement.');
    }

    if (!mounted) return;

    final parsedIfsc = parsed.ifscCode.trim().toUpperCase();
    final parsedHolder = parsed.accountHolder.trim();
    final parsedAccount = parsed.accountNumber.trim();
    final parsedBankName = parsed.bankName.trim();

    setState(() {
      if (isSecondary) {
        if (_secondaryIfscController.text.trim().isEmpty && parsedIfsc.isNotEmpty) {
          _secondaryIfscController.text = parsedIfsc;
        }
        if (_secondaryHolderController.text.trim().isEmpty && parsedHolder.isNotEmpty) {
          _secondaryHolderController.text = parsedHolder;
        }
        if (_secondaryAccountController.text.trim().isEmpty && parsedAccount.isNotEmpty) {
          _secondaryAccountController.text = parsedAccount;
        }
        if (_secondaryBankNameController.text.trim().isEmpty && parsedBankName.isNotEmpty) {
          _secondaryBankNameController.text = parsedBankName;
        }
      } else {
        if (_ifscController.text.trim().isEmpty && parsedIfsc.isNotEmpty) {
          _ifscController.text = parsedIfsc;
        }
        if (_holderController.text.trim().isEmpty && parsedHolder.isNotEmpty) {
          _holderController.text = parsedHolder;
        }
        if (_accountController.text.trim().isEmpty && parsedAccount.isNotEmpty) {
          _accountController.text = parsedAccount;
        }
        if (_bankNameController.text.trim().isEmpty && parsedBankName.isNotEmpty) {
          _bankNameController.text = parsedBankName;
        }
      }

      if (isSecondary) {
        _secondaryStatementUploaded = true;
        _secondaryTransactionCount = parsed.transactionCount;
        _secondaryTransactions = parsed.transactions;
      } else {
        _statementUploaded = true;
        _primaryTransactionCount = parsed.transactionCount;
        _primaryTransactions = parsed.transactions;
      }
      _recomputeFromCombinedTransactions();
    });

    final emiSummary = _detectedEmis.isEmpty
        ? 'No recurring EMI detected.'
        : '${_detectedEmis.length} EMI pattern(s) detected. Est. monthly: ₹${_emiDetector.totalMonthlyObligation(_detectedEmis).toStringAsFixed(0)}';

    _toast('Parsed ${parsed.transactionCount} transactions and completed bank-statement verification. $emiSummary');
  }

  void _recomputeFromCombinedTransactions() {
    final combined = <BankTransaction>[
      ..._primaryTransactions,
      ..._secondaryTransactions,
    ];
    _detectedEmis = _emiDetector.detect(combined);
    _transactionCount = _primaryTransactionCount + _secondaryTransactionCount;
  }

  Future<void> _uploadUpiStatement() async {
    final file = await DocumentPicker.pickSingle(pdfOnly: true);
    if (file == null || !mounted) return;
    setState(() => _upiStatementUploaded = true);
    _toast('UPI statement selected: ${file.name}');
  }

  String? _validateMicr(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^\d{9}$').hasMatch(trimmed)) {
      return 'MICR must be 9 digits.';
    }
    return null;
  }

  String? _validateRequiredBankText(String value, String fieldName) {
    if (value.trim().isEmpty) return '$fieldName is required.';
    return null;
  }

  void _completeStep() {
    final primaryChecks = <String?>[
      _validateRequiredBankText(_bankNameController.text, 'Primary bank name'),
      _validateRequiredBankText(_holderController.text, 'Primary account holder name'),
      _validateRequiredBankText(_branchController.text, 'Primary branch name'),
      _validateMicr(_micrController.text),
    ];
    final firstPrimaryError = primaryChecks.firstWhere((e) => e != null, orElse: () => null);
    if (firstPrimaryError != null) {
      return _toast(firstPrimaryError);
    }

    if (!_statementUploaded || _fromDate == null || _toDate == null) {
      return _toast('Complete all primary bank inputs and process statement first.');
    }
    if (!(_ifscVerified && _accountVerified)) {
      return _toast('Verify primary IFSC and account before continuing.');
    }

    if (_enableSecondaryAccount) {
      final secondaryChecks = <String?>[
        _validateRequiredBankText(_secondaryBankNameController.text, 'Secondary bank name'),
        _validateRequiredBankText(_secondaryHolderController.text, 'Secondary account holder name'),
        _validateRequiredBankText(_secondaryBranchController.text, 'Secondary branch name'),
        _validateMicr(_secondaryMicrController.text),
      ];
      final firstSecondaryError = secondaryChecks.firstWhere((e) => e != null, orElse: () => null);
      if (firstSecondaryError != null) {
        return _toast(firstSecondaryError);
      }
      if (!(_secondaryIfscVerified && _secondaryAccountVerified)) {
        return _toast('Verify secondary IFSC and account.');
      }
      if (!(_secondaryStatementUploaded && _secondaryFromDate != null && _secondaryToDate != null)) {
        return _toast('Complete and process secondary account statement.');
      }
    }

    final ok = ref.read(verifiedProfileProvider.notifier).completeStep3(
          bankName: _bankNameController.text,
          accountHolderName: _holderController.text,
          ifscCode: _ifscController.text,
          accountNumberMasked: _maskAccountNumber(_accountController.text),
          accountNumber: _accountController.text,
          statementFrom: _fromDate!,
          statementTo: _toDate!,
          transactionCount: _transactionCount,
          emiDetected: _detectedEmis.isNotEmpty,
          emiCandidateCount: _detectedEmis.length,
          monthlyEmiObligation: _emiDetector.totalMonthlyObligation(_detectedEmis),
        );

    if (!ok) {
      return _toast('Cross-step validation failed. Account holder must match Step-1 identity.');
    }

    widget.onContinue();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _maskAccountNumber(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return '';
    }
    final normalized = Step3Validators.normalizeAccountNumber(value);
    if (normalized.length <= 4) {
      return normalized;
    }
    final keep = normalized.substring(normalized.length - 4);
    return 'XXXXXX$keep';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step 3 of 9 • Bank Verification')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const StepProgressHeader(currentStep: 3),
          const SizedBox(height: 14),
          const Text('Primary Bank Account', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _bankNameController,
            decoration: const InputDecoration(labelText: 'Bank Name (SBI/HDFC/ICICI)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _holderController,
            decoration: const InputDecoration(labelText: 'Account Holder Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _branchController,
            decoration: const InputDecoration(labelText: 'Bank Branch Name'),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _ifscController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'IFSC Code'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _verifyIfsc, child: const Text('Verify')),
            ],
          ),
          const SizedBox(height: 6),
          Text(_ifscVerified ? 'IFSC Verified' : 'IFSC Not Verified'),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _accountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Account Number'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _verifyAccount, child: const Text('Verify')),
            ],
          ),
          const SizedBox(height: 6),
          Text(_accountVerified ? 'Account Verified' : 'Account Not Verified'),
          const SizedBox(height: 10),
          TextField(
            controller: _micrController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'MICR Code (Optional)'),
          ),
          const Divider(height: 26),
          const Text('Statement Period', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isFrom: true, isSecondary: false),
                  child: Text(_fromDate == null ? 'From Date' : _fromDate!.toIso8601String().split('T').first),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isFrom: false, isSecondary: false),
                  child: Text(_toDate == null ? 'To Date' : _toDate!.toIso8601String().split('T').first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: (_ifscVerified && _accountVerified)
                ? () => _uploadStatement(isSecondary: false)
                : null,
            child: Text(_statementUploaded ? 'Statement processed' : 'Upload Bank Statement'),
          ),
          const Divider(height: 26),
          SwitchListTile(
            value: _enableSecondaryAccount,
            onChanged: (value) => setState(() => _enableSecondaryAccount = value),
            title: const Text('Add Secondary Bank Account'),
            subtitle: const Text('Recommended for platform workers with separate payout accounts.'),
          ),
          if (_enableSecondaryAccount) ...<Widget>[
            const SizedBox(height: 8),
            const Text('Secondary Bank Account', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _secondaryBankNameController,
              decoration: const InputDecoration(labelText: 'Bank Name (Secondary)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _secondaryHolderController,
              decoration: const InputDecoration(labelText: 'Account Holder Name (Secondary)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _secondaryBranchController,
              decoration: const InputDecoration(labelText: 'Bank Branch Name (Secondary)'),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _secondaryIfscController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'IFSC Code (Secondary)'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _verifySecondaryIfsc, child: const Text('Verify')),
              ],
            ),
            const SizedBox(height: 6),
            Text(_secondaryIfscVerified ? 'Secondary IFSC Verified' : 'Secondary IFSC Not Verified'),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _secondaryAccountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Account Number (Secondary)'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _verifySecondaryAccount, child: const Text('Verify')),
              ],
            ),
            const SizedBox(height: 6),
            Text(_secondaryAccountVerified ? 'Secondary Account Verified' : 'Secondary Account Not Verified'),
            const SizedBox(height: 10),
            TextField(
              controller: _secondaryMicrController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'MICR Code (Secondary, Optional)'),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isFrom: true, isSecondary: true),
                    child: Text(_secondaryFromDate == null
                        ? 'From Date (Secondary)'
                        : _secondaryFromDate!.toIso8601String().split('T').first),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isFrom: false, isSecondary: true),
                    child: Text(_secondaryToDate == null
                        ? 'To Date (Secondary)'
                        : _secondaryToDate!.toIso8601String().split('T').first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: (_secondaryIfscVerified && _secondaryAccountVerified)
                  ? () => _uploadStatement(isSecondary: true)
                  : null,
              child: Text(_secondaryStatementUploaded
                  ? 'Secondary statement processed'
                  : 'Upload Secondary Bank Statement'),
            ),
          ],
          const Divider(height: 26),
          const Text('Optional UPI Statement', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _upiPlatform,
            decoration: const InputDecoration(labelText: 'UPI Platform (Optional)'),
            items: _upiPlatforms
                .map((platform) => DropdownMenuItem<String>(
                      value: platform,
                      child: Text(platform),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _upiPlatform = value),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _uploadUpiStatement,
            child: Text(_upiStatementUploaded ? 'UPI statement uploaded' : 'Upload UPI Statement (Optional)'),
          ),
          const SizedBox(height: 8),
          Text('Primary transactions: $_primaryTransactionCount | Secondary transactions: $_secondaryTransactionCount'),
          Text('Total transaction count: $_transactionCount'),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: _completeStep, child: const Text('Continue to Step 4')),
        ],
      ),
    );
  }
}
