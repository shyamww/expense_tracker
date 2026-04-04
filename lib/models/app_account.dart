class AppAccount {
  final int? id;
  final String name;
  final int sortOrder;

  const AppAccount({
    this.id,
    required this.name,
    this.sortOrder = 0,
  });

  AppAccount copyWith({
    int? id,
    String? name,
    int? sortOrder,
  }) {
    return AppAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name.trim(),
      'sort_order': sortOrder,
    };
  }

  factory AppAccount.fromMap(Map<String, dynamic> map) {
    return AppAccount(
      id: map['id'] as int?,
      name: map['name'] as String,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
