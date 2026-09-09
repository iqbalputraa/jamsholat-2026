import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/prayer_time.dart';
import '../providers/prayer_provider.dart';
import 'select_city_screen.dart';

const _kDeepGreen = Color(0xFF0B3D2E);
const _kPrimary = Color(0xFF0E7C6B);
const _kBright = Color(0xFF14A085);
const _kAmber = Color(0xFFF5C26B);
const _kInk = Color(0xFF14201C);

const _kMonths = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const _kDays = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

String _two(int n) => n.toString().padLeft(2, '0');

String _formatDate(DateTime d) =>
    '${_kDays[d.weekday - 1]}, ${d.day} ${_kMonths[d.month - 1]} ${d.year}';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Jam digital berjalan tiap detik
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // Jalankan alur init setelah frame pertama selesai dibangun
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrayerProvider>().init();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _openCityPicker() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectCityScreen()),
    );
    if (mounted) setState(() {});
  }

  DateTime? _parseTime(String t) {
    final parts = t.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(_now.year, _now.month, _now.day, h, m);
  }

  /// Cari sholat berikutnya (Imsak + 5 waktu sholat, tanpa Terbit).
  /// Kalau semua sudah lewat hari ini, lanjut ke waktu pertama besok.
  ({String name, DateTime time, IconData icon})? _findNextPrayer(
    PrayerTime pt,
  ) {
    final items = <(String, String, IconData)>[
      ('Imsak', pt.imsak, Icons.wb_twilight),
      ('Subuh', pt.subuh, Icons.wb_sunny),
      ('Dzuhur', pt.dzuhur, Icons.light_mode),
      ('Ashar', pt.ashar, Icons.wb_cloudy),
      ('Maghrib', pt.maghrib, Icons.wb_twilight),
      ('Isya', pt.isya, Icons.nights_stay),
    ];

    ({String name, DateTime time, IconData icon})? firstOfDay;
    ({String name, DateTime time, IconData icon})? next;

    for (final (name, timeStr, icon) in items) {
      final dt = _parseTime(timeStr);
      if (dt == null) continue;
      final rec = (name: name, time: dt, icon: icon);
      if (firstOfDay == null || dt.isBefore(firstOfDay.time)) {
        firstOfDay = rec;
      }
      if (dt.isAfter(_now) &&
          (next == null || dt.isBefore(next.time))) {
        next = rec;
      }
    }

    if (next != null) return next;
    if (firstOfDay != null) {
      return (
        name: firstOfDay.name,
        time: firstOfDay.time.add(const Duration(days: 1)),
        icon: firstOfDay.icon,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<PrayerProvider>(
        builder: (context, provider, _) {
          switch (provider.status) {
            case PrayerStatus.initial:
            case PrayerStatus.loading:
              return const _LoadingView();
            case PrayerStatus.error:
              return _ErrorView(
                message: provider.errorMessage ?? 'Terjadi kesalahan',
                onRetry: provider.loadFromGps,
                onPickCity: _openCityPicker,
              );
            case PrayerStatus.success:
              final pt = provider.prayerTime!;
              final cityName = provider.savedCityName ?? pt.cityName;
              final scheduleDate = DateTime.tryParse(pt.date) ?? _now;
              final next = _findNextPrayer(pt);
              return RefreshIndicator(
                color: _kPrimary,
                onRefresh: provider.loadFromGps,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _Header(
                      cityName: cityName,
                      now: _now,
                      dateLabel: _formatDate(_now),
                      next: next,
                      onPickCity: _openCityPicker,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Jadwal Sholat Hari Ini',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _kInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(scheduleDate),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7C8A85),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._buildPrayerTiles(pt, next),
                        ],
                      ),
                    ),
                  ],
                ),
              );
          }
        },
      ),
    );
  }

  List<Widget> _buildPrayerTiles(
    PrayerTime pt,
    ({String name, DateTime time, IconData icon})? next,
  ) {
    final items = <(String, String, IconData)>[
      ('Imsak', pt.imsak, Icons.wb_twilight),
      ('Subuh', pt.subuh, Icons.wb_sunny),
      ('Terbit', pt.terbit, Icons.brightness_5),
      ('Dzuhur', pt.dzuhur, Icons.light_mode),
      ('Ashar', pt.ashar, Icons.wb_cloudy),
      ('Maghrib', pt.maghrib, Icons.wb_twilight),
      ('Isya', pt.isya, Icons.nights_stay),
    ];
    return [
      for (final (name, time, icon) in items)
        _PrayerTile(
          name: name,
          time: time,
          icon: icon,
          isNext: next != null && next.name == name,
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.cityName,
    required this.now,
    required this.dateLabel,
    required this.next,
    required this.onPickCity,
  });

  final String cityName;
  final DateTime now;
  final String dateLabel;
  final ({String name, DateTime time, IconData icon})? next;
  final VoidCallback onPickCity;

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kDeepGreen, _kPrimary, _kBright],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            const Positioned(
              top: -50,
              right: -40,
              child: Icon(
                Icons.nightlight_round,
                size: 200,
                color: Color(0x14FFFFFF),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: _kAmber,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          cityName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onPickCity,
                        tooltip: 'Ganti kota',
                        icon: const Icon(
                          Icons.location_city,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (next != null) _NextPrayerCard(next: next!, now: now),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextPrayerCard extends StatelessWidget {
  const _NextPrayerCard({required this.next, required this.now});

  final ({String name, DateTime time, IconData icon}) next;
  final DateTime now;

  String _countdown() {
    var diff = next.time.difference(now);
    if (diff.isNegative) diff = Duration.zero;
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    return '${_two(h)}:${_two(m)}:${_two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(next.icon, color: _kAmber, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MENUJU ${next.name.toUpperCase()}',
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _countdown(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${_two(next.time.hour)}:${_two(next.time.minute)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerTile extends StatelessWidget {
  const _PrayerTile({
    required this.name,
    required this.time,
    required this.icon,
    required this.isNext,
  });

  final String name;
  final String time;
  final IconData icon;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isNext ? const Color(0xFFE3F3EF) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isNext ? scheme.primary : const Color(0xFFE8EDEB),
          width: isNext ? 1.4 : 1,
        ),
        boxShadow: isNext
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isNext ? scheme.primary : const Color(0xFFEFF4F2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isNext ? Colors.white : _kPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _kInk,
                  ),
                ),
                if (isNext) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Berikutnya',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isNext ? scheme.primary : const Color(0xFF1B2B26),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kDeepGreen, _kPrimary],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 18),
              Text(
                'Memuat jadwal sholat...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onPickCity,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onPickCity;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kDeepGreen, _kPrimary],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: _kAmber,
                    size: 44,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Gagal memuat jadwal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7C8A85),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Gunakan lokasi saya'),
                  ),
                  TextButton(
                    onPressed: onPickCity,
                    child: const Text('Pilih kota manual'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}