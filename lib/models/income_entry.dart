import '../core/money.dart';

class IncomeEntry {
  final int? id;
  /// Stored in paisa (1 ₹ = 100).
  final int amount;
  final String month;
  /// Bank / cash account this income credits.
  final String account;
  final String note;
  final String createdAt;

  IncomeEntry({
    this.id,
    required this.amount,
    required this.month,
    this.account = '',
    this.note = '',
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'month': month,
      'account': account,
      'note': note,
      'created_at': createdAt,
    };
  }

  factory IncomeEntry.fromMap(Map<String, dynamic> map) {
    return IncomeEntry(
      id: map['id'] as int?,
      amount: amountPaisaFromMap(map['amount']),
      month: map['month'] as String,
      account: map['account'] as String? ?? '',
      note: map['note'] as String? ?? '',
      createdAt: map['created_at'] as String?,
    );
  }
}
