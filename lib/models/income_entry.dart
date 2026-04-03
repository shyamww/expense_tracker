class IncomeEntry {
  final int? id;
  final double amount;
  final String month;
  final String note;
  final String createdAt;

  IncomeEntry({
    this.id,
    required this.amount,
    required this.month,
    this.note = '',
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'month': month,
      'note': note,
      'created_at': createdAt,
    };
  }

  factory IncomeEntry.fromMap(Map<String, dynamic> map) {
    return IncomeEntry(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      month: map['month'] as String,
      note: map['note'] as String? ?? '',
      createdAt: map['created_at'] as String?,
    );
  }
}
