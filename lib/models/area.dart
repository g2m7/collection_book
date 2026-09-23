class Area {
  final int? id;
  final String name;

  const Area({this.id, required this.name});

  Map<String, dynamic> toMap() => {if (id != null) 'id': id, 'name': name};

  factory Area.fromMap(Map<String, dynamic> map) =>
      Area(id: map['id'] as int?, name: map['name'] as String);

  Area copyWith({int? id, String? name}) =>
      Area(id: id ?? this.id, name: name ?? this.name);

  @override
  String toString() => 'Area(id: $id, name: $name)';
}
