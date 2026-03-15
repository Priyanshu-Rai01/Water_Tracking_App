// main.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AquaFitApp());
}

class AquaFitApp extends StatefulWidget {
  const AquaFitApp({super.key});

  @override
  State<AquaFitApp> createState() => _AquaFitAppState();
}

class _AquaFitAppState extends State<AquaFitApp> {
  ThemeMode _theme = ThemeMode.system;

  // Runtime-only onboarding flag (shows once per cold start)
  static bool _autoOnboardingShown = false;

  void setTheme(ThemeMode t) => setState(() => _theme = t);

  @override
  void initState() {
    super.initState();
    // Auto theme by time of day: light between 7:00-18:59, dark otherwise (can be overridden)
    final hour = DateTime.now().hour;
    if (hour >= 7 && hour < 19) {
      _theme = ThemeMode.light;
    } else {
      _theme = ThemeMode.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aquafit Health & Fitness',
      debugShowCheckedModeBanner: false,
      themeMode: _theme,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: MainEntry(onThemeChanged: setTheme, autoOnboardingShownSetter: (val) => _autoOnboardingShown = val, autoOnboardingShown: _autoOnboardingShown),
    );
  }
}

/// MainEntry: Onboarding -> Splash -> Login -> Home (keeps app state)
class MainEntry extends StatefulWidget {
  final void Function(ThemeMode) onThemeChanged;
  final void Function(bool) autoOnboardingShownSetter;
  final bool autoOnboardingShown;
  const MainEntry({
    super.key,
    required this.onThemeChanged,
    required this.autoOnboardingShownSetter,
    required this.autoOnboardingShown,
  });

  @override
  State<MainEntry> createState() => _MainEntryState();
}

class _MainEntryState extends State<MainEntry> {
  String _username = '';
  String _email = '';
  bool _loggedIn = false;

  // app-wide state: water entries across dates (in-memory)
  final List<WaterEntry> _allEntries = [];

  // Reminder state
  final List<Reminder> _reminders = [];

  // Theme handling
  ThemeMode _currentTheme = ThemeMode.system;

  // onboarding runtime flag (so we can show once per cold start)
  bool onboardingCompleted = false;

  void _loginAs(String username, {String email = ''}) {
    setState(() {
      _username = username;
      _email = email;
      _loggedIn = true;
    });
  }

  void _logout() {
    // cancel active reminders
    for (final r in _reminders) r.cancel();
    setState(() {
      _username = '';
      _email = '';
      _loggedIn = false;
      // keep data in memory
    });
  }

  void _addEntry(WaterEntry e) {
    setState(() {
      _allEntries.insert(0, e);
    });
  }

  void _removeEntry(WaterEntry e) {
    setState(() {
      _allEntries.remove(e);
    });
  }

  void _addReminder(Reminder r) {
    setState(() {
      _reminders.add(r);
    });
    r.schedule(context);
  }

  void _cancelAllReminders() {
    for (final r in _reminders) r.cancel();
    setState(() => _reminders.clear());
  }

  void _setThemeMode(ThemeMode m) {
    setState(() => _currentTheme = m);
    widget.onThemeChanged(m);
  }

  @override
  void dispose() {
    for (final r in _reminders) r.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // show onboarding once per cold start (runtime-only)
    if (!onboardingCompleted && !widget.autoOnboardingShown) {
      widget.autoOnboardingShownSetter(true);
      return OnboardingScreen(onComplete: () => setState(() => onboardingCompleted = true));
    }

    if (!_loggedIn) {
      return SplashThenLogin(
        onLogin: _loginAs,
        onThemeChange: _setThemeMode,
        onPrefillEmail: (e) => setState(() => _email = e),
      );
    }

    return HomeShell(
      username: _username,
      email: _email,
      entries: _allEntries,
      onAddEntry: _addEntry,
      onRemoveEntry: _removeEntry,
      reminders: _reminders,
      onAddReminder: _addReminder,
      onCancelReminders: _cancelAllReminders,
      onLogout: _logout,
      onThemeChange: _setThemeMode,
      currentTheme: _currentTheme,
    );
  }
}

