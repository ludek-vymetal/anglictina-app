import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Hlas: appka mluví anglicky (TTS) a poslouchá tvou odpověď (rozpoznání řeči).
/// Ve verzi 1 obojí běží přímo v telefonu, zdarma.
class Voice {
  Voice._();
  static final Voice instance = Voice._();

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  bool _ttsReady = false;
  bool _sttReady = false;
  String? _enLocale;

  Future<void> say(String text, {bool slow = false}) async {
    if (!_ttsReady) {
      await _tts.setLanguage('en-US');
      await _tts.awaitSpeakCompletion(true);
      _ttsReady = true;
    }
    await _tts.setSpeechRate(slow ? 0.3 : 0.45);
    await _tts.speak(text);
  }

  Future<void> sayCzech(String text) async {
    await _tts.setLanguage('cs-CZ');
    await _tts.setSpeechRate(0.5);
    await _tts.speak(text);
    await _tts.setLanguage('en-US');
  }

  Future<bool> _initStt() async {
    if (_sttReady) return true;
    _sttReady = await _stt.initialize();
    if (_sttReady) {
      final locales = await _stt.locales();
      for (final l in locales) {
        if (l.localeId.toLowerCase().replaceAll('-', '_') == 'en_us') {
          _enLocale = l.localeId;
        }
      }
      _enLocale ??= locales
          .where((l) => l.localeId.toLowerCase().startsWith('en'))
          .map((l) => l.localeId)
          .firstOrNull;
    }
    return _sttReady;
  }

  /// Poslouchá, co řekneš anglicky. [onText] dostává průběžný text,
  /// [onDone] výsledný text, když domluvíš.
  Future<bool> listen({
    required void Function(String text) onText,
    required void Function(String text) onDone,
  }) async {
    if (!await _initStt()) return false;
    await _stt.listen(
      localeId: _enLocale,
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 2),
      onResult: (r) {
        onText(r.recognizedWords);
        if (r.finalResult) onDone(r.recognizedWords);
      },
    );
    return true;
  }

  Future<void> stop() async => _stt.stop();

  bool get isListening => _stt.isListening;

  /// Porovná, co jsi řekl, se správnou odpovědí (bez členů a interpunkce).
  static bool matches(String said, String target) {
    String norm(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z' ]"), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !{'a', 'an', 'the'}.contains(w))
        .join(' ');
    final s = norm(said);
    final t = norm(target);
    if (t.isEmpty) return false;
    return s == t || s.contains(t);
  }
}
