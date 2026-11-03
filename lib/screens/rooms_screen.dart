import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../ai.dart';
import '../db.dart';
import '../models.dart';
import 'photo_screen.dart';

/// Seznam místností (fotek) – tvůj paměťový palác.
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  List<Room> _rooms = [];
  bool _busy = false;
  String _busyText = '';

  static const _suggestions = [
    'Kuchyň',
    'Ložnice',
    'Chodba',
    'Koupelna',
    'Obývák',
    'Fitko',
    'Auto',
    'Cesta do práce',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Db.instance.rooms();
    if (mounted) setState(() => _rooms = r);
  }

  Future<String?> _askName() async {
    final used = _rooms.map((r) => r.name).toSet();
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Co fotíš?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions
                .where((s) => !used.contains(s))
                .map((s) => ActionChip(
                    label: Text(s), onPressed: () => Navigator.pop(ctx, s)))
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Vlastní název'),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Zrušit')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Dál')),
        ],
      ),
    );
  }

  Future<void> _addRoom(ImageSource source) async {
    final name = await _askName();
    if (name == null || name.isEmpty) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() {
      _busy = true;
      _busyText = 'Hledám věci na fotce…';
    });
    try {
      // fotku si uložíme do appky, aby nezmizela z galerie
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(
          dir.path, 'room_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final file = await File(picked.path).copy(path);

      final bytes = await file.readAsBytes();
      final img = await decodeImageFromList(bytes);
      final w = img.width.toDouble(), h = img.height.toDouble();
      img.dispose();

      final labels = await Ai.labelPhoto(file, name);

      final now = DateTime.now().millisecondsSinceEpoch;
      final roomId = await Db.instance.addRoom(Room(
          name: name, imagePath: path, width: w, height: h, created: now));
      for (final l in labels) {
        await Db.instance.addWord(Word(
          roomId: roomId,
          en: l.en,
          cs: l.cs,
          pron: l.pron,
          x: l.x,
          y: l.y,
          sentenceEn: l.sentenceEn,
          sentenceCs: l.sentenceCs,
          created: now,
        ));
      }
      await _load();
      if (!mounted) return;
      final room = _rooms.firstWhere((r) => r.id == roomId);
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => PhotoScreen(room: room)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Nepovedlo se: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteRoom(Room r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Smazat „${r.name}“?'),
        content: const Text('Smažou se i všechna slova z této fotky.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ne')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Smazat')),
        ],
      ),
    );
    if (ok != true) return;
    await Db.instance.deleteRoom(r.id!);
    try {
      await File(r.imagePath).delete();
    } catch (_) {}
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moje místnosti')),
      floatingActionButton: _busy
          ? null
          : Column(mainAxisSize: MainAxisSize.min, children: [
              FloatingActionButton.small(
                heroTag: 'gallery',
                tooltip: 'Z galerie',
                onPressed: () => _addRoom(ImageSource.gallery),
                child: const Icon(Icons.photo_library),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'camera',
                icon: const Icon(Icons.photo_camera),
                label: const Text('Vyfotit'),
                onPressed: () => _addRoom(ImageSource.camera),
              ),
            ]),
      body: Stack(children: [
        if (_rooms.isEmpty && !_busy)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Zatím tu nic není.\nVyfoť kuchyň, ložnici nebo fitko a appka k věcem napíše anglické názvy.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 140),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85),
          itemCount: _rooms.length,
          itemBuilder: (_, i) {
            final r = _rooms[i];
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PhotoScreen(room: r)));
                _load();
              },
              onLongPress: () => _deleteRoom(r),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                          child:
                              Image.file(File(r.imagePath), fit: BoxFit.cover)),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(r.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                    ]),
              ),
            );
          },
        ),
        if (_busy)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_busyText),
              ]),
            ),
          ),
      ]),
    );
  }
}

