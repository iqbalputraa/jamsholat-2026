import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/province.dart';
import '../models/city.dart';
import '../models/prayer_time.dart';

class PrayerService {
  // Base URL dari repo maftuh23/waktu-sholat
  static const String baseUrl =
      'http://loscos4w40ko04sss0cg0wo4.70.153.72.107.sslip.io';

  // Timeout supaya request yang macet tidak bikin layar loading
  // menggantung lama (default http.get tanpa timeout bisa menunggu
  // sampai hitungan menit).
  static const Duration _timeout = Duration(seconds: 15);

  static Future<http.Response> _get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path')).timeout(_timeout);
    _checkStatus(res);
    return res;
  }

  static Future<List<Province>> getProvinces() async {
    final res = await _get('/province');
    _checkStatus(res);
    final decoded = json.decode(res.body);
    final list = (decoded is List) ? decoded : (decoded['data'] ?? []);
    return (list as List)
        .map((e) => Province.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<City>> getCities(String provinceId) async {
    final res = await _get('/province/$provinceId/city');
    _checkStatus(res);
    final decoded = json.decode(res.body);
    final list = (decoded is List) ? decoded : (decoded['data'] ?? []);
    return (list as List)
        .map((e) => City.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<City> getCityDetail(String provinceId, String cityId) async {
    final res = await _get('/province/$provinceId/city/$cityId');
    _checkStatus(res);
    final decoded = json.decode(res.body);
    final data = (decoded['data'] ?? decoded) as Map<String, dynamic>;
    return City.fromJson(data);
  }

  static List<City>? _cachedCities;

  /// Ambil semua kota beserta koordinat persisnya dari endpoint /province
  /// (respons-nya sudah menyertakan daftar kota tiap provinsi).
  /// Hasilnya di-cache karena endpoint /prayer butuh koordinat yang
  /// persis sama dengan yang ada di database server.
  static Future<List<City>> _getAllCities() async {
    if (_cachedCities != null) return _cachedCities!;

    final res = await _get('/province');
    _checkStatus(res);
    final decoded = json.decode(res.body);
    final list = (decoded is List) ? decoded : (decoded['data'] ?? []);

    final cities = <City>[];
    for (final p in list as List) {
      final province = p as Map<String, dynamic>;
      final cityList = province['cities'];
      if (cityList is List) {
        cities.addAll(
          cityList.map((c) => City.fromJson(c as Map<String, dynamic>)),
        );
      }
    }
    _cachedCities = cities;
    return cities;
  }

  /// Cari kota terdekat dari koordinat GPS. Server /prayer hanya cocok
  /// dengan koordinat yang persis sama dengan database, sedangkan hasil
  /// GPS tidak akan pernah persis. Jadi kita "snap" ke kota terdekat
  /// lalu pakai koordinat persis kota tersebut untuk request berikutnya.
  static Future<City> getNearestCity(double lat, double lng) async {
    final cities = await _getAllCities();

    City? nearest;
    double? nearestDistance;
    for (final c in cities) {
      final clat = c.latitude;
      final clng = c.longitude;
      if (clat == null || clng == null) continue;
      final d = _haversineKm(lat, lng, clat, clng);
      if (nearest == null || d < nearestDistance!) {
        nearest = c;
        nearestDistance = d;
      }
    }

    if (nearest == null) {
      throw Exception('Tidak ada kota terdekat yang ditemukan.');
    }
    return nearest;
  }

  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return earthRadiusKm *
        2 *
        math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  static Future<PrayerTime> getPrayerTime(double lat, double lng) async {
    final res = await _get('/prayer?latitude=$lat&longitude=$lng');
    _checkStatus(res);
    final decoded = json.decode(res.body);
    return PrayerTime.fromJson(decoded as Map<String, dynamic>);
  }

  static void _checkStatus(http.Response res) {
    if (res.statusCode != 200) {
      throw Exception('API error (${res.statusCode}): ${res.body}');
    }
  }
}