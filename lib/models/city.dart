class City {
  final String id;
  final String name;
  final double? latitude;
  final double? longitude;

  City({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    // Koordinat dibungkus di dalam objek "coordinate": { latitude, longitude }
    final coord = json['coordinate'] as Map<String, dynamic>?;

    return City(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? json['nama'] ?? json['city'] ?? '').toString(),
      latitude: _toDouble(coord?['latitude'] ?? json['latitude'] ?? json['lat']),
      longitude: _toDouble(
        coord?['longitude'] ?? json['longitude'] ?? json['lng'] ?? json['long'],
      ),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}