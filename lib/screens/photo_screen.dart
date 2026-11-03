import 'dart:io';

import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../voice.dart';
import 'review_screen.dart';

/// Fotka místnosti s anglickými štítky.
/// Ťukni = výslovnost a detail, táhni = posuň štítek,
/// dlouze podrž na fotce = přidej vlastní slovo.
class PhotoScreen extends StatefulWidget {
  final Room room;
  const PhotoScreen({super.key, required this.room});

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  List<Word> _words = [];
  bool _hidden = false;
  int? _revealed; // id slova odkrytého v režimu „skrýt názvy“

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = await Db.instance.wordsInRoom(widget.room.id!);
    if (mounted) setState(() => _words = w);
  }

  Future<void> _showWord(Word w) async {
    Voice.instance.say(w.en);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(w.en,
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.w800)),
              ),
              IconButton.filledTonal(
                  icon: const Icon(Icons.volume_up),
                  onPressed: () => Voice.instance.say(w.en)),
              IconButton(
                  tooltip: 'Pomalu',
                  icon: const Icon(Icons.slow_motion_video),
                  onPressed: () => Voice.instance.say(w.en, slow: true)),
            ]),
            if (w.pron.isNotEmpty)
              Text('[${w.pron}]', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(w.cs, style: const TextStyle(fontSize: 20)),
            if (w.sentenceEn.isNotEmpty) ...[
              const Divider(height: 32),
              InkWell(
                onTap: () => Voice.instance.say(w.sentenceEn),
                child: Row(children: [
                  const Icon(Icons.volume_up, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(w.sentenceEn,
                          style: const TextStyle(
                              fontSize: 18, fontStyle: FontStyle.italic))),
                ]),
              ),
              const SizedBox(height: 4),
              Text(w.sentenceCs),
            ],
            const SizedBox(height: 20),
            Row(children: [
              TextButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Opravit'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _editWord(w);
                },
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Smazat'),
                onPressed: () async {
                  await Db.instance.deleteWord(w.id!);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }

  /// Dialog pro nové nebo opravené slovo.
  Future<void> _editWord(Word? existing, {double? x, double? y}) async {
    final en = TextEditingController(text: existing?.en ?? '');
    final cs = TextEditingController(text: existing?.cs ?? '');
    final pron = TextEditingController(text: existing?.pron ?? '');
    final sEn = TextEditingController(text: existing?.sentenceEn ?? '');
    final sCs = TextEditingController(text: existing?.sentenceCs ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nové slovo' : 'Opravit slovo'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: en,
                decoration: const InputDecoration(labelText: 'Anglicky')),
            TextField(
                controller: cs,
                decoration: const InputDecoration(labelText: 'Česky')),
            TextField(
                controller: pron,
                decoration: const InputDecoration(
                    labelText: 'Výslovnost (nepovinné)')),
            TextField(
                controller: sEn,
                decoration: const InputDecoration(
                    labelText: 'Věta anglicky (nepovinné)')),
            TextField(
                controller: sCs,
                decoration: const InputDecoration(
                    labelText: 'Věta česky (nepovinné)')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Zrušit')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Uložit')),
        ],
      ),
    );
    if (ok != true || en.text.trim().isEmpty) return;
    if (existing == null) {
      await Db.instance.addWord(Word(
        roomId: widget.room.id!,
        en: en.text.trim(),
        cs: cs.text.trim(),
        pron: pron.text.trim(),
        x: x ?? 0.5,
        y: y ?? 0.5,
        sentenceEn: sEn.text.trim(),
        sentenceCs: sCs.text.trim(),
        created: DateTime.now().millisecondsSinceEpoch,
      ));
    } else {
      existing
        ..en = en.text.trim()
        ..cs = cs.text.trim()
        ..pron = pron.text.trim()
        ..sentenceEn = sEn.text.trim()
        ..sentenceCs = sCs.text.trim();
      await Db.instance.updateWord(existing);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    return Scaffold(
      appBar: AppBar(
        title: Text(room.name),
        actions: [
          IconButton(
            tooltip: _hidden ? 'Ukázat názvy' : 'Skrýt názvy',
            icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() {
              _hidden = !_hidden;
              _revealed = null;
            }),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: room.width / room.height,
              child: LayoutBuilder(builder: (context, box) {
                final W = box.maxWidth, H = box.maxHeight;
                return GestureDetector(
                  onLongPressStart: (d) => _editWord(null,
                      x: d.localPosition.dx / W, y: d.localPosition.dy / H),
                  child: Stack(children: [
                    Positioned.fill(
                        child:
                            Image.file(File(room.imagePath), fit: BoxFit.fill)),
                    for (final w in _words)
                      Positioned(
                        left: w.x * W,
                        top: w.y * H,
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, -0.5),
                          child: GestureDetector(
                            onTap: () {
                              if (_hidden && _revealed != w.id) {
                                setState(() => _revealed = w.id);
                                Voice.instance.say(w.en);
                              } else {
                                _showWord(w);
                              }
                            },
                            onPanUpdate: (d) => setState(() {
                              w.x = (w.x + d.delta.dx / W).clamp(0.0, 1.0);
                              w.y = (w.y + d.delta.dy / H).clamp(0.0, 1.0);
                            }),
                            onPanEnd: (_) => Db.instance.updateWord(w),
                            child: _Label(
                                text: _hidden && _revealed != w.id
                                    ? '?'
                                    : w.en),
                          ),
                        ),
                      ),
                  ]),
                );
              }),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            _hidden
                ? 'Ukaž na otazník, řekni slovo nahlas a pak ťukni pro kontrolu.'
                : 'Ťukni na štítek = výslovnost. Táhni = posuň. Podrž na fotce = přidej slovo.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: const Icon(Icons.mic),
            label: const Text('Zkoušet tuhle místnost'),
            onPressed: _words.isEmpty
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ReviewScreen(roomId: room.id))),
          ),
        ),
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xE61E5EFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
    );
  }
}
