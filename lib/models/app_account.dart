class AppAccount {
  final int? id;
  final String name;
  final int sortOrder;
  final bool archived;

  const AppAccount({
    this.id,
    required this.name,
    this.sortOrder = 0,
    this.archived = false,
  });

  AppAccount copyWith({
    int? id,
    String? name,
    int? sortOrder,
    bool? archived,
  }) {
    return AppAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name.trim(),
      'sort_order': sortOrder,
      'archived': archived ? 1 : 0,
    };
  }

  factory AppAccount.fromMap(Map<String, dynamic> map) {
    return AppAccount(
      id: map['id'] as int?,
      name: map['name'] as String,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      archived: (map['archived'] as num?)?.toInt() == 1,
    );
  }
}