/// Onboarding screens
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pc = PageController();
  int _page = 0;

  final List<Map<String, String>> pages = [
    {'title': 'Welcome to Aquafit', 'body': 'Track your daily hydration, set goals, get reminders.'},
    {'title': 'Smart Reminders', 'body': 'Schedule reminders and stay consistent.'},
    {'title': 'Insights', 'body': 'View 7-day summaries, trends and personalized recommendations.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.water_drop, size: 92, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 24),
                  Text(pages[i]['title']!, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(pages[i]['body']!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                ]),
              ),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(pages.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 250), margin: const EdgeInsets.all(4), width: _page == i ? 24 : 8, height: 8, decoration: BoxDecoration(color: _page==i?Theme.of(context).colorScheme.primary:Colors.grey, borderRadius: BorderRadius.circular(8))))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
            child: Row(children: [
              if (_page < pages.length - 1)
                TextButton(onPressed: () { widget.onComplete(); }, child: const Text('Skip'))
              else
                const SizedBox.shrink(),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  if (_page < pages.length - 1) _pc.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.ease);
                  else widget.onComplete();
                },
                child: Text(_page < pages.length - 1 ? 'Next' : 'Get Started'),
              )
            ]),
          )
        ]),
      ),
    );
  }
}

/// Splash then Login widget
class SplashThenLogin extends StatefulWidget {
  final void Function(String, {String email}) onLogin;
  final void Function(ThemeMode) onThemeChange;
  final void Function(String) onPrefillEmail;
  const SplashThenLogin({super.key, required this.onLogin, required this.onThemeChange, required this.onPrefillEmail});

  @override
  State<SplashThenLogin> createState() => _SplashThenLoginState();
}

class _SplashThenLoginState extends State<SplashThenLogin> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _showLogin = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 900), () => setState(() => _showLogin = true));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showLogin) {
      return Scaffold(
        body: AnimatedBuilder(
          animation: _anim,
          builder: (ctx, child) {
            final v = _anim.value;
            return Container(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: Opacity(
                  opacity: v,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.water_drop, size: 96, color: Colors.blue),
                    const SizedBox(height: 12),
                    Text('Aquafit Health & Fitness', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Private Limited', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ),
            );
          },
        ),
      );
    }

    return LoginScreen(onLogin: widget.onLogin, onThemeChange: widget.onThemeChange, onPrefillEmail: widget.onPrefillEmail);
  }
}

/// Login screen (simple demo login)
class LoginScreen extends StatefulWidget {
  final void Function(String, {String email}) onLogin;
  final void Function(ThemeMode) onThemeChange;
  final void Function(String) onPrefillEmail;
  const LoginScreen({super.key, required this.onLogin, required this.onThemeChange, required this.onPrefillEmail});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  String _username = '';
  String _password = '';
  String _email = '';
  bool _isDark = false;

  void _submit() {
    if (_form.currentState!.validate()) {
      widget.onLogin(_username, email: _email);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // pleasant login UI
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.water_drop, size: 84, color: Colors.blue),
                const SizedBox(height: 12),
                Text('Aquafit Health & Fitness', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Form(
                  key: _form,
                  child: Column(children: [
                    TextFormField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.person), labelText: 'Username'),
                      onChanged: (v) => _username = v,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter username' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.email), labelText: 'Email (optional)'),
                      onChanged: (v) { _email = v; widget.onPrefillEmail(v); },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      obscureText: true,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.lock), labelText: 'Password'),
                      onChanged: (v) => _password = v,
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter password' : null,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _submit, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12), child: Text('Login'))),
                  ]),
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Dark mode'),
                  const SizedBox(width: 8),
                  Switch(value: _isDark, onChanged: (val) { setState(() => _isDark = val); widget.onThemeChange(val ? ThemeMode.dark : ThemeMode.light); }),
                ])
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// HomeShell: main scaffold with drawer and tabs
class HomeShell extends StatefulWidget {
  final String username;
  final String email;
  final List<WaterEntry> entries;
  final void Function(WaterEntry) onAddEntry;
  final void Function(WaterEntry) onRemoveEntry;
  final List<Reminder> reminders;
  final void Function(Reminder) onAddReminder;
  final VoidCallback onCancelReminders;
  final VoidCallback onLogout;
  final void Function(ThemeMode) onThemeChange;
  final ThemeMode currentTheme;

