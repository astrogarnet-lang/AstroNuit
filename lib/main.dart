import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'data/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;
  runApp(const TimeControlApp());
}

const emerald = Color(0xFF10B981);
const bg = Color(0xFF0B0F0E);
const panel = Color(0xFF151C19);

class TimeControlApp extends StatelessWidget {
  const TimeControlApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TimeControl',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: bg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: emerald,
            brightness: Brightness.dark,
            surface: panel,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: bg,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: panel,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFF26332D)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: panel,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: panel,
            indicatorColor: Color(0xFF174B39),
            labelTextStyle: WidgetStatePropertyAll(
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          useMaterial3: true,
        ),
        home: const HomeShell(),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  int refreshKey = 0;

  void refresh() => setState(() => refreshKey++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      OverviewPage(key: ValueKey('overview-$refreshKey'), onChanged: refresh),
      PeoplePage(key: ValueKey('people-$refreshKey'), onChanged: refresh),
      AttendancePage(key: ValueKey('attendance-$refreshKey'), onChanged: refresh),
      StatsPage(key: ValueKey('stats-$refreshKey')),
      const SettingsPage(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Обзор'),
          NavigationDestination(icon: Icon(Icons.groups_2_outlined), label: 'Люди'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: 'Посещаемость'),
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Статистика'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Настройки'),
        ],
      ),
    );
  }
}

Widget pageTitle(String title, {String? subtitle}) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: Colors.white54)),
        ],
      ]),
    );

Widget metric(String label, String value, IconData icon, {Color color = emerald}) =>
    Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
      ),
    );

class OverviewPage extends StatefulWidget {
  final VoidCallback onChanged;
  const OverviewPage({super.key, required this.onChanged});
  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> active = [];
  bool loading = true;

  Future<void> load() async {
    final s = await AppDatabase.instance.summary();
    final a = await AppDatabase.instance.openSessions();
    if (!mounted) return;
    setState(() { summary = s; active = a; loading = false; });
  }

  @override
  void initState() { super.initState(); load(); }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: ListView(children: [
      pageTitle('Обзор', subtitle: DateFormat('EEEE, d MMMM yyyy', 'ru').format(DateTime.now())),
      if (loading) const Center(child: CircularProgressIndicator())
      else Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(children: [
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.35, children: [
              metric('Участников', '${summary['people'] ?? 0}', Icons.groups),
              metric('Сейчас работают', '${summary['present'] ?? 0}', Icons.work_history),
              metric('Сессий открыто', '${active.length}', Icons.timer_outlined, color: Colors.amber),
              metric('Часов сегодня', '${summary['todayHours'] ?? '0.0'}', Icons.schedule),
            ],
          ),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Открытые рабочие сессии', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (active.isEmpty) const Text('Сейчас нет открытых сессий', style: TextStyle(color: Colors.white54))
              else ...active.map((s) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(backgroundColor: Color(0xFF174B39), child: Icon(Icons.person, color: emerald)),
                title: Text('${s['first_name']} ${s['last_name']}'),
                subtitle: Text('Пришёл: ${DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(s['check_in']))}'),
              )),
            ],
          ))),
          const SizedBox(height: 12),
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Row(children: [
            Icon(Icons.offline_bolt, color: emerald), SizedBox(width: 10),
            Expanded(child: Text('Все данные хранятся локально на устройстве. Интернет не требуется.')),
          ]))),
        ]),
      ),
    ]),
  );
}

class PeoplePage extends StatefulWidget {
  final VoidCallback onChanged;
  const PeoplePage({super.key, required this.onChanged});
  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  final search = TextEditingController();
  List<Map<String, dynamic>> people = [];
  bool archived = false;

  Future<void> load() async {
    final rows = await AppDatabase.instance.people(search: search.text, archived: archived);
    if (mounted) setState(() => people = rows);
  }

  @override
  void initState() { super.initState(); load(); search.addListener(load); }
  @override
  void dispose() { search.dispose(); super.dispose(); }

