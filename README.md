# Semoga Bisa - Jadwal Sholat App

Aplikasi jadwal sholat digital untuk Indonesia yang dibangun dengan Flutter. Aplikasi ini menampilkan waktu sholat harian secara *real-time*, hitung mundur menuju sholat berikutnya, serta pemutaran adzan otomatis ketika waktu sholat tiba.

## Fitur Utama

- **Jadwal Sholat Harian** - Menampilkan 7 waktu sholat (Imsak, Subuh, Terbit, Dzuhur, Ashar, Maghrib, Isya)
- **Jam Digital Real-Time** - Jam yang diperbarui setiap detik
- **Hitung Mundur Sholat** - Countdown menuju waktu sholat berikutnya
- **Adzan Otomatis** - Pemutaran audio adzan otomatis saat waktu sholat tiba
- **Pencarian Kota** - Pilih provinsi dan kota secara manual atau gunakan lokasi GPS
- **Penentuan Lokasi Otomatis** - Mendeteksi lokasi pengguna dan menyesuaikan jadwal sholat terdekat
- **Tema Material 3** - Desain modern dengan warna hijau yang menenangkan

## Teknologi yang Digunakan

| Teknologi | Keterangan |
|---|---|
| **Flutter** | Framework cross-platform (Android, iOS, Web, Desktop) |
| **Dart** | Bahasa pemrograman |
| **Provider** | State management |
| **HTTP** | REST API client |
| **Geolocator** | Akses lokasi GPS |
| **SharedPreferences** | Penyimpanan data lokal |
| **Just Audio** | Pemutaran audio adzan |

## Struktur Proyek

```
lib/
├── main.dart                    # Entry point aplikasi
├── models/
│   ├── city.dart                # Model data kota
│   ├── province.dart            # Model data provinsi
│   └── prayer_time.dart         # Model data waktu sholat
├── providers/
│   └── prayer_provider.dart     # State management & logic
├── screens/
│   ├── home_screen.dart         # Halaman utama
│   └── select_city_screen.dart  # Pemilihan provinsi & kota
└── services/
    ├── prayer_service.dart      # REST API client
    ├── location_service.dart    # Layanan lokasi GPS
    └── adzan_audio_service.dart # Layanan pemutaran adzan
```

## Persiapan

### Prasyarat

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.44.0)
- [Dart SDK](https://dart.dev/get-dart) (>= 3.12.0)
- IDE (VS Code, Android Studio, atau IntelliJ)
- Device atau emulator untuk menjalankan aplikasi

### Instalasi

1. Clone repository ini:

```bash
git clone https://github.com/iqbalputraa/jamsholat-2026.git
cd semogabisa
```

2. Install dependencies:

```bash
flutter pub get
```

3. Tambahkan file audio adzan (`adzan.mp3`) ke folder `assets/`:

```
assets/
└── adzan.mp3
```

4. Jalankan aplikasi:

```bash
flutter run
```

### Build

```bash
# Android APK
flutter build apk --release

# Web
flutter build web

# Windows Desktop
flutter build windows
```

## API

Aplikasi ini menggunakan REST API dari [waktu-sholat](https://github.com/maftuh23/waktu-sholat) untuk mendapatkan data jadwal sholat Indonesia.

### Endpoint

| Endpoint | Keterangan |
|---|---|
| `GET /province` | Mendapatkan daftar provinsi |
| `GET /province/{id}/city` | Mendapatkan daftar kota berdasarkan provinsi |
| `GET /prayer?latitude=...&longitude=...` | Mendapatkan jadwal sholat berdasarkan koordinat |

## Platform yang Didukung

- [x] Android
- [ ] iOS
- [x] Web
- [x] Windows
- [ ] macOS
- [ ] Linux

## Developer

**Mochiqbaal Putra Muhajir**

## Lisensi

Proyek ini merupakan proyek pribadi untuk keperluan belajar dan pengembangan.

---

Dibuat dengan ❤ menggunakan Flutter
