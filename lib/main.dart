import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Call Analytics',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<CallLogEntry> calls = [];
  bool loading = true, denied = false;
  int days = 30;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final status = await Permission.phone.request();
    if (!status.isGranted) {
      setState(() { denied = true; loading = false; });
      return;
    }
    final from = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final entries = await CallLog.query(dateFrom: from);
    setState(() { calls = entries.toList(); denied = false; loading = false; });
  }

  String fmt(int s) => '${s ~/ 3600}h ${(s % 3600) ~/ 60}m';

  @override
  Widget build(BuildContext context) {
    final incoming = calls.where((c) => c.callType == CallType.incoming).length;
    final outgoing = calls.where((c) => c.callType == CallType.outgoing).length;
    final missed = calls.where((c) => c.callType == CallType.missed).length;
    final talk = calls.fold<int>(0, (a, c) => a + (c.duration ?? 0));
    final hours = List<int>.filled(24, 0);
    final contacts = <String, int>{};
    for (final c in calls) {
      final t = DateTime.fromMillisecondsSinceEpoch(c.timestamp ?? 0);
      hours[t.hour]++;
      final k = (c.name?.isNotEmpty ?? false) ? c.name! : (c.number ?? 'Unknown');
      contacts[k] = (contacts[k] ?? 0) + 1;
    }
    final top = contacts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxH = hours.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Call Analytics'), actions: [
        PopupMenuButton<int>(
          onSelected: (v) { days = v; load(); },
          itemBuilder: (_) => [7, 30, 90].map((d) => PopupMenuItem(value: d, child: Text('Last $d days'))).toList(),
        ),
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : denied
              ? Center(child: FilledButton(onPressed: openAppSettings, child: const Text('Allow call log permission')))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  Text('Last $days days', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    stat('Total', '${calls.length}'),
                    stat('Incoming', '$incoming'),
                    stat('Outgoing', '$outgoing'),
                    stat('Missed', '$missed'),
                    stat('Talk time', fmt(talk)),
                  ]),
                  const SizedBox(height: 20),
                  Text('Busiest hours', style: Theme.of(context).textTheme.titleMedium),
                  for (var h = 0; h < 24; h++)
                    if (hours[h] > 0)
                      Row(children: [
                        SizedBox(width: 44, child: Text('${h.toString().padLeft(2, '0')}:00')),
                        Expanded(child: LinearProgressIndicator(value: hours[h] / maxH, minHeight: 10)),
                        SizedBox(width: 36, child: Text(' ${hours[h]}')),
                      ]),
                  const SizedBox(height: 20),
                  Text('Top contacts', style: Theme.of(context).textTheme.titleMedium),
                  for (final e in top.take(10)) ListTile(dense: true, title: Text(e.key), trailing: Text('${e.value}')),
                ]),
    );
  }

  Widget stat(String l, String v) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text(l)]),
        ),
      );
}
