class Province {
  final String id;
  final String name;
 
  Province({required this.id, required this.name});
 
  factory Province.fromJson(Map<String, dynamic> json) {
    return Province(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? json['nama'] ?? json['province'] ?? '').toString(),
    );
  }
}