import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

// ============================================================
// ওষুধের সাথী (Oushudher Shathi) v0.2
//
// New in v0.2 (compared to the DartPad prototype):
//   * data is SAVED on the phone (restart-safe)
//   * a real Android home-screen WIDGET with tick buttons
//   * the tick from the widget works even when the app is closed
//
// This app only REMINDS. Medicine and dose must follow the doctor's advice.
// ============================================================

// ---------------- Bangla helpers ----------------

/// Turns 0-9 into ০-৯ inside any text/number.
String bn(Object v) {
  const digits = '০১২৩৪৫৬৭৮৯';
  final out = StringBuffer();
  for (final ch in v.toString().split('')) {
    final i = int.tryParse(ch);
    out.write(i == null ? ch : digits[i]);
  }
  return out.toString();
}

/// "সকাল ৯:১০" style time.
String bnTime(DateTime t) {
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final String period;
  if (t.hour < 4) {
    period = 'রাত';
  } else if (t.hour < 6) {
    period = 'ভোর';
  } else if (t.hour < 12) {
    period = 'সকাল';
  } else if (t.hour < 15) {
    period = 'দুপুর';
  } else if (t.hour < 18) {
    period = 'বিকাল';
  } else if (t.hour < 20) {
    period = 'সন্ধ্যা';
  } else {
    period = 'রাত';
  }
  return '$period ${bn(h12)}:${bn(t.minute.toString().padLeft(2, '0'))}';
}

/// One place for text styles. height: 1.5 gives Bangla letters
/// (matra, kar, juktakkhor) enough room so they do not look squashed.
TextStyle t(double size, {FontWeight? w, Color? c}) =>
    TextStyle(fontSize: size, fontWeight: w, color: c, height: 1.5);

// ---------------- Constants ----------------

const List<String> slotNames = ['সকাল', 'দুপুর', 'রাত'];
const List<String> slotTimeText = ['সকাল ৮টা', 'দুপুর ২টা', 'রাত ৯টা'];
const List<int> slotDueHours = [8, 14, 21];
const List<IconData> slotIcons = [
  Icons.wb_twilight,
  Icons.wb_sunny,
  Icons.nightlight_round,
];
const List<String> timingNames = ['খাওয়ার আগে', 'খাওয়ার পরে', 'যেকোনো সময়'];
const List<String> weekdaysBn = [
  'সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার',
  'শুক্রবার', 'শনিবার', 'রবিবার',
];
const List<String> monthsBn = [
  'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
  'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
];

