import 'package:anglictina_app/models.dart';
import 'package:anglictina_app/srs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Word word() => Word(roomId: 1, en: 'kettle', cs: 'konvice', x: 0.5, y: 0.5, created: 0);

  test('správně zodpovězené slovo přijde za čím dál delší dobu', () {
    final w = word();
    final now = DateTime(2026, 11, 3);
    Srs.apply(w, Grade.good, now: now);
    expect(w.interval, 1.0);
    Srs.apply(w, Grade.good, now: now);
    expect(w.interval, 3.0);
    Srs.apply(w, Grade.good, now: now);
    expect(w.interval, greaterThan(3.0));
  });

  test('zapomenuté slovo přijde za 10 minut', () {
    final w = word();
    final now = DateTime(2026, 11, 3, 10);
    Srs.apply(w, Grade.again, now: now);
    expect(w.due, now.add(const Duration(minutes: 10)).millisecondsSinceEpoch);
    expect(w.lapses, 1);
  });
}
