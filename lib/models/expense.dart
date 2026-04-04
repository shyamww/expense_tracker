class Expense {
  final int? id;
  final double amount;
  final String category;
  /// Bank / cash account this expense debits (or credits if [category] is Received).
  final String account;
  final String note;
  final String date;
  final String createdAt;

  Expense({
    this.id,
    required this.amount,
    required this.category,
    this.account = '',
    this.note = '',
    required this.date,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'category': category,
      'account': account,
      'note': note,
      'date': date,
      'created_at': createdAt,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      account: map['account'] as String? ?? '',
      note: map['note'] as String? ?? '',
      date: map['date'] as String,
      createdAt: map['created_at'] as String?,
    );
  }
}
