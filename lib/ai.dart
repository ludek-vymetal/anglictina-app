import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Jeden štítek, který AI našla na fotce.
class FoundLabel {
  final String en, cs, pron, sentenceEn, sentenceCs;
  final double x, y;
  FoundLabel(this.en, this.cs, this.pron, this.x, this.y, this.sentenceEn,
      this.sentenceCs);
}

/// Volání Claude API: pozná věci na fotce a vrátí anglické štítky.
///
/// Verze 1: klíč se předává při spuštění přes
/// `--dart-define=ANTHROPIC_API_KEY=...` (jen pro tvůj telefon).
/// Než appku pustíme dalším lidem, přesune se volání na malý server,
/// aby klíč nebyl uvnitř appky.
class Ai {
  static const _key = String.fromEnvironment('ANTHROPIC_API_KEY');
  static const _model = 'claude-sonnet-5-5';

  static bool get hasKey => _key.isNotEmpty;

  static const _prompt = '''
Jsi lektor angličtiny pro Čecha (začátečník). Na fotce je místo z jeho běžného dne: "{ROOM}".
Najdi 8–15 dobře viditelných předmětů, které se hodí naučit (běžné věci, ne značky).
Ke každému vrať:
- "en": anglický název s členem a/an jen když je to přirozené, jinak bez členu (např. "kettle", "cutting board")
- "cs": český překlad
- "pron": výslovnost přepsaná česky, jak by ji četl Čech (např. "ketl", "katyng bórd")
- "x", "y": střed předmětu na fotce jako číslo 0–1 (0,0 = levý horní roh)
- "sentence_en": krátká věta (max 8 slov) o činnosti s tím předmětem, v 1. osobě, přítomný čas (např. "I'm boiling water in the kettle.")
- "sentence_cs": její český překlad
Odpověz POUZE JSON polem objektů, bez dalšího textu.''';

  static Future<List<FoundLabel>> labelPhoto(File image, String roomName) async {
    if (!hasKey) {
      throw Exception(
          'Chybí API klíč. Spusť appku s --dart-define=ANTHROPIC_API_KEY=...');
    }
    final bytes = await image.readAsBytes();
    final body = jsonEncode({
      'model': _model,
      'max_tokens': 4000,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': base64Encode(bytes),
              }
            },
            {'type': 'text', 'text': _prompt.replaceAll('{ROOM}', roomName)},
          ]
        }
      ],
    });

    final res = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': _key,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: body,
    );
    if (res.statusCode != 200) {
      throw Exception('AI odpověděla chybou ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final text = (data['content'] as List)
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String)
        .join();
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start < 0 || end <= start) {
      throw Exception('AI nevrátila seznam štítků.');
    }
    final list = jsonDecode(text.substring(start, end + 1)) as List;

    double num01(dynamic v) =>
        ((v is num ? v.toDouble() : double.tryParse('$v') ?? 0.5))
            .clamp(0.0, 1.0);

    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return FoundLabel(
        '${m['en'] ?? ''}'.trim(),
        '${m['cs'] ?? ''}'.trim(),
        '${m['pron'] ?? ''}'.trim(),
        num01(m['x']),
        num01(m['y']),
        '${m['sentence_en'] ?? ''}'.trim(),
        '${m['sentence_cs'] ?? ''}'.trim(),
      );
    }).where((l) => l.en.isNotEmpty).toList();
  }
}
