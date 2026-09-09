import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/province.dart';
import '../models/city.dart';
import '../services/prayer_service.dart';
import '../providers/prayer_provider.dart';

class SelectCityScreen extends StatefulWidget {
  const SelectCityScreen({super.key});

  @override
  State<SelectCityScreen> createState() => _SelectCityScreenState();
}

class _SelectCityScreenState extends State<SelectCityScreen> {
  late Future<List<Province>> _provincesFuture;
  Province? _selectedProvince;
  Future<List<City>>? _citiesFuture;
  bool _submitting = false;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _provincesFuture = PrayerService.getProvinces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onProvinceSelected(Province province) {
    setState(() {
      _selectedProvince = province;
      _citiesFuture = PrayerService.getCities(province.id);
      _query = '';
      _searchController.clear();
    });
  }

  Future<void> _useMyLocation() async {
    setState(() => _submitting = true);
    await context.read<PrayerProvider>().loadFromGps();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onCitySelected(City city) async {
    if (city.latitude == null || city.longitude == null) {
      // Kalau list city tidak menyertakan koordinat, ambil detail dulu
      setState(() => _submitting = true);
      try {
        final detail = await PrayerService.getCityDetail(
          _selectedProvince!.id,
          city.id,
        );
        city = detail;
      } catch (e) {
        setState(() => _submitting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengambil detail kota: $e')),
          );
        }
        return;
      }
    }

    if (city.latitude == null || city.longitude == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kota ini tidak memiliki data koordinat.'),
          ),
        );
      }
      setState(() => _submitting = false);
      return;
    }

    await context.read<PrayerProvider>().loadFromManualCity(
          latitude: city.latitude!,
          longitude: city.longitude!,
          cityName: city.name,
        );

    setState(() => _submitting = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isProvinceStep = _selectedProvince == null;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(isProvinceStep ? 'Pilih Provinsi' : 'Pilih Kota'),
        leading: _selectedProvince != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _selectedProvince = null;
                  _citiesFuture = null;
                }),
              )
            : null,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0B3D2E),
                Theme.of(context).colorScheme.primary,
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ListCard(
                      icon: Icons.my_location,
                      title: 'Gunakan lokasi saya',
                      subtitle: 'Deteksi otomatis dari GPS perangkat',
                      onTap: _useMyLocation,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (v) =>
                          setState(() => _query = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: isProvinceStep
                            ? 'Cari provinsi...'
                            : 'Cari kota...',
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isProvinceStep
                    ? _buildProvinceList()
                    : _buildCityList(),
              ),
            ],
          ),
          if (_submitting)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildProvinceList() {
    return FutureBuilder<List<Province>>(
      future: _provincesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ListError(
            message: 'Gagal memuat daftar provinsi.',
            onRetry: () => setState(() {
              _provincesFuture = PrayerService.getProvinces();
            }),
          );
        }
        final provinces = (snapshot.data ?? [])
            .where((p) => p.name.toLowerCase().contains(_query))
            .toList();
        if (provinces.isEmpty) return const _EmptyResult();
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: provinces.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final p = provinces[i];
            return _ListCard(
              icon: Icons.map_outlined,
              title: p.name,
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(0xFF9AA8A3),
              ),
              onTap: () => _onProvinceSelected(p),
            );
          },
        );
      },
    );
  }

  Widget _buildCityList() {
    final savedCityName = context.read<PrayerProvider>().savedCityName;
    return FutureBuilder<List<City>>(
      future: _citiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ListError(
            message: 'Gagal memuat daftar kota.',
            onRetry: () => setState(() {
              _citiesFuture =
                  PrayerService.getCities(_selectedProvince!.id);
            }),
          );
        }
        final cities = (snapshot.data ?? [])
            .where((c) => c.name.toLowerCase().contains(_query))
            .toList();
        if (cities.isEmpty) return const _EmptyResult();
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: cities.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = cities[i];
            final isSelected = savedCityName == c.name;
            return _ListCard(
              icon: Icons.location_city,
              title: c.name,
              isSelected: isSelected,
              trailing: isSelected
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => _onCitySelected(c),
            );
          },
        );
      },
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.isSelected = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? scheme.primary : const Color(0xFFE8EDEB),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFE3F3EF)
                      : const Color(0xFFEFF4F2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: scheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B2B26),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7C8A85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.search_off, size: 44, color: Color(0xFFB9C4C0)),
          SizedBox(height: 10),
          Text(
            'Tidak ditemukan',
            style: TextStyle(color: Color(0xFF7C8A85)),
          ),
        ],
      ),
    );
  }
}

class _ListError extends StatelessWidget {
  const _ListError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 40,
            color: Color(0xFFB9C4C0),
          ),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: Color(0xFF7C8A85))),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Muat ulang'),
          ),
        ],
      ),
    );
  }
}