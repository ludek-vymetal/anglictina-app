/// Místnost = jedna fotka (kuchyň, ložnice, fitko, cesta do práce...).
class Room {
  final int? id;
  final String name;
  final String imagePath;
  final double width;
  final double height;
  final int created;

  Room({
    this.id,
    required this.name,
    required this.imagePath,
    required this.width,
    required this.height,
    required this.created,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'image_path': imagePath,
        'width': width,
        'height': height,
        'created': created,
      };

  factory Room.fromMap(Map<String, Object?> m) => Room(
        id: m['id'] as int,
        name: m['name'] as String,
        imagePath: m['image_path'] as String,
        width: (m['width'] as num).toDouble(),
        height: (m['height'] as num).toDouble(),
        created: m['created'] as int,
      );
}

/// Jedno slovo se štítkem na fotce + stav opakování.
class Word {
  final int? id;
  final int roomId;
  String en;
  String cs;
  String pron; // výslovnost přepsaná česky, např. "ketl"
  double x; // 0–1, pozice štítku na fotce
  double y;
  String sentenceEn;
  String sentenceCs;

  // stav opakování (viz srs.dart)
  int due; // ms od 1970, kdy má slovo přijít znovu
  double interval; // dny
  double ease;
  int reps; // kolikrát po sobě správně
  int lapses; // kolikrát zapomenuto
  final int created;

  Word({
    this.id,
    required this.roomId,
    required this.en,
    required this.cs,
    this.pron = '',
    required this.x,
    required this.y,
    this.sentenceEn = '',
    this.sentenceCs = '',
    this.due = 0,
    this.interval = 0,
    this.ease = 2.5,
    this.reps = 0,
    this.lapses = 0,
    required this.created,
  });

  /// Slovo, které ještě nikdy nebylo ve zkoušení.
  bool get isNew => reps == 0 && lapses == 0;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'room_id': roomId,
        'en': en,
        'cs': cs,
        'pron': pron,
        'x': x,
        'y': y,
        'sentence_en': sentenceEn,
        'sentence_cs': sentenceCs,
        'due': due,
        'interval': interval,
        'ease': ease,
        'reps': reps,
        'lapses': lapses,
        'created': created,
      };

  factory Word.fromMap(Map<String, Object?> m) => Word(
        id: m['id'] as int,
        roomId: m['room_id'] as int,
        en: m['en'] as String,
        cs: m['cs'] as String,
        pron: (m['pron'] as String?) ?? '',
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        sentenceEn: (m['sentence_en'] as String?) ?? '',
        sentenceCs: (m['sentence_cs'] as String?) ?? '',
        due: m['due'] as int,
        interval: (m['interval'] as num).toDouble(),
        ease: (m['ease'] as num).toDouble(),
        reps: m['reps'] as int,
        lapses: m['lapses'] as int,
        created: m['created'] as int,
      );
}
