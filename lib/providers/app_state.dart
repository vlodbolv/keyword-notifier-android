import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_notification_listener_plus/flutter_notification_listener_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/background_service.dart'; // Import the service

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
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('host_package_name', packageInfo.packageName);

    try {
      // Reference the imported callback
      await NotificationsListener.initialize(callbackHandle: onNotificationData);
    } catch (e) {
      print("Failed to initialize listener: $e");
    }

    await _loadData();
    _initIsolateCommunication();
    await _checkServiceStatus();
    
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