  const HomeShell({
    super.key,
    required this.username,
    required this.email,
    required this.entries,
    required this.onAddEntry,
    required this.onRemoveEntry,
    required this.reminders,
    required this.onAddReminder,
    required this.onCancelReminders,
    required this.onLogout,
    required this.onThemeChange,
    required this.currentTheme,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  int _tabIndex = 0;
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    // Animated background controller
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      HomeTabWidget(entries: widget.entries, onAddEntry: widget.onAddEntry, onRemoveEntry: widget.onRemoveEntry, waveAnimation: _waveCtrl),
      HistoryTab(entries: widget.entries),
      ServicesTab(),
      NotificationsTabWidget(reminders: widget.reminders, onAddReminder: widget.onAddReminder, onCancelAll: widget.onCancelReminders),
      AboutTab(),
      ContactTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Aquafit — Hello ${widget.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => showDialog(context: context, builder: (_) => ProfileDialog(username: widget.username, email: widget.email, onSave: (n,e) {/*in-memory only*/})),
            tooltip: 'Profile',
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () {
              // stop reminders when logging out
              widget.onCancelReminders();
              widget.onLogout();
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(children: [
            DrawerHeader(
              child: Row(children: [
                CircleAvatar(radius: 32, child: Text(widget.username.isNotEmpty ? widget.username[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 24))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(widget.email, style: const TextStyle(fontSize: 12))])),
              ]),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () => showDialog(context: context, builder: (_) => ProfileDialog(username: widget.username, email: widget.email, onSave: (n,e) { /* no-op */ })),
            ),
            SwitchListTile(
              value: widget.currentTheme == ThemeMode.dark,
              title: const Text('Dark Mode'),
              onChanged: (val) => widget.onThemeChange(val ? ThemeMode.dark : ThemeMode.light),
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Cancel reminders'),
              onTap: () {
                widget.onCancelReminders();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All reminders cancelled')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Onboarding (view again)'),
              onTap: () {
                // reopen onboarding (runtime only)
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => OnboardingScreen(onComplete: () => Navigator.of(context).pop())));
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('App info'),
              subtitle: const Text('Aquafit Health & Fitness Pvt. Ltd.'),
            ),
          ]),
        ),
      ),
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: tabs[_tabIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.miscellaneous_services), label: 'Services'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: 'About'),
          BottomNavigationBarItem(icon: Icon(Icons.contact_mail), label: 'Contact'),
        ],
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

/// PROFILE DIALOG (editable, in-memory)
class ProfileDialog extends StatefulWidget {
  final String username;
  final String email;
  final void Function(String name, String email) onSave;
  const ProfileDialog({super.key, required this.username, required this.email, required this.onSave});

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.username);
    _emailCtrl = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Profile'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 36, child: Text(widget.username.isNotEmpty ? widget.username[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 24))),
        const SizedBox(height: 10),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 8),
        TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { widget.onSave(_nameCtrl.text.trim(), _emailCtrl.text.trim()); Navigator.pop(context); }, child: const Text('Save'))
      ],
    );
  }
}

/// HOME TAB WIDGET with animated background and ml-based tracker
class HomeTabWidget extends StatefulWidget {
  final List<WaterEntry> entries;
  final void Function(WaterEntry) onAddEntry;
  final void Function(WaterEntry) onRemoveEntry;
  final AnimationController waveAnimation;

  const HomeTabWidget({super.key, required this.entries, required this.onAddEntry, required this.onRemoveEntry, required this.waveAnimation});

  @override
  State<HomeTabWidget> createState() => _HomeTabWidgetState();
}

class _HomeTabWidgetState extends State<HomeTabWidget> {
  int goalMl = 3000;
  final TextEditingController _customController = TextEditingController();
  String _selectedCategory = 'General';
  final TextEditingController _noteController = TextEditingController();

  // compute today's entries
  List<WaterEntry> get todayEntries {
    final now = DateTime.now();
    return widget.entries.where((e) => e.time.year == now.year && e.time.month == now.month && e.time.day == now.day).toList();
  }

  int get todayTotal => todayEntries.fold(0, (p, e) => p + e.ml);

  void _addMl(int ml, {String category = 'General', String note = ''}) {
    widget.onAddEntry(WaterEntry(time: DateTime.now(), ml: ml, category: category, note: note));
  }

