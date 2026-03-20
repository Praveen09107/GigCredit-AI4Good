import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/core/bank/emi_detector.dart';
import 'package:gigcredit_app/models/bank_transaction.dart';

void main() {
  group('EmiDetector Unit Tests', () {
    test('Empty and non-conforming lists return empty', () {
      final detector = EmiDetector();
      expect(detector.detect([]), isEmpty);
      
      // Only 1 debit
      expect(
        detector.detect([
          BankTransaction(date: DateTime(2023, 1, 1), amount: 5000, type: 'DEBIT', description: 'HDFC LOAN EMI', balanceAfter: 0)
        ]),
        isEmpty,
        reason: 'Requires at least minOccurrences (2 by default)',
      );

      // Only credits
      expect(
        detector.detect([
          BankTransaction(date: DateTime(2023, 1, 1), amount: 5000, type: 'CREDIT', description: 'SALARY', balanceAfter: 0),
          BankTransaction(date: DateTime(2023, 2, 1), amount: 5000, type: 'CREDIT', description: 'SALARY', balanceAfter: 0),
        ]),
        isEmpty,
        reason: 'Only debits are analyzed for EMI',
      );
    });

    test('Detects perfect monthly EMI', () {
      final detector = EmiDetector();
      final txns = [
        BankTransaction(date: DateTime(2023, 1, 5), amount: 8000, type: 'DEBIT', description: 'BAJAJ FINANCE EMI 1234567890', balanceAfter: 0),
        BankTransaction(date: DateTime(2023, 2, 5), amount: 8000, type: 'DEBIT', description: 'BAJAJ FINANCE EMI 1234567891', balanceAfter: 0),
        BankTransaction(date: DateTime(2023, 3, 5), amount: 8000, type: 'DEBIT', description: 'BAJAJ FINANCE EMI 1234567892', balanceAfter: 0),
        BankTransaction(date: DateTime(2023, 4, 5), amount: 8000, type: 'DEBIT', description: 'BAJAJ FINANCE EMI 1234567893', balanceAfter: 0),
      ];

      final results = detector.detect(txns);
      expect(results.length, 1);
      final emi = results.first;
      expect(emi.occurrences, 4);
      expect(emi.monthlyAmount, 8000.0);
      expect(emi.isMonthly, isTrue);
      expect(emi.confidence, greaterThan(0.8));
    });

    test('Filters out random irregular debits', () {
      final detector = EmiDetector();
      final txns = [
        BankTransaction(date: DateTime(2023, 1, 1), amount: 150, type: 'DEBIT', description: 'AMAZON PAY', balanceAfter: 0),
        BankTransaction(date: DateTime(2023, 1, 10), amount: 300, type: 'DEBIT', description: 'AMAZON PAY', balanceAfter: 0),
        BankTransaction(date: DateTime(2023, 1, 15), amount: 150, type: 'DEBIT', description: 'AMAZON PAY', balanceAfter: 0),
        BankTransaction(date: DateTime(2023, 2, 2), amount: 450, type: 'DEBIT', description: 'AMAZON PAY', balanceAfter: 0),
      ];

      final results = detector.detect(txns);
      expect(results, isEmpty, reason: 'Intervals vary and are not ~30 days, amount varies');
    });

    test('Computes total monthly obligation correctly', () {
      final detector = EmiDetector();
      final txns = [
        // Load 1 (10,000 / month)
        BankTransaction(date: DateTime(2023, 1, 1), amount: 10000, type: 'DEBIT', description: 'HOME LOAN EMI', balanceAfter: 0),
        BankTransaction(date: DateTime(2023, 2, 1), amount: 10000, type: 'DEBIT', description: 'HOME LOAN EMI', balanceAfter: 0),
        BankTransaction(date: DateTime(2023, 3, 1), amount: 10000, type: 'DEBIT', description: 'HOME LOAN EMI', balanceAfter: 0),

        // Load 2 (2,000 / month)
        BankTransaction(date: DateTime(2023, 1, 15), amount: 2000, type: 'DEBIT', description: 'PERSONAL LOAN', balanceAfter: 0),
        BankTransaction(date: DateTime(2023, 2, 14), amount: 2000, type: 'DEBIT', description: 'PERSONAL LOAN', balanceAfter: 0),
        BankTransaction(date: DateTime(2023, 3, 16), amount: 2000, type: 'DEBIT', description: 'PERSONAL LOAN', balanceAfter: 0),
      ];

      final results = detector.detect(txns);
      expect(results.length, 2);

      final total = detector.totalMonthlyObligation(results);
      expect(total, 12000.0);
    });
  });
}
