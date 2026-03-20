class BankTransaction {
  const BankTransaction({
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.balanceAfter,
  });

  final DateTime date;
  final String description;
  final double amount;
  final String type;
  final double balanceAfter;
}
