import 'dart:convert';
import 'dart:ui';
import 'dart:isolate';
import 'package:flutter/widgets.dart'; // For WidgetsFlutterBinding
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_notification_listener_plus/flutter_notification_listener_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void onNotificationData(NotificationEvent evt) async {
  print("Background Service Received: ${evt.packageName}");
  
  // CRITICAL: Ensure binding is initialized for background isolate
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    final prefs = await SharedPreferences.getInstance();

    // DYNAMIC LOOP CHECK
    final String? myPackageName = prefs.getString('host_package_name');
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