  void _showAddCustom() {
    _customController.text = '250';
    _noteController.text = '';
    _selectedCategory = 'General';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add custom ml'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _customController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Enter ml')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            items: ['General','Workout','Morning','Evening','Other'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v ?? 'General'),
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const SizedBox(height: 8),
          TextField(controller: _noteController, decoration: const InputDecoration(hintText: 'Note (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(_customController.text.trim());
              if (v != null && v > 0) {
                _addMl(v, category: _selectedCategory, note: _noteController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  void _setGoalDialog() {
    final t = TextEditingController(text: goalMl.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set daily goal (ml)'),
        content: TextField(controller: t, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () { final v = int.tryParse(t.text.trim()); if (v!=null && v>0) { setState(() => goalMl = v); Navigator.pop(context);} }, child: const Text('Save'))
        ],
      ),
    );
  }

  void _removeEntry(WaterEntry e) {
    widget.onRemoveEntry(e);
  }
  Timer? _midnightTimer;

  void _scheduleMidnightCheck() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final diff = tomorrow.difference(now);
    _midnightTimer = Timer(diff + const Duration(seconds: 1), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New day — today\'s tracker reset.')));
        _scheduleMidnightCheck(); // schedule next
        setState(() {}); // recompute UI
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _scheduleMidnightCheck();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _customController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // compute 7-day totals: 0=today, 1=yesterday, ...
  Map<int,int> getSevenDayTotals() {
    final now = DateTime.now();
    Map<int,int> m = {for (int i=0;i<7;i++) i:0};
    for (final e in widget.entries) {
      final days = DateTime(now.year, now.month, now.day).difference(DateTime(e.time.year, e.time.month, e.time.day)).inDays;
      if (days >=0 && days < 7) m[days] = (m[days] ?? 0) + e.ml;
    }
    return m;
  }

  // --- 7-day average
  int getSevenDayAverage() {
    final totals = getSevenDayTotals();
    final sum = totals.values.fold(0, (p, e) => p + e);
    return (sum / 7).round();
  }

  // --- weight based water calculator
  void _showWeightCalculatorDialog() {
    final TextEditingController c = TextEditingController(text: '70');
    showDialog(context: context, builder: (_) {
      return AlertDialog(
        title: const Text('Water calculator (by weight)'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Enter weight in kg')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            final w = double.tryParse(c.text.trim());
            if (w != null && w > 0) {
              final rec = (w * 35).round(); // guideline: 35 ml per kg
              Navigator.pop(context);
              showDialog(context: context, builder: (_) => AlertDialog(
                title: const Text('Recommended'),
                content: Text('$rec ml per day (approx.)'),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
              ));
            }
          }, child: const Text('Calculate'))
        ],
      );
    });
  }

  // --- export full history to clipboard as CSV (pure flutter)
  void _exportAllToClipboard() {
    final rows = widget.entries.map((e) => '${e.time.toIso8601String()},${e.ml},${e.category},"${e.note.replaceAll('"','""')}"').join('\n');
    final csv = 'time,ml,category,note\n$rows';
    Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All data exported to clipboard (CSV)')));
  }

  @override
  Widget build(BuildContext context) {
    final progress = goalMl == 0 ? 0.0 : (todayTotal / goalMl).clamp(0.0, 1.0);
    final seven = getSevenDayTotals();

    return Stack(children: [
      Positioned.fill(child: AnimatedWaveBackground(animation: widget.waveAnimation)),
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 6),
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                // progress circle
                SizedBox(width: 110, height: 110, child: CustomPaint(painter: ProgressPainter(progress: progress, centerText: '$todayTotal ml'))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Goal: $goalMl ml'),
                  const SizedBox(height: 6),
                  Text('Consumed: $todayTotal ml'),
                  const SizedBox(height: 6),
                  // --- show 7-day average
                  Text('7-day average: ${getSevenDayAverage()} ml', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    ElevatedButton(onPressed: () => _addMl(50, category: _selectedCategory), child: const Text('+50')),
                    ElevatedButton(onPressed: () => _addMl(100, category: _selectedCategory), child: const Text('+100')),
                    ElevatedButton(onPressed: () => _addMl(200, category: _selectedCategory), child: const Text('+200')),
                    ElevatedButton(onPressed: () => _addMl(250, category: _selectedCategory), child: const Text('+250')),
                    ElevatedButton(onPressed: _showAddCustom, child: const Text('Custom')),
                    ElevatedButton(onPressed: _showWeightCalculatorDialog, child: const Text('Calc by weight')),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    OutlinedButton(onPressed: _setGoalDialog, child: const Text('Set Goal')),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: () {
                      // export today's entries to clipboard (CSV)
                      final rows = todayEntries.map((e) => '${e.time.toIso8601String()},${e.ml},${e.category},"${e.note.replaceAll('"','""')}"').join('\n');
                      final csv = 'time,ml,category,note\n$rows';
                      Clipboard.setData(ClipboardData(text: csv));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Today exported to clipboard (CSV)')));
                    }, child: const Text('Export Today')),
                    const SizedBox(width: 8),
                    Tooltip(message: 'Export all history to clipboard as CSV', child: IconButton(onPressed: _exportAllToClipboard, icon: const Icon(Icons.upload_file)))
                  ])
                ]))
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('7-day history', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                SizedBox(height: 140, child: SevenDayChart(totals: seven, goal: goalMl)),
                const SizedBox(height: 8),
                const Text('Category breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SizedBox(height: 100, child: CategoryPieChart(entries: widget.entries)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              title: const Text('Today\'s entries'),
              initiallyExpanded: true,
              children: [
                if (todayEntries.isEmpty)
                  const Padding(padding: EdgeInsets.all(12), child: Text('No entries yet — add above.'))
                else
                  ...todayEntries.map((e) => ListTile(
                        leading: const Icon(Icons.local_drink),
                        title: Text('${e.ml} ml — ${e.category}'),
                        subtitle: Text('${e.time.hour.toString().padLeft(2,'0')}:${e.time.minute.toString().padLeft(2,'0')} ${e.note.isNotEmpty?"• ${e.note}":""}'),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _removeEntry(e)),
                      )),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('Quick Tips', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('- Keep a 250ml bottle handy for easy logging.\n- Aim for regular small intakes across the day.'),
          const SizedBox(height: 40),
        ],
      ),
    ]);
  }
}

