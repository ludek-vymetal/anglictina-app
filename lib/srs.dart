import 'models.dart';

/// Hodnocení po odpovědi.
enum Grade { again, hard, good, easy }

/// Opakování v rozestupech (zjednodušený algoritmus SM-2).
///
/// Co jde, přijde za delší dobu. Co zapomeneš, přijde za 10 minut znovu.
/// Ve verzi 5 ho vyměníme za přesnější FSRS.
class Srs {
  static const int newPerDay = 15;

  static void apply(Word w, Grade g, {DateTime? now}) {
    final t = now ?? DateTime.now();
    switch (g) {
      case Grade.again:
        w.lapses += 1;
        w.reps = 0;
        w.ease = (w.ease - 0.2).clamp(1.3, 3.0);
        w.interval = 0.0;
        w.due = t.add(const Duration(minutes: 10)).millisecondsSinceEpoch;
        return;
      case Grade.hard:
        w.interval = w.reps == 0 ? 1.0 : (w.interval * 1.2).clamp(1.0, 365.0);
        w.ease = (w.ease - 0.15).clamp(1.3, 3.0);
        break;
      case Grade.good:
        if (w.reps == 0) {
          w.interval = 1.0;
        } else if (w.reps == 1) {
          w.interval = 3.0;
        } else {
          w.interval = (w.interval * w.ease).clamp(1.0, 365.0);
        }
        break;
      case Grade.easy:
        w.interval =
            w.reps == 0 ? 3.0 : (w.interval * w.ease * 1.3).clamp(1.0, 365.0);
        w.ease = (w.ease + 0.15).clamp(1.3, 3.0);
        break;
    }
    w.reps += 1;
    final minutes = (w.interval * 24 * 60).round();
    w.due = t.add(Duration(minutes: minutes)).millisecondsSinceEpoch;
  }

  /// Slovo, které zapomínáš pořád dokola – dostane pomůcku (verze 5).
  static bool isLeech(Word w) => w.lapses >= 3;
}
