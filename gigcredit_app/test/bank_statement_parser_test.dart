import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/core/bank/bank_statement_parser.dart';

void main() {
  group('BankStatementParser', () {
    test('parses axis sample statement without placeholder metadata', () {
      const rawText =
          'Statement of Axis Account No :920010028333901 for the period '
          '(From : 16-07-2025  To : 15-01-2026) '
          'IFSC Code :UTIB0000345 '
          'OPENING BALANCE 4.03 '
          '16-07-2025 UPI/P2A/519739896895/SHANTHI /State Ban/UPI/ 200.00 204.03 345 '
          '16-07-2025 UPI/P2M/556340591698/Mr Gokul Pandi M /UPI/YES BANK LIMITED YBS 44.00 160.03 345';

      final parser = BankStatementParser();
      final result = parser.parseText(rawText: rawText, bankName: 'AXIS');

      expect(result.supported, isTrue);
      expect(result.accountNumber, '920010028333901');
      expect(result.ifscCode, 'UTIB0000345');
      expect(result.transactions.isNotEmpty, isTrue);
    });

  });
}
