import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enums/step_status.dart';
import '../../state/verified_profile_provider.dart';
import '../../app/theme.dart';

class StepProgressHeader extends ConsumerWidget {
  const StepProgressHeader({super.key, required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(verifiedProfileProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Progress: Step $currentStep of 9', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List<Widget>.generate(9, (index) {
            final stepNo = index + 1;
            final stepId = StepId.values[index];
            final status = profile.verificationState[stepId] ?? StepStatus.notStarted;
            final isCurrent = stepNo == currentStep;
            final verified = status == StepStatus.verified;

            final bg = verified
                ? GigTheme.teal.withAlpha(40)
                : isCurrent
                    ? GigTheme.blue.withAlpha(50)
                    : GigTheme.divider.withAlpha(50);
                    
            final textColor = verified
                ? GigTheme.teal
                : isCurrent
                    ? GigTheme.blue
                    : GigTheme.txtHint;
            
            final border = verified
                ? GigTheme.teal.withAlpha(100)
                : isCurrent
                    ? GigTheme.blue.withAlpha(100)
                    : GigTheme.divider;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Text(
                'S$stepNo',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
