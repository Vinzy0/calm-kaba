import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LogEntry {
  final String symptom;
  final DateTime timestamp;
  
  LogEntry({required this.symptom, required this.timestamp});
  
  Map<String, dynamic> toMap() => {
    'symptom': symptom,
    'timestamp': timestamp.toIso8601String(),
  };
  
  factory LogEntry.fromMap(Map<String, dynamic> map) => LogEntry(
    symptom: map['symptom'],
    timestamp: DateTime.parse(map['timestamp']),
  );
}

class LogService {
  static const String _logKey = 'detection_logs';
  static final LogService _instance = LogService._internal();

  factory LogService() => _instance;

  LogService._internal();

  Future<void> addLog(String symptom) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await getLogs();
    logs.add(LogEntry(symptom: symptom, timestamp: DateTime.now()));
    
    final List<String> encodedLogs = logs.map((log) => jsonEncode(log.toMap())).toList();
    await prefs.setStringList(_logKey, encodedLogs);
  }

  Future<List<LogEntry>> getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? encodedLogs = prefs.getStringList(_logKey);
    
    if (encodedLogs == null) return [];
    
    return encodedLogs.map((log) => LogEntry.fromMap(jsonDecode(log))).toList();
  }
  
  Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logKey);
  }

  Future<File> exportLogs() async {
    final logs = await getLogs();
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/detection_logs.txt');
    
    final buffer = StringBuffer();
    buffer.writeln("--- Detection Logs ---");
    for (var log in logs) {
      buffer.writeln("${log.timestamp.toLocal()} - Symptom: ${log.symptom}");
    }
    
    return await file.writeAsString(buffer.toString());
  }
}