/// Animated wave background painter (simple moving sine waves)
class AnimatedWaveBackground extends StatelessWidget {
  final Animation<double> animation;
  const AnimatedWaveBackground({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: animation, builder: (ctx, child) {
      return CustomPaint(
        painter: _WavePainter(animation.value, Theme.of(context).colorScheme.primaryContainer, Theme.of(context).colorScheme.primary),
        child: Container(),
      );
    });
  }
}

class _WavePainter extends CustomPainter {
  final double t;
  final Color bg;
  final Color fg;
  _WavePainter(this.t, this.bg, this.fg);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paintBg = Paint()..shader = LinearGradient(colors: [bg, bg.withOpacity(0.85)]).createShader(rect);
    canvas.drawRect(rect, paintBg);

    final Path path1 = Path();
    final Path path2 = Path();
    final Path path3 = Path();

    for (int i = 0; i < size.width.toInt(); i++) {
      final x = i.toDouble();
      final y1 = 20 * sin((x / 180 * 2 * pi) + (t * 2 * pi)) + size.height * 0.75;
      final y2 = 12 * sin((x / 140 * 2 * pi) + (t * 2.3 * pi) + 1) + size.height * 0.78;
      final y3 = 8 * sin((x / 100 * 2 * pi) + (t * 2.7 * pi) + 2) + size.height * 0.82;
      if (i == 0) {
        path1.moveTo(x, y1);
        path2.moveTo(x, y2);
        path3.moveTo(x, y3);
      } else {
        path1.lineTo(x, y1);
        path2.lineTo(x, y2);
        path3.lineTo(x, y3);
      }
    }
    final p1 = Paint()..color = fg.withOpacity(0.20);
    final p2 = Paint()..color = fg.withOpacity(0.14);
    final p3 = Paint()..color = fg.withOpacity(0.10);

    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();

    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    path3.lineTo(size.width, size.height);
    path3.lineTo(0, size.height);
    path3.close();

    canvas.drawPath(path3, p3);
    canvas.drawPath(path2, p2);
    canvas.drawPath(path1, p1);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.t != t;
}

/// Progress painter (circular ring)
class ProgressPainter extends CustomPainter {
  final double progress;
  final String centerText;
  ProgressPainter({required this.progress, required this.centerText});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2);
    final radius = min(size.width, size.height)/2 - 6;
    final bgPaint = Paint()..color = Colors.white.withOpacity(0.12)..style = PaintingStyle.stroke..strokeWidth = 10;
    final fgPaint = Paint()..color = Colors.blue..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    final sweep = 2 * pi * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi/2, sweep, false, fgPaint);

    final tp = TextPainter(text: TextSpan(text: centerText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ThemeData().brightness == Brightness.dark ? Colors.white : Colors.black)), textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    tp.layout(maxWidth: size.width);
    tp.paint(canvas, Offset(center.dx - tp.width/2, center.dy - tp.height/2));
  }

  @override
  bool shouldRepaint(covariant ProgressPainter old) => old.progress != progress || old.centerText != centerText;
}

