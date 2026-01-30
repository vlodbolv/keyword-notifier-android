import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_notification_listener_plus/flutter_notification_listener_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------------------------------------------------------
// 1. Entry Point
// -----------------------------------------------------------------------------
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const MyApp(),
    ),
  );
}

// -----------------------------------------------------------------------------
// 2. Background Isolate (The Listener)
// -----------------------------------------------------------------------------
@pragma('vm:entry-point')
void onNotificationData(NotificationEvent evt) async {
  // Debug print to confirm background service is alive
  print("Background Service Received: ${evt.packageName}");
  
  // CRITICAL: Ensure binding is initialized for background isolate
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    final prefs = await SharedPreferences.getInstance();

    // DYNAMIC LOOP CHECK: Get our own package name
    final String? myPackageName = prefs.getString('host_package_name');
    
    // Ignore notifications from THIS app to prevent infinite loops
    if (evt.packageName == myPackageName) {
      return;
    }

    final List<String> keywords = prefs.getStringList('keywords') ?? [];
    if (keywords.isEmpty) return;

    String content = "${evt.title ?? ''} ${evt.text ?? ''}".toLowerCase();
    
    List<String> matches = [];
    for (String keyword in keywords) {
      if (content.contains(keyword.toLowerCase())) {
        matches.add(keyword);
      }
    }

    if (matches.isNotEmpty) {
      print("MATCH FOUND: ${matches.join(',')}");
      await _logMatch(prefs, evt, matches);
      await _sendAlertNotification(evt, matches);
      
      // Notify main UI thread to refresh
      final SendPort? sendPort = IsolateNameServer.lookupPortByName('keyword_notification_port');
      sendPort?.send('update');
    }
  } catch (e) {
    print("Error in background service: $e");
  }
}

Future<void> _logMatch(SharedPreferences prefs, NotificationEvent evt, List<String> matches) async {
  List<String> currentLogs = prefs.getStringList('logs') ?? [];
  
  final logEntry = {
    'app': evt.packageName,
    'packageName': evt.packageName,
    'keyword': matches.join(', '),
    'timestamp': DateTime.now().toIso8601String(),
    'title': evt.title ?? '',
    'text': evt.text ?? '',
  };
  
  currentLogs.insert(0, jsonEncode(logEntry));
  
  // Keep only last 100 logs to save storage
  if (currentLogs.length > 100) {
    currentLogs = currentLogs.sublist(0, 100);
  }
  
  await prefs.setStringList('logs', currentLogs);
}

Future<void> _sendAlertNotification(NotificationEvent evt, List<String> matches) async {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: initializationSettingsAndroid),
  );

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'keyword_alert_channel', 
    'Keyword Alerts',
    channelDescription: 'Alerts when specific keywords are detected',
    importance: Importance.max,
    priority: Priority.high,
  );

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch % 100000,
    'Keyword Match Detected!',
    'Found "${matches.join(", ")}" in ${evt.packageName}',
    const NotificationDetails(android: androidPlatformChannelSpecifics),
  );
}

// -----------------------------------------------------------------------------
// 3. Application State Management
// -----------------------------------------------------------------------------
class AppState extends ChangeNotifier {
  List<String> _keywords = [];
  List<Map<String, dynamic>> _logs = [];
  bool _isListening = false;
  bool _isLoading = true;
  final ReceivePort _port = ReceivePort();

  List<String> get keywords => _keywords;
  List<Map<String, dynamic>> get logs => _logs;
  bool get isListening => _isListening;
  bool get isLoading => _isLoading;

  AppState() {
    _init();
  }

  Future<void> _init() async {
    // 1. Save package name for background isolate safety
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('host_package_name', packageInfo.packageName);

    // 2. Register the callback handle (CRITICAL)
    try {
      await NotificationsListener.initialize(callbackHandle: onNotificationData);
    } catch (e) {
      print("Failed to initialize listener: $e");
    }

    await _loadData();
    _initIsolateCommunication();
    await _checkServiceStatus();
    
    // Request Android 13+ Notification Permission
    await Permission.notification.request();

    _isLoading = false;
    notifyListeners();
  }

  void _initIsolateCommunication() {
    IsolateNameServer.removePortNameMapping('keyword_notification_port');
    IsolateNameServer.registerPortWithName(_port.sendPort, 'keyword_notification_port');
    _port.listen((message) {
      if (message == 'update') {
        refreshLogs();
      }
    });
  }

