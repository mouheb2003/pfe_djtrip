import 'package:just_audio/just_audio.dart';

/// Sons d'appel (ringback / incoming).
/// Ajoutez dans assets/sounds/ : ring_back.mp3 (son en attente), incoming_call.mp3 (son entrant).
class CallSoundService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playRingback() async {
    await stop();
    try {
      await _player.setAsset('assets/sounds/ring_back.mp3');
      await _player.setLoopMode(LoopMode.one);
      await _player.play();
    } catch (_) {}
  }

  static Future<void> playIncoming() async {
    await stop();
    try {
      await _player.setAsset('assets/sounds/incoming_call.mp3');
      await _player.setLoopMode(LoopMode.one);
      await _player.play();
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }
}