/// SevenDay chart (bars + trendline)
class SevenDayChart extends StatelessWidget {
  final Map<int,int> totals;
  final int goal;
  const SevenDayChart({super.key, required this.totals, required this.goal});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SevenDayPainter(totals: totals, goal: goal, textStyle: Theme.of(context).textTheme.bodySmall),
      child: Container(),
    );
  }
}

class _SevenDayPainter extends CustomPainter {
  final Map<int,int> totals;
  final int goal;
  final TextStyle? textStyle;
  _SevenDayPainter({required this.totals, required this.goal, this.textStyle});

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 12.0;
    final availableW = size.width - padding * 2;
    final barW = (availableW / 7) * 0.6;
    final gap = (availableW - barW * 7) / 6;
    final maxVal = (totals.values.isEmpty) ? 1 : totals.values.reduce(max).clamp(1, max(goal, 1));

    final paint = Paint();
    final labels = ['6d','5d','4d','3d','2d','1d','Today'];

    // collect points to draw a simple line
    final List<Offset> points = [];

    for (int i=0;i<7;i++) {
      final x = padding + i*(barW+gap);
      final val = totals[6-i] ?? 0;
      final h = (val / maxVal) * (size.height - 28);
      paint.color = val >= goal ? Colors.green : Colors.blue;
      final rect = Rect.fromLTWH(x, size.height - h - 18, barW, h);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), paint);

      // for trend line
      final cx = x + barW/2;
      final cy = size.height - 18 - h;
      points.add(Offset(cx, cy));

      final tp = TextPainter(text: TextSpan(text: labels[i], style: textStyle), textAlign: TextAlign.center, textDirection: TextDirection.ltr);
      tp.layout(minWidth: barW, maxWidth: barW);
      tp.paint(canvas, Offset(x, size.height - 16));
    }

    // draw trend line
    if (points.length > 1) {
      final linePaint = Paint()..color = Colors.white.withOpacity(0.9)..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
      final path = Path();
      for (int i = 0; i < points.length; i++) {
        if (i == 0) {path.moveTo(points[i].dx, points[i].dy);} else {path.lineTo(points[i].dx, points[i].dy);}
      }
      canvas.drawPath(path, linePaint);
    }

    // goal line
    final goalPaint = Paint()..color = Colors.orange..strokeWidth = 1;
    final goalY = size.height - 18 - (goal / maxVal) * (size.height - 28);
    canvas.drawLine(Offset(padding - 4, goalY), Offset(size.width - padding + 4, goalY), goalPaint);
  }

  @override
  bool shouldRepaint(covariant _SevenDayPainter old) => old.totals != totals || old.goal != goal;
}

/// Category pie chart using CustomPainter (pure flutter)
class CategoryPieChart extends StatelessWidget {
  final List<WaterEntry> entries;
  const CategoryPieChart({super.key, required this.entries});

  Map<String,int> _aggregate() {
    final map = <String,int>{};
    for (final e in entries) {
      map[e.category] = (map[e.category] ?? 0) + e.ml;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final agg = _aggregate();
    return CustomPaint(size: const Size(double.infinity, 100), painter: _CategoryPiePainter(agg));
  }
}

class _CategoryPiePainter extends CustomPainter {
  final Map<String,int> data;
  _CategoryPiePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..style = PaintingStyle.fill;
    final total = data.values.fold<int>(0, (p, e) => p + e);
    if (total == 0) {
      paint.color = Colors.grey.withOpacity(0.2);
      canvas.drawCircle(rect.center, min(size.width, size.height)/3, paint);
      return;
    }
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.indigo];
    double start = -pi/2;
    int i = 0;
    final legendX = size.width * 0.55;
    final legendYStart = 8.0;