  Future<void> edit([Map<String, dynamic>? person]) async {
    final first = TextEditingController(text: person?['first_name'] ?? '');
    final last = TextEditingController(text: person?['last_name'] ?? '');
    final phone = TextEditingController(text: person?['phone'] ?? '');
    final role = TextEditingController(text: person?['role'] ?? '');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(person == null ? 'Новый участник' : 'Изменить участника'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: first, decoration: const InputDecoration(labelText: 'Имя *')),
        const SizedBox(height: 10),
        TextField(controller: last, decoration: const InputDecoration(labelText: 'Фамилия *')),
        const SizedBox(height: 10),
        TextField(controller: role, decoration: const InputDecoration(labelText: 'Должность / роль')),
        const SizedBox(height: 10),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Телефон')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
      ],
    ));
    if (ok == true && first.text.trim().isNotEmpty && last.text.trim().isNotEmpty) {
      await AppDatabase.instance.savePerson({
        if (person != null) 'id': person['id'],
        'first_name': first.text.trim(), 'last_name': last.text.trim(),
        'phone': phone.text.trim(), 'role': role.text.trim(),
      });
      widget.onChanged();
      await load();
    }
    first.dispose(); last.dispose(); phone.dispose(); role.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => edit(), icon: const Icon(Icons.person_add), label: const Text('Добавить'),
    ),
    body: Column(children: [
      pageTitle('Люди', subtitle: '${people.length} участников в списке'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(
        controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Поиск по имени, фамилии, роли'),
      )),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: SegmentedButton<bool>(
        segments: const [ButtonSegment(value: false, label: Text('Активные')), ButtonSegment(value: true, label: Text('Архив'))],
        selected: {archived}, onSelectionChanged: (v) { setState(() => archived = v.first); load(); },
      )),
      Expanded(child: people.isEmpty
        ? const Center(child: Text('Участников пока нет', style: TextStyle(color: Colors.white54)))
        : ListView.builder(itemCount: people.length, itemBuilder: (context, i) {
          final p = people[i];
          return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5), child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFF174B39), child: Icon(Icons.person, color: emerald)),
            title: Text('${p['first_name']} ${p['last_name']}'),
            subtitle: Text([p['role'], p['phone']].where((v) => v != null && v.toString().isNotEmpty).join(' • ')),
            onTap: () => edit(p),
            trailing: PopupMenuButton<String>(onSelected: (v) async {
              if (v == 'edit') {
                await edit(p);
                return;
              }
              if (!mounted) return;
              if (v == 'archive') {
                await AppDatabase.instance.archivePerson(p['id'] as int, !archived);
                if (!mounted) return;
                await load();
                widget.onChanged();
              }
              if (v == 'delete') {
                final dialogContext = context;
                if (!dialogContext.mounted) return;
                final yes = await showDialog<bool>(context: dialogContext, builder: (ctx) => AlertDialog(
                  title: const Text('Удалить участника?'),
                  content: const Text('История посещаемости и рабочие сессии сохранятся в базе как архивные записи.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
                  ],
                ));
                if (yes == true && mounted) {
                  await AppDatabase.instance.softDeletePerson(p['id'] as int);
                  if (!mounted) return;
                  await load();
                  widget.onChanged();
                }
              }
            }, itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
              PopupMenuItem(value: 'archive', child: Text(archived ? 'Вернуть из архива' : 'Архивировать')),
              const PopupMenuItem(value: 'delete', child: Text('Удалить')),
            ]),
          ));
        })),
    ]),
  );
}

class AttendancePage extends StatefulWidget {
  final VoidCallback onChanged;
  const AttendancePage({super.key, required this.onChanged});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<Map<String, dynamic>> people = [];
  List<Map<String, dynamic>> sessions = [];
  DateTime selected = DateTime.now();

  Future<void> load() async {
    final p = await AppDatabase.instance.people();
    final s = await AppDatabase.instance.sessionsForDay(selected);
    if (mounted) setState(() { people = p; sessions = s; });
  }
  @override
  void initState() { super.initState(); load(); }

