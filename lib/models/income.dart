class Income {
  final int? id;
  final double amount;
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
      amount: (map['amount'] as num).toDouble(),
      month: map['month'] as String,
    );
  }
}
