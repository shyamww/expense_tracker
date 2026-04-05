import '../core/money.dart';

class Income {
  final int? id;
  /// Stored in paisa (1 ₹ = 100).
  final int amount;
  final String month; // YYYY-MM format

  Income({
    this.id,
    required this.amount,
    required this.month,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'month': month,
    };
  }

  factory Income.fromMap(Map<String, dynamic> map) {
    return Income(
      id: map['id'] as int?,
      amount: amountPaisaFromMap(map['amount']),
      month: map['month'] as String,
    );
  }
}
