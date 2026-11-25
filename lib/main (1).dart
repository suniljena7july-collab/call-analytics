import 'dart:math';
import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(const MyApp());

const kBgTop = Color(0xFF0B1220);
const kBgBottom = Color(0xFF16263A);
const kCard = Color(0xFF1B2A3A);
const kAccent = Color(0xFF1DE9B6);
const cIn = Color(0xFF1E6FD9);
const cOut = Color(0xFF3FA2FF);
const cMiss = Color(0xFFE53935);
const cRej = Color(0xFFFFA726);
const cOther = Color(0xFF90A4AE);

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Call Analytics',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            brightness: Brightness.dark, colorSchemeSeed: kAccent, useMaterial3: true),
        home: const Home(),
      );
}

class Cat {
  final String title;
  final IconData icon;
  final Color color;
  final List<CallLogEntry> list;
  final bool showTime;
  Cat(this.title, this.icon, this.color, this.list, this.showTime);
  int get seconds => list.fold<int>(0, (a, c) => a + (c.duration ?? 0));
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  late final AnimationController _bg =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();

  @override
  void dispose() {
    _bg.dispose();
    super.dispose();
  }

  Widget orb(Alignment a, double size, Color c) => Align(
        alignment: a,
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [c.withAlpha(75), c.withAlpha(0)]),
            ),
          ),
        ),
      );

  List<CallLogEntry> calls = [];
  bool loading = true, denied = false;
  int animSeed = 0;
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
    setState(() {
      calls = entries.toList();
      denied = false;
      loading = false;
      animSeed++;
    });
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

  // ---------- helpers ----------
  String two(int n) => n.toString().padLeft(2, '0');
  String dstr(DateTime d) => '${two(d.day)}-${two(d.month)}-${d.year}';
  String fmt(int s) => s >= 3600
      ? '${s ~/ 3600}h ${(s % 3600) ~/ 60}m'
      : '${s ~/ 60}m ${s % 60}s';
  String fmtFull(int s) => '${s ~/ 3600}h ${(s % 3600) ~/ 60}m ${s % 60}s';
  String nameOf(CallLogEntry c) =>
      (c.name?.isNotEmpty ?? false) ? c.name! : (c.number ?? 'Unknown');

  String typeLabel(CallType? t) {
    if (t == CallType.incoming) return 'Incoming';
    if (t == CallType.outgoing) return 'Outgoing';
    if (t == CallType.missed) return 'Missed';
    if (t == CallType.rejected) return 'Rejected';
    return 'Other';
  }

  Color typeColor(CallType? t) {
    if (t == CallType.incoming) return cIn;
    if (t == CallType.outgoing) return cOut;
    if (t == CallType.missed) return cMiss;
    if (t == CallType.rejected) return cRej;
    return cOther;
  }

  // ---------- effects ----------
  Widget fadeIn(int i, Widget child) => TweenAnimationBuilder<double>(
        key: ValueKey('$animSeed-$i'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 450 + i * 90),
        curve: Curves.easeOutCubic,
        builder: (c, t, ch) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 28 * (1 - t)), child: ch),
        ),
        child: child,
      );

  Widget countUp(int v, TextStyle style) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: v.toDouble()),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        builder: (c, t, _) => Text('${t.round()}', style: style),
      );

  Widget chip(String t, VoidCallback f) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          label: Text(t),
          onPressed: f,
          backgroundColor: const Color(0xFF1F3044),
          side: BorderSide(color: kAccent.withAlpha(90)),
          labelStyle: const TextStyle(color: Colors.white),
        ),
      );

  // ---------- main build ----------
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bg,
      builder: (context, child) {
        final t = _bg.value * 2 * pi;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + 0.4 * sin(t), -1),
              end: Alignment(1, 1 + 0.4 * cos(t)),
              colors: [
                Color.lerp(kBgTop, const Color(0xFF1A1040), (sin(t) + 1) / 2)!,
                Color.lerp(kBgBottom, const Color(0xFF0B3A4A), (cos(t) + 1) / 2)!,
              ],
            ),
          ),
          child: Stack(children: [
            orb(Alignment(0.9 * sin(t), -0.8 + 0.3 * cos(t)), 260, const Color(0xFF1DE9B6)),
            orb(Alignment(-0.9 * cos(t), 0.2 * sin(t)), 300, const Color(0xFF7C4DFF)),
            orb(Alignment(0.8 * cos(t + 1), 0.9 + 0.1 * sin(t)), 280, const Color(0xFF2979FF)),
            child!,
          ]),
        );
      },
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Analysis',
                style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: load),
              IconButton(icon: const Icon(Icons.calendar_month), onPressed: pickRange),
            ],
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Column(children: [
                InkWell(
                  onTap: pickRange,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kAccent.withAlpha(110)),
                      color: kCard,
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.date_range, size: 18, color: kAccent),
                      const SizedBox(width: 8),
                      Text('${dstr(range.start)}   to   ${dstr(range.end)}'),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    chip('Today', () => setRange(0)),
                    chip('Yesterday', setYesterday),
                    chip('7 days', () => setRange(6)),
                    chip('30 days', () => setRange(29)),
                    chip('90 days', () => setRange(89)),
                  ]),
                ),
              ]),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14)),
              child: const TabBar(
                dividerColor: Colors.transparent,
                indicator: UnderlineTabIndicator(
                    borderSide: BorderSide(color: kAccent, width: 3)),
                labelColor: kAccent,
                unselectedLabelColor: Colors.white60,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                tabs: [Tab(text: 'Summary'), Tab(text: 'Analysis'), Tab(text: 'Daily')],
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator(color: kAccent))
                  : denied
                      ? Center(
                          child: FilledButton(
                              onPressed: openAppSettings,
                              child: const Text('Allow call log permission')))
                      : TabBarView(children: [summary(), analysis(), daily()]),
            ),
          ]),
        ),
      ),
    );
  }

  // ---------- SUMMARY TAB ----------
  Widget summary() {
    final inc = calls.where((c) => c.callType == CallType.incoming).toList();
    final out = calls.where((c) => c.callType == CallType.outgoing).toList();
    final mis = calls.where((c) => c.callType == CallType.missed).toList();
    final rej = calls.where((c) => c.callType == CallType.rejected).toList();
    final unknown = calls.where((c) => c.name == null || c.name!.isEmpty).toList();
    final notPicked = out.where((c) => (c.duration ?? 0) == 0).toList();
    final talked = calls.where((c) => (c.duration ?? 0) > 0).toList();
    final incTalked = inc.where((c) => (c.duration ?? 0) > 0).toList();
    final outTalked = out.where((c) => (c.duration ?? 0) > 0).toList();

    final cats = <Cat>[
      Cat('All Calls', Icons.phone_in_talk, const Color(0xFF26C6DA), calls, true),
      Cat('Incoming Calls', Icons.call_received, cOut, inc, true),
      Cat('Outgoing Calls', Icons.call_made, const Color(0xFFC6FF00), out, true),
      Cat('Unknown Calls', Icons.contact_support, const Color(0xFFFF9800), unknown, true),
      Cat('Missed Calls', Icons.call_missed, cMiss, mis, false),
      Cat('Rejected Calls', Icons.phone_disabled, const Color(0xFFFF5252), rej, false),
      Cat('Not Picked Outgoing', Icons.phone_missed, const Color(0xFFFF7043), notPicked, false),
      Cat('All Talked Calls', Icons.headset_mic, const Color(0xFF00E676), talked, true),
      Cat('Incoming Talked', Icons.headset_mic, const Color(0xFF00E676), incTalked, true),
      Cat('Outgoing Talked', Icons.headset_mic, const Color(0xFF00E676), outTalked, true),
    ];

    final w = (MediaQuery.of(context).size.width - 32 - 10) / 2;

    return ListView(padding: const EdgeInsets.all(16), children: [
      fadeIn(0, pieBlock(inc.length, out.length, mis.length, rej.length)),
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (var i = 0; i < cats.length; i++) catCard(cats[i], i + 1, w),
      ]),
      const SizedBox(height: 20),
    ]);
  }

  Widget pieBlock(int inc, int out, int mis, int rej) {
    final total = inc + out + mis + rej;
    if (total == 0) {
      return const SizedBox(
          height: 120, child: Center(child: Text('No calls in this date range')));
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey('pie$animSeed'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (ctx, t, _) {
        final secs = <PieChartSectionData>[];
        void add(int v, Color c) {
          if (v <= 0) return;
          final pct = v * 100 / total;
          secs.add(PieChartSectionData(
            value: v.toDouble(),
            color: c,
            radius: 95 * t,
            showTitle: pct >= 4 && t > 0.85,
            title: '${pct.toStringAsFixed(1)} %',
            titlePositionPercentageOffset: 0.65,
            titleStyle: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ));
        }

        add(inc, cIn);
        add(out, cOut);
        add(mis, cMiss);
        add(rej, cRej);

        return SizedBox(
          height: 230,
          child: Row(children: [
            Expanded(
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                    BoxShadow(color: cOut.withAlpha(70), blurRadius: 50, spreadRadius: 6)
                  ]),
                ),
                PieChart(PieChartData(
                  sections: secs,
                  sectionsSpace: 1,
                  centerSpaceRadius: 0,
                  startDegreeOffset: -90 + 120 * (1 - t),
                )),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in [
                    ('Incoming', cIn),
                    ('Outgoing', cOut),
                    ('Missed', cMiss),
                    ('Rejected', cRej),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: e.$2,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: e.$2.withAlpha(150), blurRadius: 8)],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(e.$1, style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget catCard(Cat c, int i, double w) {
    return fadeIn(
      i,
      GestureDetector(
        onTap: () => showList(c),
        child: Container(
          width: w,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A3B4F), Color(0xFF1E2C3D)],
            ),
            border: Border.all(color: c.color.withAlpha(80)),
            boxShadow: [
              BoxShadow(color: c.color.withAlpha(45), blurRadius: 14, offset: const Offset(0, 4))
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.color, width: 1.5),
                  boxShadow: [BoxShadow(color: c.color.withAlpha(90), blurRadius: 8)],
                ),
                child: Icon(c.icon, color: c.color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.phone, size: 16, color: Colors.white54),
              const SizedBox(width: 10),
              countUp(c.list.length,
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ]),
            if (c.showTime) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.timer_outlined, size: 16, color: Colors.white54),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(fmtFull(c.seconds),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5)),
                ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  void showList(Cat c) {
    final list = [...c.list]..sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16222F),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, sc) => Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('${c.title}  (${list.length})',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('No calls'))
                : ListView.builder(
                    controller: sc,
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final e = list[i];
                      final t = DateTime.fromMillisecondsSinceEpoch(e.timestamp ?? 0);
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.phone, color: typeColor(e.callType), size: 20),
                        title: Text(nameOf(e)),
                        subtitle: Text(
                            '${typeLabel(e.callType)}  •  ${dstr(t)}  ${two(t.hour)}:${two(t.minute)}'),
                        trailing: Text(fmt(e.duration ?? 0)),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  // ---------- ANALYSIS TAB ----------
  Widget panel(String title, Widget child, int i) => fadeIn(
        i,
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kCard.withAlpha(215),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            child,
          ]),
        ),
      );

  Widget barBox(List<BarChartGroupData> groups, List<String> labels) {
    final w = max(MediaQuery.of(context).size.width - 64, groups.length * 26.0);
    return SizedBox(
      height: 200,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.only(top: 12, right: 8),
            child: BarChart(BarChartData(
              barGroups: groups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) =>
                    const FlLine(color: Colors.white12, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (v, meta) => Text(
                      v == v.roundToDouble() ? '${v.toInt()}' : '',
                      style: const TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= labels.length || labels[i].isEmpty) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(labels[i],
                            style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      );
                    },
                  ),
                ),
              ),
            )),
          ),
        ),
      ),
    );
  }

  Widget analysis() {
    if (calls.isEmpty) return const Center(child: Text('No calls in this date range'));

    final hours = List<int>.filled(24, 0);
    final contacts = <String, int>{};
    // per day: [in, out, missed, rejected, other, talkSeconds]
    final perDay = <DateTime, List<int>>{};
    for (final c in calls) {
      final t = DateTime.fromMillisecondsSinceEpoch(c.timestamp ?? 0);
      hours[t.hour]++;
      final k = nameOf(c);
      contacts[k] = (contacts[k] ?? 0) + 1;
      final dk = DateTime(t.year, t.month, t.day);
      final r = perDay.putIfAbsent(dk, () => [0, 0, 0, 0, 0, 0]);
      if (c.callType == CallType.incoming) {
        r[0]++;
      } else if (c.callType == CallType.outgoing) {
        r[1]++;
      } else if (c.callType == CallType.missed) {
        r[2]++;
      } else if (c.callType == CallType.rejected) {
        r[3]++;
      } else {
        r[4]++;
      }
      r[5] += c.duration ?? 0;
    }
    final top = contacts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final days = <DateTime>[];
    for (var d = range.start; !d.isAfter(range.end); d = DateTime(d.year, d.month, d.day + 1)) {
      days.add(d);
    }
    final step = days.length > 31 ? 3 : 1;
    final dayLabels = [
      for (var i = 0; i < days.length; i++)
        (i % step == 0) ? '${two(days[i].day)}/${two(days[i].month)}' : ''
    ];

    const stackColors = [cIn, cOut, cMiss, cRej, cOther];
    final callGroups = <BarChartGroupData>[];
    final talkGroups = <BarChartGroupData>[];
    for (var i = 0; i < days.length; i++) {
      final r = perDay[days[i]] ?? [0, 0, 0, 0, 0, 0];
      var from = 0.0;
      final items = <BarChartRodStackItem>[];
      for (var k = 0; k < 5; k++) {
        final to = from + r[k];
        if (r[k] > 0) items.add(BarChartRodStackItem(from, to, stackColors[k]));
        from = to;
      }
      callGroups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
            toY: from, width: 14, borderRadius: BorderRadius.zero, rodStackItems: items),
      ]));
      talkGroups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: double.parse((r[5] / 60).toStringAsFixed(1)),
          width: 14,
          color: kAccent,
          borderRadius: BorderRadius.circular(3),
        ),
      ]));
    }

    final hourGroups = [
      for (var h = 0; h < 24; h++)
        BarChartGroupData(x: h, barRods: [
          BarChartRodData(
            toY: hours[h].toDouble(),
            width: 12,
            color: const Color(0xFFB388FF),
            borderRadius: BorderRadius.circular(3),
          ),
        ])
    ];
    final hourLabels = [for (var h = 0; h < 24; h++) (h % 3 == 0) ? two(h) : ''];

    Widget dot(Color c, String t) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(t, style: const TextStyle(fontSize: 12)),
          ]),
        );

    return ListView(padding: const EdgeInsets.all(16), children: [
      panel(
        'Calls per day',
        Column(children: [
          Wrap(children: [
            dot(cIn, 'Incoming'),
            dot(cOut, 'Outgoing'),
            dot(cMiss, 'Missed'),
            dot(cRej, 'Rejected'),
          ]),
          barBox(callGroups, dayLabels),
        ]),
        0,
      ),
      panel('Talk time per day (minutes)', barBox(talkGroups, dayLabels), 1),
      panel('Calls by hour of day', barBox(hourGroups, hourLabels), 2),
      panel(
        'Top contacts',
        Column(children: [
          for (final e in top.take(10))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(e.key),
              trailing: Text('${e.value}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: kAccent)),
            ),
        ]),
        3,
      ),
    ]);
  }

  // ---------- DAILY TAB ----------
  Widget daily() {
    if (calls.isEmpty) return const Center(child: Text('No calls in this date range'));
    final byDay = <DateTime, List<CallLogEntry>>{};
    for (final c in calls) {
      final t = DateTime.fromMillisecondsSinceEpoch(c.timestamp ?? 0);
      byDay.putIfAbsent(DateTime(t.year, t.month, t.day), () => []).add(c);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (var i = 0; i < days.length; i++)
        fadeIn(min(i, 8), dayCard(days[i], byDay[days[i]]!)),
    ]);
  }

  Widget dayCard(DateTime d, List<CallLogEntry> list) {
    final inc = list.where((c) => c.callType == CallType.incoming).length;
    final out = list.where((c) => c.callType == CallType.outgoing).length;
    final mis = list.where((c) => c.callType == CallType.missed).length;
    final talk = list.fold<int>(0, (a, c) => a + (c.duration ?? 0));
    list.sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCard.withAlpha(215),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text('${dstr(d)}   •   ${list.length} calls',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('In $inc  |  Out $out  |  Missed $mis  |  Talk ${fmt(talk)}'),
          children: [
            for (final c in list)
              ListTile(
                dense: true,
                leading: Icon(Icons.phone, color: typeColor(c.callType), size: 20),
                title: Text(nameOf(c)),
                subtitle: Text(
                    '${typeLabel(c.callType)}  •  ${two(DateTime.fromMillisecondsSinceEpoch(c.timestamp ?? 0).hour)}:${two(DateTime.fromMillisecondsSinceEpoch(c.timestamp ?? 0).minute)}'),
                trailing: Text(fmt(c.duration ?? 0)),
              ),
          ],
        ),
      ),
    );
  }
}
