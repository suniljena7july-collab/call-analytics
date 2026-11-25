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
  late DateTimeRange range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    range = DateTimeRange(
      start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)),
      end: DateTime(now.year, now.month, now.day),
    );
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final status = await Permission.phone.request();
    if (!status.isGranted) {
      setState(() { denied = true; loading = false; });
      return;
    }
    final from = range.start.millisecondsSinceEpoch;
    final to = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59)
        .millisecondsSinceEpoch;
    final entries = await CallLog.query(dateFrom: from, dateTo: to);
    setState(() { calls = entries.toList(); denied = false; loading = false; });
  }

  void setRange(int daysBack) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    range = DateTimeRange(start: today.subtract(Duration(days: daysBack)), end: today);
    load();
  }

  void setYesterday() {
    final now = DateTime.now();
    final y = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    range = DateTimeRange(start: y, end: y);
    load();
  }

  Future<void> pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: range,
    );
    if (picked != null) {
      range = picked;
      load();
    }
  }

  String two(int n) => n.toString().padLeft(2, '0');
  String dstr(DateTime d) => '${two(d.day)}-${two(d.month)}-${d.year}';
  String fmt(int s) => s >= 3600
      ? '${s ~/ 3600}h ${(s % 3600) ~/ 60}m'
      : '${s ~/ 60}m ${s % 60}s';

  String typeLabel(CallType? t) {
    if (t == CallType.incoming) return 'Incoming';
    if (t == CallType.outgoing) return 'Outgoing';
    if (t == CallType.missed) return 'Missed';
    if (t == CallType.rejected) return 'Rejected';
    return 'Other';
  }

  Color typeColor(CallType? t) {
    if (t == CallType.incoming) return Colors.green;
    if (t == CallType.outgoing) return Colors.blue;
    if (t == CallType.missed) return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Call Analytics'),
          bottom: const TabBar(tabs: [Tab(text: 'Summary'), Tab(text: 'Daily Report')]),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(children: [
              OutlinedButton.icon(
                onPressed: pickRange,
                icon: const Icon(Icons.date_range),
                label: Text('${dstr(range.start)}  to  ${dstr(range.end)}'),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  ActionChip(label: const Text('Today'), onPressed: () => setRange(0)),
                  const SizedBox(width: 6),
                  ActionChip(label: const Text('Yesterday'), onPressed: setYesterday),
                  const SizedBox(width: 6),
                  ActionChip(label: const Text('7 days'), onPressed: () => setRange(6)),
                  const SizedBox(width: 6),
                  ActionChip(label: const Text('30 days'), onPressed: () => setRange(29)),
                  const SizedBox(width: 6),
                  ActionChip(label: const Text('90 days'), onPressed: () => setRange(89)),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : denied
                    ? Center(child: FilledButton(onPressed: openAppSettings, child: const Text('Allow call log permission')))
                    : TabBarView(children: [summary(), daily()]),
          ),
        ]),
      ),
    );
  }

  Widget summary() {
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

    return ListView(padding: const EdgeInsets.all(16), children: [
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
            SizedBox(width: 44, child: Text('${two(h)}:00')),
            Expanded(child: LinearProgressIndicator(value: hours[h] / maxH, minHeight: 10)),
            SizedBox(width: 36, child: Text(' ${hours[h]}')),
          ]),
      const SizedBox(height: 20),
      Text('Top contacts', style: Theme.of(context).textTheme.titleMedium),
      for (final e in top.take(10))
        ListTile(dense: true, title: Text(e.key), trailing: Text('${e.value}')),
    ]);
  }

  Widget daily() {
    if (calls.isEmpty) return const Center(child: Text('No calls in this date range'));
    final byDay = <DateTime, List<CallLogEntry>>{};
    for (final c in calls) {
      final t = DateTime.fromMillisecondsSinceEpoch(c.timestamp ?? 0);
      final k = DateTime(t.year, t.month, t.day);
      byDay.putIfAbsent(k, () => []).add(c);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final d in days) dayCard(d, byDay[d]!),
    ]);
  }

  Widget dayCard(DateTime d, List<CallLogEntry> list) {
    final inc = list.where((c) => c.callType == CallType.incoming).length;
    final out = list.where((c) => c.callType == CallType.outgoing).length;
    final mis = list.where((c) => c.callType == CallType.missed).length;
    final talk = list.fold<int>(0, (a, c) => a + (c.duration ?? 0));
    list.sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));

    return Card(
      child: ExpansionTile(
        title: Text('${dstr(d)}   •   ${list.length} calls'),
        subtitle: Text('In $inc  |  Out $out  |  Missed $mis  |  Talk ${fmt(talk)}'),
        children: [
          for (final c in list)
            ListTile(
              dense: true,
              leading: Icon(Icons.phone, color: typeColor(c.callType), size: 20),
              title: Text((c.name?.isNotEmpty ?? false) ? c.name! : (c.number ?? 'Unknown')),
              subtitle: Text(
                  '${typeLabel(c.callType)}  •  ${two(DateTime.fromMillisecondsSinceEpoch(c.timestamp ?? 0).hour)}:${two(DateTime.fromMillisecondsSinceEpoch(c.timestamp ?? 0).minute)}'),
              trailing: Text(fmt(c.duration ?? 0)),
            ),
        ],
      ),
    );
  }

  Widget stat(String l, String v) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(l),
          ]),
        ),
      );
}