  Future<void> punch(int id, bool inNow) async {
    try {
      if (inNow) {
        await AppDatabase.instance.checkIn(id);
      } else {
        await AppDatabase.instance.checkOut(id);
      }
      await load(); widget.onChanged();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    pageTitle('Посещаемость', subtitle: 'Фактическое время • свободный график'),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: OutlinedButton.icon(
      onPressed: () async {
        final d = await showDatePicker(context: context, initialDate: selected, firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (d != null) { setState(() => selected = d); load(); }
      },
      icon: const Icon(Icons.calendar_month), label: Text(DateFormat('d MMMM yyyy', 'ru').format(selected)),
    )),
    Expanded(child: ListView.builder(itemCount: people.length, itemBuilder: (context, i) {
      final p = people[i];
      final open = sessions.any((s) => s['participant_id'] == p['id'] && s['check_out'] == null);
      final todaySessions = sessions.where((s) => s['participant_id'] == p['id']).toList();
      final last = todaySessions.isEmpty ? null : todaySessions.last;
      return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5), child: Padding(
        padding: const EdgeInsets.all(12), child: Column(children: [
          Row(children: [
            const CircleAvatar(backgroundColor: Color(0xFF174B39), child: Icon(Icons.person, color: emerald)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['first_name']} ${p['last_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(open ? 'Рабочая сессия открыта' : (last == null ? 'Ещё не приходил' : 'Сессия завершена'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ])),
            if (open) const Icon(Icons.circle, color: emerald, size: 10),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: selected.year == DateTime.now().year && selected.month == DateTime.now().month && selected.day == DateTime.now().day && !open ? () => punch(p['id'] as int, true) : null, icon: const Icon(Icons.login), label: const Text('Пришёл'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.tonalIcon(onPressed: open ? () => punch(p['id'] as int, false) : null, icon: const Icon(Icons.logout), label: const Text('Ушёл'))),
          ]),
          if (todaySessions.isNotEmpty) Align(alignment: Alignment.centerLeft, child: Text(
            todaySessions.map((s) => '${DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(s['check_in']))} – ${s['check_out'] == null ? '…' : DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(s['check_out']))}').join('   •   '),
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          )),
        ]),
      ));
    })),
  ]);
}

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsPageState();
}
class _StatsPageState extends State<StatsPage> {
  Map<String, dynamic> data = {};
  @override
  void initState() { super.initState(); AppDatabase.instance.summary().then((v) { if (mounted) setState(() => data = v); }); }
  @override
  Widget build(BuildContext context) => ListView(children: [
    pageTitle('Статистика', subtitle: 'Сводка по локальным данным'),
    Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      metric('Всего участников', '${data['people'] ?? 0}', Icons.groups),
      metric('Открытые сессии', '${data['present'] ?? 0}', Icons.timer),
      metric('Часов сегодня', '${data['todayHours'] ?? '0.0'}', Icons.schedule),
      const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Графики и расширенные отчёты будут добавлены на следующих этапах разработки.', style: TextStyle(color: Colors.white60)))),
    ]),
    ),
  ]);
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(children: [
    pageTitle('Настройки', subtitle: 'TimeControl v0.1.0'),
    const Card(child: Column(children: [
      ListTile(leading: Icon(Icons.storage, color: emerald), title: Text('Локальная база SQLite'), subtitle: Text('Данные остаются на этом устройстве')),
      Divider(height: 1),
      ListTile(leading: Icon(Icons.cloud_off, color: emerald), title: Text('Автономная работа'), subtitle: Text('Подключение к интернету не требуется')),
      Divider(height: 1),
      ListTile(leading: Icon(Icons.backup_outlined), title: Text('Резервное копирование'), subtitle: Text('Будет реализовано в этапе v0.7')),
      Divider(height: 1),
      ListTile(leading: Icon(Icons.file_download_outlined), title: Text('Экспорт CSV / XLSX / PDF'), subtitle: Text('Будет реализовано в этапе v0.7')),
    ])),
  ]);
}