/// Which time of day is it now? 0 = সকাল, 1 = দুপুর, 2 = রাত
int currentSlot() {
  final h = DateTime.now().hour;
  if (h < 12) return 0;
  if (h < 18) return 1;
  return 2;
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ---------------- Models ----------------

class Medicine {
  Medicine({
    required this.id,
    required this.nameEn,
    required this.nameBn,
    required this.slots,
    required this.timing,
    required this.dose,
  });

  final int id;
  String nameEn; // e.g. Napa
  String nameBn; // e.g. নাপা
  Set<int> slots; // 0 = সকাল, 1 = দুপুর, 2 = রাত
  int timing; // index into timingNames
  String dose; // free text, written exactly as the doctor said

  Map<String, dynamic> toJson() => {
        'id': id,
        'en': nameEn,
        'bn': nameBn,
        'slots': (slots.toList()..sort()),
        'timing': timing,
        'dose': dose,
      };

  factory Medicine.fromJson(Map<String, dynamic> j) => Medicine(
        id: j['id'] as int,
        nameEn: (j['en'] as String?) ?? '',
        nameBn: (j['bn'] as String?) ?? '',
        slots: ((j['slots'] as List?) ?? const []).map((e) => e as int).toSet(),
        timing: (j['timing'] as int?) ?? 1,
        dose: (j['dose'] as String?) ?? '',
      );
}

/// One medicine at one time of day = one "dose" to tick off.
class Dose {
  const Dose(this.med, this.slot);
  final Medicine med;
  final int slot;
}

class FeedItem {
  FeedItem(this.text, this.time, this.good);
  final String text;
  final DateTime time;
  final bool good;

  Map<String, dynamic> toJson() =>
      {'text': text, 'time': time.toIso8601String(), 'good': good};

  factory FeedItem.fromJson(Map<String, dynamic> j) => FeedItem(
        (j['text'] as String?) ?? '',
        DateTime.tryParse((j['time'] as String?) ?? '') ?? DateTime.now(),
        (j['good'] as bool?) ?? true,
      );
}

enum DoseStatus { taken, due, missed, later }

// ---------------- AppData: ALL the logic, no UI ----------------
// Keeping logic away from the screens means the widget's background
// code and the app screens can share exactly the same rules.

class AppData {
  AppData(); // needed: a class with only a factory has no default constructor

  String parentName = 'আম্মা';
  bool showBangla = true;
  int nextId = 4;
  int unread = 0;

  // SAMPLE medicines only. Replace with your parent's real list.
  List<Medicine> meds = [
    Medicine(
      id: 1, nameEn: 'Napa', nameBn: 'নাপা',
      slots: {0, 2}, timing: 1, dose: '১টি ট্যাবলেট',
    ),
    Medicine(
      id: 2, nameEn: 'Seclo', nameBn: 'সেক্লো',
      slots: {0}, timing: 0, dose: '১টি ক্যাপসুল',
    ),
    Medicine(
      id: 3, nameEn: 'Amlo', nameBn: '',
      slots: {1}, timing: 2, dose: '১টি ট্যাবলেট',
    ),
  ];

  // "medId-slot-date" -> time when it was ticked. The date is part of the
  // key, so tomorrow every tick starts fresh automatically.
  final Map<String, DateTime> taken = {};
  final List<FeedItem> feed = [];

  // ----- save / load -----

  Map<String, dynamic> toJson() => {
        'parentName': parentName,
        'showBangla': showBangla,
        'nextId': nextId,
        'unread': unread,
        'meds': meds.map((m) => m.toJson()).toList(),
        'taken': taken.map((k, v) => MapEntry(k, v.toIso8601String())),
        'feed': feed.map((f) => f.toJson()).toList(),
      };

  factory AppData.fromJson(Map<String, dynamic> j) {
    final d = AppData();
    d.parentName = (j['parentName'] as String?) ?? d.parentName;
    d.showBangla = (j['showBangla'] as bool?) ?? true;
    d.nextId = (j['nextId'] as int?) ?? 4;
    d.unread = (j['unread'] as int?) ?? 0;
    if (j['meds'] is List) {
      d.meds = (j['meds'] as List)
          .map((e) => Medicine.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    final now = DateTime.now();
    if (j['taken'] is Map) {
      (j['taken'] as Map).forEach((k, v) {
        final when = DateTime.tryParse(v as String);
        // keep only today's ticks, older ones are not needed
        if (when != null && sameDay(when, now)) d.taken[k as String] = when;
      });
    }
    if (j['feed'] is List) {
      for (final e in (j['feed'] as List)) {
        d.feed.add(FeedItem.fromJson(Map<String, dynamic>.from(e as Map)));
      }
    }
    return d;
  }

  // ----- queries -----

  String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  String key(Medicine m, int slot) => '${m.id}-$slot-${dayKey(DateTime.now())}';

  DateTime? takenAt(Medicine m, int slot) => taken[key(m, slot)];

  /// Name shown to the user, following the English/Bangla switch.
  /// If the chosen language is empty, falls back to the other one.
  String name(Medicine m) {
    final en = m.nameEn.trim();
    final b = m.nameBn.trim();
    if (showBangla) return b.isNotEmpty ? b : en;
    return en.isNotEmpty ? en : b;
  }

  /// Every (medicine, time-of-day) pair for today, sorted by time of day.
  List<Dose> todayDoses() {
    final list = <Dose>[];
    for (var s = 0; s < 3; s++) {
      for (final m in meds) {
        if (m.slots.contains(s)) list.add(Dose(m, s));
      }
    }
    return list;
  }

  DoseStatus status(Dose d) {
    if (takenAt(d.med, d.slot) != null) return DoseStatus.taken;
    final now = DateTime.now();
    final due = DateTime(now.year, now.month, now.day, slotDueHours[d.slot]);
    if (now.isAfter(due.add(const Duration(hours: 2)))) {
      return DoseStatus.missed;
    }
    if (now.isAfter(due.subtract(const Duration(hours: 1)))) {
      return DoseStatus.due;
    }
    return DoseStatus.later;
  }

  // ----- changes -----

  void addFeed(String text, {bool good = true}) {
    feed.insert(0, FeedItem(text, DateTime.now(), good));
    if (feed.length > 30) feed.removeRange(30, feed.length);
    unread++; // the family tab shows a red badge
  }

  void markTaken(Dose d) {
    taken[key(d.med, d.slot)] = DateTime.now();
    addFeed('$parentName ${slotNames[d.slot]}ের ${name(d.med)} খেয়েছেন');
  }

  void undo(Dose d) {
    taken.remove(key(d.med, d.slot));
    addFeed(
      '$parentName ভুলে ${name(d.med)} এ টিক দিয়েছিলেন, বাতিল করা হয়েছে',
      good: false,
    );
  }

  // ----- what the home-screen widget shows -----

  Map<String, String> widgetPayload() {
    final doses = todayDoses();
    final cur = currentSlot();
    final pending = doses.where((d) => takenAt(d.med, d.slot) == null).toList();
    // current time of day first, then later ones, earlier (missed) last
    int rank(Dose d) => d.slot >= cur ? d.slot - cur : d.slot + 3 - cur;
    pending.sort((a, b) => rank(a).compareTo(rank(b)));

    final total = doses.length;
    final done = total - pending.length;
    final shown = pending.length > 3 ? 3 : pending.length;

    final p = <String, String>{
      'w_header': total == 0
          ? '💊 ওষুধের সাথী'
          : '💊 ওষুধ বাকি (${bn(done)}/${bn(total)} খাওয়া হয়েছে)',
      'w_count': '$shown',
      'w_empty': total == 0
          ? 'অ্যাপ খুলে ওষুধ যোগ করুন'
          : 'সব ওষুধ খাওয়া হয়েছে ✓',
    };
    for (var i = 0; i < 3; i++) {
      if (i < shown) {
        final d = pending[i];
        p['w_text$i'] = '${name(d.med)} (${slotNames[d.slot]})';
        p['w_dose$i'] = '${d.med.id}-${d.slot}';
      } else {
        p['w_text$i'] = '';
        p['w_dose$i'] = '';
      }
    }
    return p;
  }
}

// ---------------- Storage ----------------
// home_widget keeps a small key/value store on the phone that BOTH this app
// and the Android widget code can read. We keep everything in it.

Future<void> pushToWidget(AppData d) async {
  try {
    for (final e in d.widgetPayload().entries) {
      await HomeWidget.saveWidgetData<String>(e.key, e.value);
    }
    await HomeWidget.updateWidget(
      name: 'OushudhWidgetProvider',
      androidName: 'OushudhWidgetProvider',
      qualifiedAndroidName: 'com.example.oushudh_app.OushudhWidgetProvider',
    );
  } catch (_) {
    // widget not available (for example on the web): app still works
  }
}

class Store {
  static const String _key = 'oushudh_state_v1';

  static Future<AppData> load() async {
    try {
      final s = await HomeWidget.getWidgetData<String>(_key);
      if (s != null && s.isNotEmpty) {
        return AppData.fromJson(jsonDecode(s) as Map<String, dynamic>);
      }
    } catch (_) {
      // first run or unreadable data: start with the defaults
    }
    return AppData();
  }

  static Future<void> save(AppData d) async {
    try {
      await HomeWidget.saveWidgetData<String>(_key, jsonEncode(d.toJson()));
    } catch (_) {}
    await pushToWidget(d);
  }
}

// ---------------- Widget tick (runs even if the app is closed) ----------------
// The widget's ✓ button opens a link like  oushudh://tick?dose=1-0
// (medicine id 1, time of day 0). Android starts this function in the
// background; it ticks that dose, saves, and redraws the widget.

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri == null || uri.host != 'tick') return;
  final parts = (uri.queryParameters['dose'] ?? '').split('-');
  if (parts.length != 2) return;
  final medId = int.tryParse(parts[0]);
  final slot = int.tryParse(parts[1]);
  if (medId == null || slot == null) return;

  final data = await Store.load();
  final i = data.meds.indexWhere((m) => m.id == medId);
  if (i == -1) return;
  final dose = Dose(data.meds[i], slot);
  if (data.takenAt(dose.med, dose.slot) != null) return; // already ticked
  data.markTaken(dose);
  await Store.save(data);
}

// ---------------- App ----------------

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HomeWidget.registerInteractivityCallback(backgroundCallback);
  runApp(const OushudhApp());
}

