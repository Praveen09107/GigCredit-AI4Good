import '../../models/bank_transaction.dart';

class TransactionTagger {
  String tag(BankTransaction txn) {
    final desc = txn.description.toUpperCase();
    if (desc.contains('EMI') || desc.contains('LOAN')) return 'EMI_DEBIT';
    if (desc.contains('SALARY') || desc.contains('CREDIT')) return 'INCOME';
    if (desc.contains('UPI')) return 'P2P_TRANSFER';
    return 'UNCATEGORIZED';
  }
}
