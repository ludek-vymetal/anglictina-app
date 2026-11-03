import 'package:flutter/material.dart';

import '../db.dart';
import 'review_screen.dart';
import 'rooms_screen.dart';

/// Obrazovka „Dnes“ – vždy řekne, co máš právě dělat.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, int>? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await Db.instance.stats();
    if (mounted) setState(() => _stats = s);
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    final t = Theme.of(context).textTheme;
    final toReview = s == null ? 0 : s['due']! + s['newToday']!;

    return Scaffold(
      appBar: AppBar(title: const Text('Dnes')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(children: [
                    _Stat(label: 'dní v řadě', value: '${s['streak']}'),
                    _Stat(label: 'umíš (7+ dní)', value: '${s['learned']}'),
                    _Stat(label: 'slov celkem', value: '${s['total']}'),
                  ]),
                  const SizedBox(height: 28),
                  if (s['total'] == 0) ...[
                    Text('Začni první fotkou',
                        style: t.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                        'Vyfoť kuchyň. Appka na fotce najde věci a napíše k nim anglické názvy.'),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Vyfotit první místnost'),
                      onPressed: () => _open(const RoomsScreen()),
                    ),
                  ] else ...[
                    Text(
                        toReview == 0
                            ? 'Na dnešek máš hotovo'
                            : 'Teď na řadě: $toReview slov',
                        style: t.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(toReview == 0
                        ? 'Další slova přijdou, až je začneš zapomínat. Klidně přidej novou místnost.'
                        : '${s['due']} k opakování, ${s['newToday']} nových. Odpovídej nahlas.'),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      icon: const Icon(Icons.mic),
                      label: const Text('Začít zkoušení'),
                      onPressed: toReview == 0
                          ? null
                          : () => _open(const ReviewScreen()),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52)),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Moje místnosti'),
                      onPressed: () => _open(const RoomsScreen()),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Text('Tip na dnešek', style: t.titleMedium),
                  const SizedBox(height: 6),
                  const Text(
                      'Málo, ale často: 3–4 krátké bloky během dne fungují líp než jedna dlouhá hodina. '
                      'Večer před spaním si dej ještě 5 minut opakování.'),
                ],
              ),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(children: [
            Text(value,
                style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            Text(label, style: t.bodySmall, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