class OushudhApp extends StatelessWidget {
  const OushudhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ওষুধের সাথী',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D6B),
        useMaterial3: true,
      ),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  AppData _d = AppData();
  bool _loaded = false;
  int _tab = 0; // 0 = parent screen, 1 = family screen

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // When the app comes back to the screen, re-read the saved data: the
  // widget may have ticked something while the app was closed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    final d = await Store.load();
    if (!mounted) return;
    setState(() {
      _d = d;
      _loaded = true;
    });
    await pushToWidget(d); // makes sure the widget is never out of date
  }

  // ---------- actions ----------

  void _markTaken(Dose d) {
    setState(() => _d.markTaken(d));
    Store.save(_d);
  }

  void _undo(Dose d) {
    setState(() => _d.undo(d));
    Store.save(_d);
  }

  Future<void> _editMed([Medicine? existing]) async {
    final r = await showDialog<Medicine>(
      context: context,
      builder: (_) => _MedDialog(existing: existing),
    );
    if (r == null) return;
    setState(() {
      if (existing == null) {
        _d.meds.add(Medicine(
          id: _d.nextId++,
          nameEn: r.nameEn,
          nameBn: r.nameBn,
          slots: r.slots,
          timing: r.timing,
          dose: r.dose,
        ));
      } else {
        final i = _d.meds.indexWhere((x) => x.id == existing.id);
        if (i != -1) {
          final m = _d.meds[i];
          m.nameEn = r.nameEn;
          m.nameBn = r.nameBn;
          m.slots = r.slots;
          m.timing = r.timing;
          m.dose = r.dose;
        }
      }
    });
    Store.save(_d);
  }

  Future<void> _deleteMed(Medicine m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${_d.name(m)}" মুছে ফেলবেন?',
            style: t(20, w: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('না', style: t(16)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('হ্যাঁ, মুছুন', style: t(16)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _d.meds.removeWhere((x) => x.id == m.id));
    Store.save(_d);
  }

  Future<void> _renameParent() async {
    final r = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: _d.parentName),
    );
    if (r == null) return;
    setState(() => _d.parentName = r);
    Store.save(_d);
  }

  // ---------- PARENT SCREEN ----------

  Widget _parentView() {
    final doses = _d.todayDoses();
    final total = doses.length;
    final done = doses.where((d) => _d.takenAt(d.med, d.slot) != null).length;
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('${_d.parentName}, আজকের ওষুধ', style: t(30, w: FontWeight.w800)),
        Text(
          '${weekdaysBn[now.weekday - 1]}, ${bn(now.day)} ${monthsBn[now.month - 1]}',
          style: t(18, c: Colors.black54),
        ),
        const SizedBox(height: 12),

        // Progress
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total > 0 && done == total
                      ? 'সব ওষুধ খাওয়া হয়ে গেছে 🎉'
                      : 'আজ ${bn(total)}টির মধ্যে ${bn(done)}টি খাওয়া হয়েছে',
                  style: t(20, w: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    minHeight: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        _widgetPreview(doses),
        const SizedBox(height: 4),
        Text(
          'ওপরের কার্ডটা হোম স্ক্রিন উইজেটের মতো। উইজেট বসাতে: হোম স্ক্রিনের ফাঁকা জায়গায় চেপে ধরুন, তারপর "উইজেট" থেকে "ওষুধের সাথী" বেছে নিন।',
          style: t(13, c: Colors.black45),
        ),
        const SizedBox(height: 20),

        if (doses.isEmpty)
          Text('কোনো ওষুধ যোগ করা নেই। "পরিবার" ট্যাব থেকে যোগ করুন।',
              style: t(18)),

        for (var s = 0; s < 3; s++)
          if (doses.any((d) => d.slot == s)) ...[
            Row(
              children: [
                Icon(slotIcons[s], size: 28),
                const SizedBox(width: 8),
                Text(slotNames[s], style: t(24, w: FontWeight.w800)),
                const SizedBox(width: 8),
                Text('(${slotTimeText[s]})', style: t(16, c: Colors.black54)),
                const Spacer(),
                if (s == currentSlot())
                  Chip(
                    label: Text('এখন', style: t(14, w: FontWeight.w700)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final d in doses.where((d) => d.slot == s)) _parentDoseCard(d),
            const SizedBox(height: 12),
          ],

        Text(
          'এই অ্যাপ শুধু মনে করিয়ে দেয়। ওষুধ ও ডোজ ডাক্তারের পরামর্শ অনুযায়ী খাবেন।',
          style: t(13, c: Colors.black45),
        ),
      ],
    );
  }

  Widget _widgetPreview(List<Dose> doses) {
    final pending =
        doses.where((d) => _d.takenAt(d.med, d.slot) == null).take(3).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F4D43),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💊 ওষুধ বাকি',
              style: t(16, w: FontWeight.w700, c: Colors.white70)),
          const SizedBox(height: 4),
          if (pending.isEmpty)
            Text('সব খাওয়া হয়েছে ✓', style: t(20, c: Colors.white))
          else
            for (final d in pending)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_d.name(d.med)} (${slotNames[d.slot]})',
                        style: t(20, w: FontWeight.w600, c: Colors.white),
                      ),
                    ),
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _markTaken(d),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.check_circle_outline,
                            color: Colors.white, size: 36),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _parentDoseCard(Dose d) {
    final at = _d.takenAt(d.med, d.slot);
    final dose = d.med.dose.trim();
    return Card(
      color: at != null ? Colors.green.shade50 : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_d.name(d.med), style: t(28, w: FontWeight.w800)),
            Text(
              '${timingNames[d.med.timing]}${dose.isEmpty ? '' : ' • $dose'}',
              style: t(18, c: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (at == null)
              SizedBox(
                width: double.infinity,
                height: 64,
                child: FilledButton.icon(
                  onPressed: () => _markTaken(d),
                  icon: const Icon(Icons.check, size: 30),
                  label: Text('খেয়েছি', style: t(24, w: FontWeight.w700)),
                ),
              )
            else
              Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade700, size: 34),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${bnTime(at)} এ খেয়েছেন',
                      style:
                          t(20, w: FontWeight.w700, c: Colors.green.shade800),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _undo(d),
                    child: Text('ভুল? বাতিল', style: t(16)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ---------- FAMILY SCREEN ----------

  Widget _familyView() {
    final doses = _d.todayDoses();
    final missed = doses.where((d) => _d.status(d) == DoseStatus.missed).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Card(
          color: Colors.amber.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'ডেমো: এখানে দুটো স্ক্রিন একই ফোনে।
