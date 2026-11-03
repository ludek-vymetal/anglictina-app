import 'dart:io';

import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../srs.dart';
import '../voice.dart';

/// Zkoušení: na fotce bliká místo, ty řekneš anglicky, co tam je.
/// Žádné možnosti na výběr – slovo si musíš vybavit sám.
class ReviewScreen extends StatefulWidget {
  final int? roomId; // null = všechny místnosti
  const ReviewScreen({super.key, this.roomId});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

enum _Phase { ask, listening, revealed }

class _ReviewScreenState extends State<ReviewScreen>
    with SingleTickerProviderStateMixin {
  final List<Word> _queue = [];
  final Map<int, Room> _rooms = {};
  bool _loading = true;
  int _done = 0;
  _Phase _phase = _Phase.ask;
  String _heard = '';
  bool? _correct;
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  Word? get _current => _queue.isEmpty ? null : _queue.first;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pulse.dispose();
    Voice.instance.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final rooms = await Db.instance.rooms();
    final q = await Db.instance.dueQueue(roomId: widget.roomId);
    if (!mounted) return;
    setState(() {
      for (final r in rooms) {
        _rooms[r.id!] = r;
      }
      _queue.addAll(q);
      _loading = false;
    });
  }

  Future<void> _listen() async {
    final w = _current;
    if (w == null) return;
    setState(() {
      _phase = _Phase.listening;
      _heard = '';
      _correct = null;
    });
    final ok = await Voice.instance.listen(
      onText: (t) {
        if (mounted) setState(() => _heard = t);
      },
      onDone: (t) {
        if (!mounted) return;
        final right = Voice.matches(t, w.en);
        setState(() {
          _heard = t;
          _correct = right;
        });
        _reveal();
      },
    );
    if (!ok && mounted) {
      setState(() => _phase = _Phase.ask);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Mikrofon nejde zapnout. Povol ho appce v nastavení telefonu.')));
    }
  }

  Future<void> _reveal() async {
    await Voice.instance.stop();
    final w = _current;
    if (w == null || !mounted) return;
    setState(() => _phase = _Phase.revealed);
    await Voice.instance.say(w.en);
  }

  Future<void> _grade(Grade g) async {
    final w = _current;
    if (w == null) return;
    final wasNew = w.isNew;
    Srs.apply(w, g);
    await Db.instance.updateWord(w);
    if (wasNew) await Db.instance.markNewIntroduced();
    await Db.instance.markPracticed();
    setState(() {
      _queue.removeAt(0);
      // zapomenuté slovo se v tomhle bloku vrátí ještě jednou, o 3 slova dál
      if (g == Grade.again) {
        _queue.insert(_queue.length < 3 ? _queue.length : 3, w);
      } else {
        _done += 1;
      }
      _phase = _Phase.ask;
      _heard = '';
      _correct = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = _current;
    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? 'Zkoušení' : 'Hotovo $_done · zbývá ${_queue.length}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : w == null
              ? _finished()
              : _card(w),
    );
  }

  Widget _finished() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle, size: 72),
            const SizedBox(height: 16),
            Text('Hotovo, $_done slov.',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
                'Každé slovo přijde znovu přesně ve chvíli, kdy ho začneš zapomínat.',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zpět')),
          ]),
        ),
      );

  Widget _card(Word w) {
    final room = _rooms[w.roomId];
    final t = Theme.of(context).textTheme;
    return Column(children: [
      if (room != null)
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: room.width / room.height,
              child: LayoutBuilder(builder: (_, box) {
                final W = box.maxWidth, H = box.maxHeight;
                return Stack(children: [
                  Positioned.fill(
                      child:
                          Image.file(File(room.imagePath), fit: BoxFit.fill)),
                  Positioned(
                    left: w.x * W,
                    top: w.y * H,
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, -0.5),
                      child: _phase == _Phase.revealed
                          ? _answerChip(w.en)
                          : ScaleTransition(
                              scale: Tween(begin: 0.8, end: 1.2)
                                  .animate(_pulse),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xCCFFC400),
                                  border:
                                      Border.all(color: Colors.white, width: 3),
                                ),
                              ),
                            ),
                    ),
                  ),
                ]);
              }),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(room?.name ?? '', style: t.labelLarge),
              const SizedBox(height: 4),
              Text('Řekni anglicky: ${w.cs}',
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (_heard.isNotEmpty)
                Text('Slyším: „$_heard“',
                    style: t.titleMedium?.copyWith(
                        color: _correct == null
                            ? null
                            : _correct!
                                ? Colors.greenAccent
                                : Colors.orangeAccent)),
              if (_phase == _Phase.revealed) ..._revealed(w),
              if (_phase != _Phase.revealed) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: Icon(
                      _phase == _Phase.listening ? Icons.graphic_eq : Icons.mic),
                  label: Text(_phase == _Phase.listening
                      ? 'Poslouchám…'
                      : 'Říct nahlas'),
                  onPressed: _phase == _Phase.listening ? _reveal : _listen,
                ),
                TextButton(onPressed: _reveal, child: const Text('Nevím, ukaž')),
              ],
            ]),
      ),
    ]);
  }

  List<Widget> _revealed(Word w) {
    final t = Theme.of(context).textTheme;
    return [
      if (_correct == true)
        Text('Správně!',
            style: t.titleLarge?.copyWith(color: Colors.greenAccent)),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
          child: Text(
            w.pron.isEmpty ? w.en : '${w.en}  [${w.pron}]',
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () => Voice.instance.say(w.en)),
      ]),
      if (w.sentenceEn.isNotEmpty)
        InkWell(
          onTap: () => Voice.instance.say(w.sentenceEn),
          child: Text('${w.sentenceEn}\n${w.sentenceCs}',
              style: const TextStyle(fontStyle: FontStyle.italic)),
        ),
      if (Srs.isLeech(w))
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
              'Tohle slovo ti utíká. Vymysli si k němu vtipný obrázek nebo spojení s češtinou.'),
        ),
      const SizedBox(height: 16),
      Row(children: [
        _gradeBtn('Nevěděl', Grade.again, Colors.redAccent),
        _gradeBtn('Těžké', Grade.hard, Colors.orangeAccent),
        _gradeBtn('Věděl', Grade.good, Colors.greenAccent,
            highlight: _correct == true),
        _gradeBtn('Snadné', Grade.easy, Colors.lightBlueAccent),
      ]),
    ];
  }

  Widget _gradeBtn(String label, Grade g, Color c, {bool highlight = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: c,
            side: BorderSide(color: c, width: highlight ? 3 : 1),
            padding: EdgeInsets.zero,
          ),
          onPressed: () => _grade(g),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _answerChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xE61E5EFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      );
}
