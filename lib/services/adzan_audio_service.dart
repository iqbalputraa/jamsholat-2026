import 'dart:async';

import 'package:just_audio/just_audio.dart';

class AdzanAudioService {
  static final AdzanAudioService _instance = AdzanAudioService._();
  factory AdzanAudioService() => _instance;
  AdzanAudioService._();

  final _player = AudioPlayer();
  Timer? _cooldownTimer;
  static const _cooldownSeconds = 60;

  bool get _isOnCooldown => _cooldownTimer != null;

  Future<void> _startCooldown() async {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(
      Duration(seconds: _cooldownSeconds),
      () => _cooldownTimer = null,
    );
  }

  /// Mainkan adzan sekali per [cooldownSeconds] detik.
  /// [assetPath] bisa berupa path assets, mis. 'assets/adzan.mp3'.
  Future<void> play({required String assetPath}) async {
    if (_isOnCooldown) return;
    try {
      // Pakai AudioSource.uri agar bisa mainkan dari folder assets
      // Flutter lewat skema asset:
      // https://pub.dev/packages/just_audio#local-files
      // Setelah main, mulai cooldown biar nggak perpanjang di detik
      // berikutnya.
      final source = AudioSource.uri(
        Uri.parse('asset:///$assetPath'),
      );
      await _player.setAudioSource(source);
      await _player.play();
      _startCooldown();
    } catch (e) {
      // Biar kegagalan audio tidak bikin app selamat / crash.
      // Mis. file asset belum disertakan di pubspec, atau error decode.
    }
  }

  /// Paksa berhenti (mis. user matikan fitur).
  Future<void> stop() async {
    await _player.stop();
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
  }

  /// Lepaskan listener / matikan engine audio.
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