    for (final entry in data.entries) {
      final sweep = (entry.value / total) * 2 * pi;
      paint.color = colors[i % colors.length];
      canvas.drawArc(Rect.fromLTWH(0, 0, size.height, size.height), start, sweep, true, paint);
      // legend
      final tp = TextPainter(text: TextSpan(text: '${entry.key} (${entry.value}ml)', style: const TextStyle(fontSize: 11, color: Colors.white)), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(legendX, legendYStart + i * 16));
      start += sweep;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryPiePainter old) => old.data != data;
}

/// HISTORY TAB (aggregated list of past entries) with date-range filter and simple analytics
class HistoryTab extends StatefulWidget {
  final List<WaterEntry> entries;
  const HistoryTab({super.key, required this.entries});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String _range = 'This Week';

  List<WaterEntry> _filter() {
    final now = DateTime.now();
    if (_range == 'Today') {
      return widget.entries.where((e) => e.time.year==now.year && e.time.month==now.month && e.time.day==now.day).toList();
    } else if (_range == 'This Week') {
      final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday-1));
      return widget.entries.where((e) => e.time.isAfter(start.subtract(const Duration(seconds:1)))).toList();
    } else if (_range == 'This Month') {
      final start = DateTime(now.year, now.month, 1);
      return widget.entries.where((e) => e.time.isAfter(start.subtract(const Duration(seconds:1)))).toList();
    }
    return widget.entries;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter();
    return ListView(padding: const EdgeInsets.all(12), children: [
      const SizedBox(height: 8),
      Row(children: [
        const Text('History (by entry)', style: TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        DropdownButton<String>(value: _range, items: ['Today','This Week','This Month','All'].map((s)=>DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v)=> setState(()=> _range = v ?? 'This Week'))
      ]),
      const SizedBox(height: 10),
      if (filtered.isEmpty) const Text('No history for this range.'),
      ...filtered.map((e) => Card(child: ListTile(leading: const Icon(Icons.local_drink), title: Text('${e.ml} ml — ${e.category}'), subtitle: Text('${e.time.toLocal()}\n${e.note}')))),
      const SizedBox(height: 12),
      const Divider(),
      const SizedBox(height: 8),
      const Text('Simple analytics', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      SizedBox(height: 140, child: TrendLineChart(entries: filtered)),
    ]);
  }
}

/// Services Tab (kept minimal + profile quick stats)
class ServicesTab extends StatelessWidget {
  const ServicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final services = [
      {'t':'Water intake tracking','d':'Log water quickly and set daily goals.'},
      {'t':'Reminders','d':'Schedule reminders to stay consistent.'},
      {'t':'Analytics','d':'Seven-day summaries and exports.'},
      {'t':'Corporate plans','d':'Team-based hydration programs (contact us).'},
    ];
    return ListView(padding: const EdgeInsets.all(12), children: [
      const SizedBox(height: 8),
      const Text('Services', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      ...services.map((s) => Card(child: ListTile(leading: const Icon(Icons.check_circle), title: Text(s['t']!), subtitle: Text(s['d']!))))
    ]);
  }
}

/// Notifications page with add reminder UI
class NotificationsTabWidget extends StatefulWidget {
  final List<Reminder> reminders;
  final void Function(Reminder) onAddReminder;
  final VoidCallback onCancelAll;
  const NotificationsTabWidget({super.key, required this.reminders, required this.onAddReminder, required this.onCancelAll});

  @override
  State<NotificationsTabWidget> createState() => _NotificationsTabWidgetState();
}

class _NotificationsTabWidgetState extends State<NotificationsTabWidget> {
  final TextEditingController _msgCtrl = TextEditingController(text: 'Time to drink water!');
  final TextEditingController _minCtrl = TextEditingController(text: '120');

