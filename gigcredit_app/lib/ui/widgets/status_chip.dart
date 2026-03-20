import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.ok,
    this.okLabel = 'Verified',
    this.pendingLabel = 'Pending',
  });

  final bool ok;
  final String okLabel;
  final String pendingLabel;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(ok ? okLabel : pendingLabel),
      backgroundColor: ok ? const Color(0xFFD5F5DE) : const Color(0xFFF1F1F4),
    );
  }
}
