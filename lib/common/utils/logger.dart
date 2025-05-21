import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Niveles de log
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Clase para gestionar logs en la aplicación
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  
  AppLogger._internal() {
    _initializeLogger();
  }

  // Cola de mensajes para almacenar logs en memoria
  final Queue<String> _logQueue = Queue<String>();
  final int _maxQueueSize = 1000; // Máximo número de logs en memoria
  
  // Archivo de log
  File? _logFile;
  final int _maxLogFileSize = 5 * 1024 * 1024; // 5MB
  
  // Controlador para transmitir logs
  final StreamController<String> _logStreamController = StreamController<String>.broadcast();
  
  // Getter para el stream de logs
  Stream<String> get logStream => _logStreamController.stream;
  
  // Inicializar logger
  Future<void> _initializeLogger() async {
    if (!kIsWeb) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final logDir = Directory('${directory.path}/logs');
        
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        
        final now = DateTime.now();
        final fileName = 'app_log_${DateFormat('yyyyMMdd').format(now)}.txt';
        _logFile = File('${logDir.path}/$fileName');
        
        // Crear archivo si no existe
        if (!await _logFile!.exists()) {
          await _logFile!.create();
          log(LogLevel.info, 'Logger', 'Archivo de log creado: ${_logFile!.path}');
        }
        
        // Verificar tamaño del archivo
        final fileSize = await _logFile!.length();
        if (fileSize > _maxLogFileSize) {
          await _rotateLogFile();
        }
      } catch (e) {
        debugPrint('Error al inicializar logger: $e');
      }
    }
  }
  
  // Rotar archivo de log
  Future<void> _rotateLogFile() async {
    if (_logFile != null) {
      try {
        final now = DateTime.now();
        final backupFileName = 'app_log_${DateFormat('yyyyMMdd_HHmmss').format(now)}.bak';
        final directory = await getApplicationDocumentsDirectory();
        final logDir = Directory('${directory.path}/logs');
        final backupFile = File('${logDir.path}/$backupFileName');
        
        // Copiar archivo actual a backup
        await _logFile!.copy(backupFile.path);
        
        // Limpiar archivo actual
        await _logFile!.writeAsString('');
        
        log(LogLevel.info, 'Logger', 'Archivo de log rotado: ${backupFile.path}');
      } catch (e) {
        debugPrint('Error al rotar archivo de log: $e');
      }
    }
  }
  
  // Método principal para registrar logs
  void log(LogLevel level, String tag, String message, [dynamic error, StackTrace? stackTrace]) {
    final now = DateTime.now();
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(now);
    
    // Emoji según nivel de log
    String emoji;
    switch (level) {
      case LogLevel.debug:
        emoji = '🔍';
        break;
      case LogLevel.info:
        emoji = '✅';
        break;
      case LogLevel.warning:
        emoji = '⚠️';
        break;
      case LogLevel.error:
        emoji = '❌';
        break;
      case LogLevel.critical:
        emoji = '🔴';
        break;
    }
    
    // Formatear mensaje
    String formattedMessage = '$timestamp $emoji [$tag] $message';
    
    // Añadir error y stack trace si existen
    if (error != null) {
      formattedMessage += '\nError: $error';
    }
    
    if (stackTrace != null) {
      formattedMessage += '\nStack Trace: $stackTrace';
    }
    
    // Imprimir en consola
    debugPrint(formattedMessage);
    
    // Añadir a la cola de logs
    _addToQueue(formattedMessage);
    
    // Enviar al stream
    _logStreamController.add(formattedMessage);
    
    // Escribir en archivo
    _writeToFile(formattedMessage);
  }
  
  // Añadir log a la cola
  void _addToQueue(String log) {
    _logQueue.add(log);
    
    // Mantener tamaño máximo de cola
    while (_logQueue.length > _maxQueueSize) {
      _logQueue.removeFirst();
    }
  }
  
  // Escribir log en archivo
  Future<void> _writeToFile(String log) async {
    if (_logFile != null && !kIsWeb) {
      try {
        await _logFile!.writeAsString('$log\n', mode: FileMode.append);
        
        // Verificar tamaño del archivo
        final fileSize = await _logFile!.length();
        if (fileSize > _maxLogFileSize) {
          await _rotateLogFile();
        }
      } catch (e) {
        debugPrint('Error al escribir en archivo de log: $e');
      }
    }
  }
  
  // Obtener logs recientes
  List<String> getRecentLogs([int count = 100]) {
    final logs = _logQueue.toList();
    if (logs.length <= count) {
      return logs;
    }
    return logs.sublist(logs.length - count);
  }
  
  // Exportar logs a JSON
  Future<String> exportLogsToJson() async {
    final logs = getRecentLogs(_maxQueueSize);
    final jsonData = jsonEncode({
      'timestamp': DateTime.now().toIso8601String(),
      'logs': logs,
    });
    
    return jsonData;
  }
  
  // Guardar logs en archivo
  Future<String?> saveLogsToFile() async {
    if (kIsWeb) return null;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final fileName = 'app_logs_export_${DateFormat('yyyyMMdd_HHmmss').format(now)}.json';
      final file = File('${directory.path}/$fileName');
      
      final jsonData = await exportLogsToJson();
      await file.writeAsString(jsonData);
      
      return file.path;
    } catch (e) {
      debugPrint('Error al guardar logs en archivo: $e');
      return null;
    }
  }
  
  // Limpiar logs
  void clearLogs() {
    _logQueue.clear();
  }
  
  // Cerrar logger
  void dispose() {
    _logStreamController.close();
  }
}

// Métodos de conveniencia para usar el logger
void logDebug(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
  AppLogger().log(LogLevel.debug, tag, message, error, stackTrace);
}

void logInfo(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
  AppLogger().log(LogLevel.info, tag, message, error, stackTrace);
}

void logWarning(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
  AppLogger().log(LogLevel.warning, tag, message, error, stackTrace);
}

void logError(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
  AppLogger().log(LogLevel.error, tag, message, error, stackTrace);
}

void logCritical(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
  AppLogger().log(LogLevel.critical, tag, message, error, stackTrace);
}