  void _addReminder() {
    final mins = int.tryParse(_minCtrl.text.trim());
    final msg = _msgCtrl.text.trim();
    if (mins == null || mins <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid minutes interval')));
      return;
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final rem = Reminder(id: id, interval: Duration(minutes: mins), message: msg.isEmpty ? 'Time to drink water!' : msg);
    widget.onAddReminder(rem);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reminder every $mins minutes added')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      const SizedBox(height: 8),
      const Text('Reminders', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            TextField(controller: _msgCtrl, decoration: const InputDecoration(labelText: 'Reminder message')),
            const SizedBox(height: 8),
            TextField(controller: _minCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Interval (minutes)')),
            const SizedBox(height: 10),
            Row(children: [
              ElevatedButton(onPressed: _addReminder, child: const Text('Add reminder')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () { widget.onCancelAll(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All reminders cancelled'))); }, child: const Text('Cancel all'))
            ])
          ]),
        ),
      ),
      const SizedBox(height: 12),
      const Text('Active reminders', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...widget.reminders.map((r) => Card(child: ListTile(title: Text(r.message), subtitle: Text('Every ${r.interval.inMinutes} min')))),
      if (widget.reminders.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No active reminders'))
    ]);
  }
}

/// ABOUT TAB (team photos and bios)
class AboutTab extends StatelessWidget {
  const AboutTab({super.key});

  Widget _card(String name, String role, String assetPath) {
    return Card(
      child: ListTile(
        leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset(assetPath, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width:60,height:60,color:Colors.grey,child:const Icon(Icons.person)))),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      const SizedBox(height: 8),
      const Text('About Aquafit', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Aquafit Health and Fitness Pvt. Ltd. builds delightful hydration & wellness experiences.'),
      const SizedBox(height: 12),
      _card('Priyanshu Rai', 'CEO', 'assets/images/ceo.jpg'),
      _card('R. Madhan Kumar', 'COO', 'assets/images/coo.jpg'),
      _card('Pathem Raghava', 'CTO', 'assets/images/cto.jpg'),
    ]);
  }
}

/// CONTACT TAB
class ContactTab extends StatelessWidget {
  const ContactTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(12), children: const [
      SizedBox(height: 10),
      ListTile(leading: Icon(Icons.email), title: Text('priyanshudrjrai@gmail.com')),
      ListTile(leading: Icon(Icons.location_on), title: Text('Hyderabad, Telangana')),
      ListTile(leading: Icon(Icons.phone), title: Text('+91 9125322162')),
      SizedBox(height: 12),
      Text('CEO: Priyanshu Rai\nCTO: Pathem Raghava\nCOO: R. Madhan Kumar'),
    ]);
  }
}

/// Simple trend line chart painter for history analytics
class TrendLineChart extends StatelessWidget {
  final List<WaterEntry> entries;
  const TrendLineChart({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(double.infinity, 140), painter: _TrendLinePainter(entries));
  }
}

class _TrendLinePainter extends CustomPainter {
  final List<WaterEntry> entries;
  _TrendLinePainter(this.entries);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blue..strokeWidth = 2..style = PaintingStyle.stroke;
    final bg = Paint()..color = Colors.blue.withOpacity(0.07);

    // aggregate by day
    final map = <DateTime,int>{};
    for (final e in entries) {
      final d = DateTime(e.time.year, e.time.month, e.time.day);
      map[d] = (map[d] ?? 0) + e.ml;
    }
    if (map.isEmpty) return;
    final list = map.entries.toList()..sort((a,b) => a.key.compareTo(b.key));
    final maxVal = list.map((e)=>e.value).reduce(max).toDouble();
    final stepX = size.width / max(1, list.length - 1);
    final points = <Offset>[];

    for (int i=0;i<list.length;i++) {
      final x = i * stepX;
      final y = size.height - (list[i].value / maxVal) * (size.height - 20) - 10;
      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i=1;i<points.length;i++) path.lineTo(points[i].dx, points[i].dy);

    // area fill
    final area = Path.from(path);
    area.lineTo(points.last.dx, size.height);
    area.lineTo(points.first.dx, size.height);
    area.close();
    canvas.drawPath(area, bg);

    canvas.drawPath(path, paint);

    // draw points
    final dot = Paint()..color = Colors.white..style = PaintingStyle.fill;
    for (final p in points) canvas.drawCircle(p, 3, dot..color = Colors.blue);
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter old) => old.entries != entries;
}

/// WaterEntry model (category & note)
class WaterEntry {
  final DateTime time;
  final int ml;
  final String category;
  final String note;
  WaterEntry({required this.time, required this.ml, this.category = 'General', this.note = ''});
}

/// Reminder model (in-app simulated reminders)
class Reminder {
  final String id;
  final Duration interval;
  final String message;
  Timer? _timer;

  Reminder({required this.id, required this.interval, required this.message});

  void schedule(BuildContext ctx) {
    cancel();
    // first fire after interval
    _timer = Timer.periodic(interval, (_) {
      // show SnackBar on main scaffold
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(message)),
      );
      // In pure Flutter (no packages) we simulate a visual notification by a small dialog if the app is visible
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