  Future<void> _checkServiceStatus() async {
    try {
      _isListening = await NotificationsListener.isRunning ?? false;
      notifyListeners();
    } catch (e) {
      _isListening = false;
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _keywords = prefs.getStringList('keywords') ?? [];
    List<String> rawLogs = prefs.getStringList('logs') ?? [];
    
    _logs = rawLogs.map((e) {
      try {
        return jsonDecode(e) as Map<String, dynamic>;
      } catch (e) {
        return {'title': 'Error', 'text': 'Log corrupted'};
      }
    }).toList();
    
    notifyListeners();
  }

  Future<void> addKeyword(String word) async {
    final trimmedWord = word.trim();
    if (trimmedWord.isEmpty || _keywords.contains(trimmedWord)) return;
    
    _keywords.add(trimmedWord);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('keywords', _keywords);
    notifyListeners();
  }

  Future<void> removeKeyword(String word) async {
    _keywords.remove(word);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('keywords', _keywords);
    notifyListeners();
  }
  
  // NEW: Delete a single log entry
  Future<void> deleteLog(Map<String, dynamic> logToDelete) async {
    _logs.remove(logToDelete);
    final prefs = await SharedPreferences.getInstance();
    final List<String> stringLogs = _logs.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('logs', stringLogs);
    notifyListeners();
  }

  Future<void> clearLogs() async {
    _logs.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('logs', []);
    notifyListeners();
  }

  Future<void> refreshLogs() async {
    await _loadData();
    notifyListeners();
  }

  Future<void> toggleListening(BuildContext context) async {
    try {
      bool running = await NotificationsListener.isRunning ?? false;
      
      if (!running) {
        bool hasPermission = await NotificationsListener.hasPermission ?? false;
        
        if (!hasPermission) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please grant Notification Access in Settings")),
            );
          }
          await NotificationsListener.openPermissionSettings();
          return;
        }

        await NotificationsListener.startService(
          foreground: true,
          title: "Keyword Listener Active",
          description: "Scanning incoming notifications...",
        );
        _isListening = true;
      } else {
        await NotificationsListener.stopService();
        _isListening = false;
      }
      notifyListeners();
    } catch (e) {
      print("Error toggling service: $e");
    }
  }
  
  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('keyword_notification_port');
    _port.close();
    super.dispose();
  }
}

// -----------------------------------------------------------------------------
// 4. UI Components
// -----------------------------------------------------------------------------
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>()._checkServiceStatus();
      context.read<AppState>().refreshLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keyword Notifier',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Keyword Notifier"),
        actions: [
          Row(
            children: [
              Text(appState.isListening ? "ON" : "OFF", 
                style: TextStyle(
                  color: appState.isListening ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.bold
                )
              ),
              Switch(
                value: appState.isListening,
                onChanged: (val) => appState.toggleListening(context),
                activeColor: Colors.green,
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: appState.isLoading 
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: const [
                KeywordsView(),
                HistoryView(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: 'Keywords',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}

class KeywordsView extends StatelessWidget {
  const KeywordsView({super.key});

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Keyword"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "e.g., OTP, Urgent"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<AppState>().addKeyword(controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        label: const Text("Add Keyword"),
        icon: const Icon(Icons.add),
      ),
      body: appState.keywords.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text("No keywords yet.", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text("Add words to monitor incoming notifications."),
                ],
              ),
            )
          : ListView.builder(
              itemCount: appState.keywords.length,
              itemBuilder: (context, index) {
                final word = appState.keywords[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(word[0].toUpperCase())),
                  title: Text(word, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => context.read<AppState>().removeKeyword(word),
                  ),
                );
              },
            ),
    );
  }
}

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});
  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmClearAll(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All?"),
        content: const Text("This will delete your entire match history."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              appState.clearLogs();
              Navigator.pop(ctx);
            },
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    // Filter logs based on search
    final filteredLogs = appState.logs.where((log) {
      if (_query.isEmpty) return true;
      final content = "${log['packageName']} ${log['title']} ${log['text']} ${log['keyword']}".toLowerCase();
      return content.contains(_query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search history...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                onPressed: () => _confirmClearAll(context, appState),
                tooltip: "Clear All Logs",
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
          ),
        ),
        Expanded(
          child: filteredLogs.isEmpty
              ? const Center(child: Text("No matches found"))
              : ListView.builder(
                  itemCount: filteredLogs.length,
                  itemBuilder: (ctx, i) {
                    final log = filteredLogs[i];
                    final date = DateTime.tryParse(log['timestamp'] ?? '') ?? DateTime.now();
                    
                    // Create unique key for Dismissible (timestamp + index)
                    final String uniqueKey = "${log['timestamp']}_$i";

                    return Dismissible(
                      key: Key(uniqueKey),
                      direction: DismissDirection.endToStart, // Swipe Right to Left only
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        // Remove item from state
                        context.read<AppState>().deleteLog(log);
                        
                        // Show Undo snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("Item deleted"),
                            action: SnackBarAction(
                              label: "Undo",
                              onPressed: () {
                                // In a real app, you would implement re-insert logic here
                              },
                            ),
                          ),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.notification_important, color: Colors.deepPurple),
                          title: Text(log['packageName'] ?? 'Unknown App', 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(log['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text("Matched: ${log['keyword']}", 
                                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                              Text("${date.hour}:${date.minute.toString().padLeft(2,'0')} • ${date.day}/${date.month}",
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text(log['packageName']),
                                content: SingleChildScrollView(
                                  child: Text("${log['title']}\n\n${log['text']}"),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close"))
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}