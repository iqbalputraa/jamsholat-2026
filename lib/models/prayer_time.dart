class PrayerTime {
  final String cityName;
  final String date;
  final String imsak;
  final String subuh;
  final String terbit;
  final String dzuhur;
  final String ashar;
  final String maghrib;
  final String isya;

  PrayerTime({
    required this.cityName,
    required this.date,
    required this.imsak,
    required this.subuh,
    required this.terbit,
    required this.dzuhur,
    required this.ashar,
    required this.maghrib,
    required this.isya,
  });

  factory PrayerTime.fromJson(Map<String, dynamic> json) {
    // Nama kota di root objek ('name', 'cityName', 'city', 'kota')
    final cityName = (json['name'] ??
            json['cityName'] ??
            json['city'] ??
            json['kota'] ??
            '-')
        .toString();

    Map<String, dynamic>? timeMap;
    String dateStr = '-';

    // API mengembalikan array "prayers" yang berisi objek per tanggal
    if (json['prayers'] is List && (json['prayers'] as List).isNotEmpty) {
      final prayersList = json['prayers'] as List;
      final now = DateTime.now();
      final targetDate = "${now.year}-${now.month}-${now.day}";

      Map<String, dynamic>? selectedPrayer;
      for (final p in prayersList) {
        if (p is Map<String, dynamic> && p['date'].toString() == targetDate) {
          selectedPrayer = p;
          break;
        }
      }
      // Jika tanggal hari ini tidak ditemukan di list, gunakan item pertama
      selectedPrayer ??= (prayersList.first as Map<String, dynamic>);

      dateStr = selectedPrayer['date']?.toString() ?? '-';
      if (selectedPrayer['time'] is Map<String, dynamic>) {
        timeMap = selectedPrayer['time'] as Map<String, dynamic>;
      } else {
        timeMap = selectedPrayer;
      }
    } else if (json['data'] is Map<String, dynamic>) {
      final data = json['data'] as Map<String, dynamic>;
      dateStr = (data['date'] ?? data['tanggal'] ?? '-').toString();
      timeMap =
          (data['time'] ?? data['jadwal'] ?? data) as Map<String, dynamic>;
    } else {
      dateStr = (json['date'] ?? json['tanggal'] ?? '-').toString();
      timeMap =
          (json['time'] ?? json['jadwal'] ?? json) as Map<String, dynamic>;
    }

    String getValue(List<String> keys) {
      if (timeMap != null) {
        for (final k in keys) {
          if (timeMap[k] != null) return timeMap[k].toString();
        }
      }
      for (final k in keys) {
        if (json[k] != null) return json[k].toString();
      }
      return '-';
    }

    return PrayerTime(
      cityName: cityName,
      date: dateStr,
      imsak: getValue(['imsak']),
      subuh: getValue(['subuh', 'fajr']),
      terbit: getValue(['terbit', 'sunrise']),
      dzuhur: getValue(['dzuhur', 'zuhur', 'dhuhr']),
      ashar: getValue(['ashar', 'asr']),
      maghrib: getValue(['maghrib']),
      isya: getValue(['isya', 'isha']),
    );
  }

  List<MapEntry<String, String>> toList() => [
        MapEntry('Imsak', imsak),
        MapEntry('Subuh', subuh),
        MapEntry('Terbit', terbit),
        MapEntry('Dzuhur', dzuhur),
        MapEntry('Ashar', ashar),
        MapEntry('Maghrib', maghrib),
        MapEntry('Isya', isya),
      ];
}