import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_time.dart';
import '../services/prayer_service.dart';
import '../services/location_service.dart';
import '../services/adzan_audio_service.dart';

enum PrayerStatus { initial, loading, success, error }

// Baca nama asset dari preferensi agar user bisa ganti file adzan
// tanpa ubah kode (mis. 'assets/adzan_subuh.mp3').
const _keyAdzanAsset = 'adzan_asset';
const _adzanAssetFallback = 'assets/adzan.mp3';

class PrayerProvider extends ChangeNotifier {
  PrayerStatus status = PrayerStatus.initial;
  PrayerTime? prayerTime;
  String? errorMessage;
  String? savedCityName;

  static const _keyLat = 'saved_lat';
  static const _keyLng = 'saved_lng';
  static const _keyCityName = 'saved_city_name';

  /// Untuk cek waktu sholat berikutnya tiap detik.
  Timer? _checkTimer;
  /// Cache waktu selanjutnya kalau tidak ada jadwal (mis. error).
  ({String name, DateTime time, IconData icon})? _nextPrayer;

  /// Dipanggil saat app dibuka. Cek dulu apakah user punya lokasi
  /// tersimpan (dari pilihan manual sebelumnya). Kalau tidak ada,
  /// coba ambil dari GPS.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLat = prefs.getDouble(_keyLat);
      final savedLng = prefs.getDouble(_keyLng);
      savedCityName = prefs.getString(_keyCityName);

      if (savedLat != null && savedLng != null) {
        await _fetchPrayerTime(savedLat, savedLng);
      } else {
        await loadFromGps();
      }
    } catch (e) {
      // Tanpa try/catch ini, kegagalan jaringan bikin status stuck di
      // "loading" selamanya karena status tidak pernah berubah ke error.
      status = PrayerStatus.error;
      errorMessage = e.toString();
      notifyListeners();
    }

    // Mulai cek waktu sholat setelah jadwal berhasil / gagal dimuat.
    _startChecking();
  }

  /// Skenario B — otomatis via GPS
  Future<void> loadFromGps() async {
    status = PrayerStatus.loading;
    notifyListeners();

    try {
      final loc = await LocationService.getCurrentLocation();

      // Server /prayer hanya cocok dengan koordinat yang persis sama
      // dengan database kota. GPS tidak akan pernah persis, jadi snap
      // dulu ke kota terdekat lalu pakai koordinat persis kota tsb.
      final city = await PrayerService.getNearestCity(
        loc.latitude,
        loc.longitude,
      );
      savedCityName = city.name;

      await _fetchPrayerTime(city.latitude!, city.longitude!);
      await _saveLocation(city.latitude!, city.longitude!, city.name);
    } catch (e) {
      status = PrayerStatus.error;
      errorMessage = e.toString();
      notifyListeners();

      // Lanjut cek berdasarkan jadwal sebelumnya kalau ada.
      _startChecking();
    }
  }

  /// Skenario A — dipanggil setelah user pilih kota manual dari
  /// SelectCityScreen. Butuh koordinat kota yang dipilih.
  Future<void> loadFromManualCity({
    required double latitude,
    required double longitude,
    required String cityName,
  }) async {
    status = PrayerStatus.loading;
    notifyListeners();

    try {
      await _fetchPrayerTime(latitude, longitude);
      savedCityName = cityName;
      await _saveLocation(latitude, longitude, cityName);
    } catch (e) {
      status = PrayerStatus.error;
      errorMessage = e.toString();
      notifyListeners();

      _startChecking();
    }
  }

  Future<void> _fetchPrayerTime(double lat, double lng) async {
    final result = await PrayerService.getPrayerTime(lat, lng);
    prayerTime = result;
    status = PrayerStatus.success;
    notifyListeners();
  }

  Future<void> _saveLocation(double lat, double lng, String? cityName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLat, lat);
    await prefs.setDouble(_keyLng, lng);
    if (cityName != null) await prefs.setString(_keyCityName, cityName);
  }

  /// Dipanggil dari tombol "Ganti Kota" di UI — hapus preferensi lama
  /// supaya user bisa pilih ulang.
  Future<void> clearSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLat);
    await prefs.remove(_keyLng);
    await prefs.remove(_keyCityName);
    savedCityName = null;
    notifyListeners();
  }

  /// Jalankan pengecekan waktu sholat tiap detik. Adzan akan otomatis
  /// keluar saat jamnya masuk (dengan cooldown 60 detik buat hindari
  /// perpanjangan karena perbedaan jam di tiap detik).
  void _startChecking() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkAndMaybePlayAdzan();
    });

    // Cek langsung juga saat pertama kali dimulai.
    _checkAndMaybePlayAdzan();
  }

  void _checkAndMaybePlayAdzan() {
    if (status != PrayerStatus.success || prayerTime == null) return;

    final now = DateTime.now();
    final pt = prayerTime!;

    final candidates = _todayPrayers(pt);
    if (candidates.isEmpty) return;

    // Cari sholat yang jamnya sudah masuk sekarang.
    for (final (name, timeStr) in candidates) {
      final t = _parseTimeOfDay(timeStr);
      if (t == null) continue;
      final prayerAt = DateTime(
        now.year,
        now.month,
        now.day,
        t.hour,
        t.minute,
      );
      if (now.isAfter(prayerAt) ||
          now.isAtSameMomentAs(prayerAt) &&
          now.second == 0) {
        _attemptPlay(name, prayerAt, pt);
        return;
      }
    }

    // Kalau hari sudah berubah, reset cache jam berikutnya.
    if (_nextPrayer != null &&
        _nextPrayer!.time.year != now.year ||
        _nextPrayer!.time.month != now.month ||
        _nextPrayer!.time.day != now.day) {
      _nextPrayer = null;
    }
  }

  Future<void> _attemptPlay(
    String name,
    DateTime prayerAt,
    PrayerTime pt,
  ) async {
    // Anti-double-play dalam hitungan detik yang sama.
    if (_nextPrayer != null &&
        _nextPrayer!.name == name &&
        (_nextPrayer!.time.difference(prayerAt)).abs().inSeconds <= 30) {
      return;
    }
    _nextPrayer = (name: name, time: prayerAt, icon: _iconFor(name));

    final asset = await _adzanAssetPath();
    if (asset == null) return;

    try {
      await AdzanAudioService().play(assetPath: asset);
    } catch (e) {
      // Jangan bikin crash kalau audio gagal dimainkan.
    }
  }

  /// Baca path asset adzan dari SharedPreferences, kalau tidak ada
  /// pakai yang bawaan.
  Future<String?> _adzanAssetPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_keyAdzanAsset);
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    return _adzanAssetFallback;
  }

  /// Urutan waktu sholat dalam sehari (tanpa Terbit kalau belum diminta).
  List<(String name, String timeStr)> _todayPrayers(PrayerTime pt) {
    return [
      ('Imsak', pt.imsak),
      ('Subuh', pt.subuh),
      ('Dzuhur', pt.dzuhur),
      ('Ashar', pt.ashar),
      ('Maghrib', pt.maghrib),
      ('Isya', pt.isya),
    ];
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'Subuh':
        return Icons.wb_sunny;
      case 'Dzuhur':
        return Icons.light_mode;
      case 'Ashar':
        return Icons.wb_cloudy;
      case 'Maghrib':
        return Icons.wb_twilight;
      case 'Imsak':
      case 'Isya':
      default:
        return Icons.nights_stay;
    }
  }

  DateTime? _parseTimeOfDay(String t) {
    final parts = t.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(0, 1, 1, h, m);
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}