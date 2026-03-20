import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/validation/step1_validators.dart';
import '../../../models/enums/work_type.dart';
import '../../../state/verified_profile_provider.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/step_progress_header.dart';

class Step1ProfileScreen extends ConsumerStatefulWidget {
  const Step1ProfileScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  ConsumerState<Step1ProfileScreen> createState() => _Step1ProfileScreenState();
}

class _Step1ProfileScreenState extends ConsumerState<Step1ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _mobileController = TextEditingController();
  final _currentAddressController = TextEditingController();
  final _permanentAddressController = TextEditingController();
  final _monthlyIncomeController = TextEditingController();
  final _yearsInProfessionController = TextEditingController();
  final _dependentsController = TextEditingController();
  final _secondaryIncomeSourceController = TextEditingController();
  final _secondaryIncomeAmountController = TextEditingController();

  WorkType? _workType;
  String? _stateOfResidence;
  bool? _hasVehicle;

  static const List<String> _indianStatesAndUts = <String>[
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Andaman and Nicobar Islands',
    'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Jammu and Kashmir',
    'Ladakh',
    'Lakshadweep',
    'Puducherry',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _dateOfBirthController.dispose();
    _mobileController.dispose();
    _currentAddressController.dispose();
    _permanentAddressController.dispose();
    _monthlyIncomeController.dispose();
    _yearsInProfessionController.dispose();
    _dependentsController.dispose();
    _secondaryIncomeSourceController.dispose();
    _secondaryIncomeAmountController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString().padLeft(4, '0');
    return '$dd/$mm/$yyyy';
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 25, now.month, now.day);
    final firstDate = DateTime(now.year - 65, 1, 1);
    final lastDate = DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(lastDate) ? lastDate : initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select Date of Birth',
    );

    if (picked != null) {
      setState(() {
        _dateOfBirthController.text = _formatDate(picked);
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final relationErr = Step1Validators.validateAddressRelationship(
      _currentAddressController.text,
      _permanentAddressController.text,
    );
    if (relationErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(relationErr)));
      return;
    }

    if (_workType == null || _hasVehicle == null || _stateOfResidence == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select work type, state, and vehicle ownership.')),
      );
      return;
    }

    ref.read(verifiedProfileProvider.notifier).completeStep1(
          fullName: _fullNameController.text,
          dateOfBirthText: _dateOfBirthController.text,
          mobile: _mobileController.text,
          currentAddress: _currentAddressController.text,
          permanentAddress: _permanentAddressController.text,
          stateOfResidence: _stateOfResidence!,
          workType: _workType!,
          monthlyIncomeText: _monthlyIncomeController.text,
          yearsInCurrentProfessionText: _yearsInProfessionController.text,
          numberOfDependentsText: _dependentsController.text,
          hasVehicle: _hasVehicle!,
          secondaryIncomeSource: _secondaryIncomeSourceController.text,
          secondaryIncomeAmountText: _secondaryIncomeAmountController.text,
        );

    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step 1 of 9 • Basic Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const StepProgressHeader(currentStep: 1),
            const SizedBox(height: 14),
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
              validator: (v) => Step1Validators.validateFullName(v ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dateOfBirthController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                hintText: 'DD/MM/YYYY',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: _pickDateOfBirth,
              validator: (v) => Step1Validators.validateDateOfBirth(v ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile Number'),
              validator: (v) => Step1Validators.validateMobile(v ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _currentAddressController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Current Address'),
              validator: (v) => Step1Validators.validateAddress(v ?? '', fieldLabel: 'Current address'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _permanentAddressController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Permanent Address'),
              validator: (v) => Step1Validators.validateAddress(v ?? '', fieldLabel: 'Permanent address'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _stateOfResidence,
              decoration: const InputDecoration(labelText: 'State of Residence'),
              items: _indianStatesAndUts
                  .map((state) => DropdownMenuItem<String>(
                        value: state,
                        child: Text(
                          state,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _stateOfResidence = value),
              validator: (value) => Step1Validators.validateStateOfResidence(value ?? ''),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<WorkType>(
              isExpanded: true,
              initialValue: _workType,
              items: WorkType.values
                  .map((e) => DropdownMenuItem<WorkType>(
                        value: e,
                        child: Text(
                          e.label,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _workType = value),
              decoration: const InputDecoration(labelText: 'Work Type'),
              validator: (value) => value == null ? 'Work type is required.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _monthlyIncomeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Self-Declared Monthly Income (INR)'),
              validator: (v) => Step1Validators.validateMonthlyIncome(v ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _yearsInProfessionController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Years in Current Profession'),
              validator: (v) => Step1Validators.validateYearsInCurrentProfession(v ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dependentsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Number of Dependents'),
              validator: (v) => Step1Validators.validateDependents(v ?? ''),
            ),
            const SizedBox(height: 12),
            const Text('Do you have a vehicle?', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Yes'),
                  selected: _hasVehicle == true,
                  onSelected: (selected) => setState(() => _hasVehicle = selected ? true : null),
                ),
                ChoiceChip(
                  label: const Text('No'),
                  selected: _hasVehicle == false,
                  onSelected: (selected) => setState(() => _hasVehicle = selected ? false : null),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _secondaryIncomeSourceController,
              decoration: const InputDecoration(
                labelText: 'Secondary Income Source (Optional)',
              ),
              validator: (v) => Step1Validators.validateSecondaryIncomeSource(
                v ?? '',
                hasAmount: _secondaryIncomeAmountController.text.trim().isNotEmpty,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _secondaryIncomeAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Secondary Income Amount (Optional)',
              ),
              validator: (v) => Step1Validators.validateSecondaryIncomeAmount(
                v ?? '',
                hasSource: _secondaryIncomeSourceController.text.trim().isNotEmpty,
              ),
            ),
            const SizedBox(height: 8),
            PrimaryButton(label: 'Continue to Step 2', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
