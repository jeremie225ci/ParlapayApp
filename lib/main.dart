import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // Importar para MethodChannel
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mk_mesenger/common/models/call.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/common/utils/logger.dart';
import 'package:mk_mesenger/common/utils/widgets/error.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:mk_mesenger/feature/auth/controller/auth_controller.dart';
import 'package:mk_mesenger/feature/landing/screens/landing_screen.dart';
import 'package:mk_mesenger/feature/chat/screens/mobile_layout_screen.dart';
import 'package:mk_mesenger/firebase_options.dart';
import 'package:mk_mesenger/restart_wigdet.dart';
import 'package:mk_mesenger/services/rapyd_service.dart';
import 'package:mk_mesenger/widgets/router.dart';
import 'package:mk_mesenger/feature/call/repository/call_repository.dart';
import 'package:mk_mesenger/feature/call/screens/call_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Proveedor para el estado de inicialización de Rapyd
final rapydInitializedProvider = StateProvider<bool>((ref) => false);

// Clave de navegación global para acceder al Navigator desde cualquier lugar
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Clase de servicio para navegación global
class GlobalNavigation {
  static Future<T?> push<T>(Widget route) {
    return navigatorKey.currentState!.push(
      MaterialPageRoute(builder: (context) => route),
    );
  }
  
  static Future<T?> pushNamed<T>(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed(routeName, arguments: arguments);
  }
  
  static void pop<T>([T? result]) {
    navigatorKey.currentState!.pop(result);
  }
}

// Clase de servicio para notificaciones
class NotificationService {
  static late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  
  // Inicializar el servicio de notificaciones
  static Future<void> init() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // Configuración para Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración para iOS
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true, 
      requestSoundPermission: true,
    );
    
    // Configuración general
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    // Inicializar plugin con manejadores de respuesta
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _handleBackgroundNotificationResponse,
    );
    
    // Crear canal de notificación para llamadas en Android
    if (Platform.isAndroid) {
      await createCallNotificationChannel();
    }
  }
  
  // Crear canal de notificación específico para llamadas
  static Future<void> createCallNotificationChannel() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          
      if (androidPlugin != null) {
        // Canal para llamadas con alta prioridad
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'call_channel',
          'Llamadas',
          description: 'Notificaciones de llamadas entrantes',
          importance: Importance.max,
          enableLights: true,
          enableVibration: true,
          playSound: true,
          showBadge: true,
        );
        
        await androidPlugin.createNotificationChannel(channel);
      }
    }
  }
  
  // Mostrar notificación de llamada entrante
  static Future<void> showIncomingCallNotification({
    required String callId,
    required String callerId,
    required String callerName,
    required String callType,
    required String receiverId,
    String? callerPic,
  }) async {
    try {
      // Primero, intentar usar el código nativo para mostrar la pantalla de llamada
      if (Platform.isAndroid) {
        try {
          const platform = MethodChannel('com.example.mk_mesenger/call');
          
          // Despertar pantalla primero
          await platform.invokeMethod('wakeScreen');
          
          // Mostrar pantalla de llamada entrante a pantalla completa
          await platform.invokeMethod('showIncomingCall', {
            'callId': callId,
            'callerName': callerName,
            'callType': callType,
          });
          
          // También crear una notificación de alta prioridad como respaldo
          await platform.invokeMethod('createHighPriorityNotification', {
            'callId': callId,
            'callerName': callerName,
            'callType': callType,
          });
          
          logInfo('NotificationService', 'Método nativo para mostrar llamada invocado correctamente');
          return; // Si tenemos éxito, salimos aquí
        } catch (e) {
          logError('NotificationService', 'Error al invocar método nativo para mostrar llamada', e);
          // Continuamos con el enfoque de notificación si falla el método nativo
        }
      }
      
      // Enfoque alternativo: mostrar una notificación estándar
      if (Platform.isAndroid) {
        // Configuración para Android
        final androidPlatformChannelSpecifics = AndroidNotificationDetails(
          'call_channel',
          'Llamadas',
          channelDescription: 'Notificaciones de llamadas entrantes',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
          timeoutAfter: 60000, // 60 segundos
          ticker: 'Llamada entrante',
          styleInformation: BigTextStyleInformation(
            callType == 'video' ? 'Videollamada entrante' : 'Llamada entrante',
          ),
          actions: const [
            AndroidNotificationAction(
              'accept',
              'Aceptar',
              icon: DrawableResourceAndroidBitmap('ic_call_accept'),
              contextual: true,
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'reject',
              'Rechazar',
              icon: DrawableResourceAndroidBitmap('ic_call_reject'),
              contextual: true,
              showsUserInterface: true,
            ),
          ],
        );
        
        // Configuración para iOS
        const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
          categoryIdentifier: 'callCategory',
          interruptionLevel: InterruptionLevel.timeSensitive,
        );
        
        // Configuración general
        final platformChannelSpecifics = NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: iOSPlatformChannelSpecifics,
        );
        
        // Payload para identificar la llamada
        final payload = json.encode({
          'type': 'call',
          'callId': callId,
          'callerId': callerId,
          'callerName': callerName,
          'callType': callType,
          'receiverId': receiverId,
        });
        
        // Cancelar cualquier notificación previa con el mismo ID
        await flutterLocalNotificationsPlugin.cancel(callId.hashCode);
        
        // Mostrar la notificación
        await flutterLocalNotificationsPlugin.show(
          callId.hashCode,
          callerName,
          callType == 'video' ? 'Videollamada entrante' : 'Llamada entrante',
          platformChannelSpecifics,
          payload: payload,
        );
        
        logInfo('NotificationService', 'Notificación de llamada entrante mostrada');
      } else if (Platform.isIOS) {
        // Configuración para iOS
        final iOSPlatformChannelSpecifics = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
          categoryIdentifier: 'callCategory',
          interruptionLevel: InterruptionLevel.timeSensitive,
        );
        
        final platformChannelSpecifics = NotificationDetails(
          iOS: iOSPlatformChannelSpecifics,
        );
        
        // Payload para identificar la llamada
        final payload = json.encode({
          'type': 'call',
          'callId': callId,
          'callerId': callerId,
          'callerName': callerName,
          'callType': callType,
          'receiverId': receiverId,
        });
        
        // Mostrar la notificación
        await flutterLocalNotificationsPlugin.show(
          callId.hashCode,
          callerName,
          callType == 'video' ? 'Videollamada entrante' : 'Llamada entrante',
          platformChannelSpecifics,
          payload: payload,
        );
      }
    } catch (e) {
      logError('NotificationService', 'Error mostrando notificación de llamada', e);
    }
  }
  
  // Cancelar notificación de llamada
  static Future<void> cancelCallNotification(String callId) async {
    try {
      // 1. Cancelar notificación local
      await flutterLocalNotificationsPlugin.cancel(callId.hashCode);
      
      // 2. Cancelar notificación a través del código nativo (para asegurar que se cancele en todos lados)
      if (Platform.isAndroid) {
        try {
          const platform = MethodChannel('com.example.mk_mesenger/call');
          await platform.invokeMethod('cancelNotification', {'callId': callId});
        } catch (e) {
          logError('NotificationService', 'Error cancelando notificación nativa', e);
        }
      }
      
      logInfo('NotificationService', 'Notificación de llamada cancelada');
    } catch (e) {
      logError('NotificationService', 'Error cancelando notificación de llamada', e);
    }
  }
}

// Manejador de mensajes en segundo plano - DEBE estar fuera de cualquier clase
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Asegurarnos que Firebase esté inicializado
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  logInfo('BackgroundHandler', 'Mensaje recibido en background: ${message.messageId}');
  
  // Verificar si es una notificación de llamada
  if (message.data.containsKey('callId')) {
    logInfo('BackgroundHandler', 'Notificación de llamada entrante detectada');
    
    // Usar el método estático de CallRepository
    try {
      await CallRepository.firebaseMessagingBackgroundHandler(message);
      logInfo('BackgroundHandler', 'Notificación de llamada procesada correctamente');
    } catch (e) {
      logError('BackgroundHandler', 'Error procesando llamada en background', e);
    }
  }
}

// Manejador para respuestas de notificaciones en background
@pragma('vm:entry-point')
void _handleBackgroundNotificationResponse(NotificationResponse response) async {
  // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  try {
    if (response.payload == null) return;
    
    final data = json.decode(response.payload!);
    if (data['type'] != 'call') return;
    
    final String actionId = response.actionId ?? '';
    final String callId = data['callId'] ?? '';
    final String callerId = data['callerId'] ?? '';
    final String callerName = data['callerName'] ?? '';
    final String callType = data['callType'] ?? 'audio';
    final String receiverId = data['receiverId'] ?? '';
    
    // Cancelar la notificación
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.cancel(callId.hashCode);
    
    // Guardar la acción para ser procesada cuando la app se abra
    final prefs = await SharedPreferences.getInstance();
    
    if (actionId == 'accept') {
      await prefs.setString('call_action', json.encode({
        'action': 'accept',
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'callType': callType,
        'receiverId': receiverId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));
    } else if (actionId == 'reject') {
      // Rechazar llamada directamente
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('calls').doc(callId).update({
        'status': 'rejected',
        'endTimestamp': FieldValue.serverTimestamp(),
      });
      
      await prefs.remove('pending_call');
    }
  } catch (e) {
    print('Error procesando respuesta de notificación en background: $e');
  }
}

void main() {
  // Aseguramos que la inicialización de Flutter se complete
  WidgetsFlutterBinding.ensureInitialized();
  
  // AÑADIDO: Configurar el handler de mensajes en background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Inicializamos las variables
  bool firebaseInitialized = false;
  bool rapydInitialized = false;

  // Manejamos errores no capturados
  runZonedGuarded(() async {
    logInfo('Main', '🚀 Iniciando aplicación...');
    
    try {
      logInfo('Main', '📱 Inicializando Firebase...');
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      firebaseInitialized = true;
      
      // AÑADIDO: Configuración inicial de notificaciones
      await _configurarNotificaciones();
      
      logInfo('Main', '✅ Firebase inicializado correctamente');
    } catch (e, stack) {
      logError('Main', '❌ Error al inicializar Firebase', e, stack);
    }

    try {
      logInfo('Main', '💰 Inicializando servicio de Rapyd...');
      // Verificamos la conexión con el servicio de Rapyd
      final rapydService = RapydService();
      final isConnected = await rapydService.testConnection();
      rapydInitialized = isConnected;
      
      if (isConnected) {
        logInfo('Main', '✅ Servicio de Rapyd inicializado correctamente');
      } else {
        logWarning('Main', '⚠️ No se pudo conectar con el servicio de Rapyd');
      }
    } catch (e, stack) {
      logError('Main', '❌ Error al inicializar Rapyd', e, stack);
    }
    
    // Ejecutamos la aplicación en la misma zona
    runApp(
      ProviderScope(
        overrides: [
          rapydInitializedProvider.overrideWith((ref) => rapydInitialized),
        ],
        child: RestartWidget(
          child: MyApp(
            firebaseInitialized: firebaseInitialized,
            rapydInitialized: rapydInitialized,
          ),
        ),
      ),
    );
  }, (e, st) {
    logCritical('Main', '🔴 Error no capturado', e, st);
  });
}

// MEJORADA: Configuración de notificaciones con soporte para llamadas
Future<void> _configurarNotificaciones() async {
  try {
    // Solicitar permiso para notificaciones
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true, // Importante para llamadas
      announcement: true,
      carPlay: false,
    );
    
    logInfo('Main', 'Estado de permisos de notificaciones: ${settings.authorizationStatus}');
    
    // Configurar cómo se manejan las notificaciones cuando la app está en primer plano
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // AÑADIDO: Canal específico para llamadas en Android
    if (Platform.isAndroid) {
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        'call_channel',
        'Llamadas',
        description: 'Notificaciones de llamadas entrantes',
        importance: Importance.max,
        enableLights: true,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
          FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      
      // Inicializar plugin de notificaciones locales
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
          
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      );
      
      // Definir acciones para Android (botones de respuesta)
      const List<AndroidNotificationAction> callActions = [
        AndroidNotificationAction(
          'accept',
          'Aceptar',
          icon: DrawableResourceAndroidBitmap('ic_call_accept'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'reject',
          'Rechazar',
          icon: DrawableResourceAndroidBitmap('ic_call_reject'),
          showsUserInterface: true,
        ),
      ];
      
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: _handleBackgroundNotificationResponse,
      );
      
      // Guardar instancia para uso posterior
      NotificationService.flutterLocalNotificationsPlugin = flutterLocalNotificationsPlugin;
    }
    
    // Registrar manejadores para primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      logInfo('Main', 'Mensaje recibido en primer plano: ${message.messageId}');
      
      if (message.data.containsKey('callId')) {
        _mostrarNotificacionLlamadaEntrante(message);
      }
    });
    
    // Manejar cuando se abre la app desde una notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      logInfo('Main', 'App abierta desde notificación: ${message.messageId}');
      
      if (message.data.containsKey('callId') && message.data.containsKey('callerId')) {
        _manejarNotificacionLlamadaAbierta(message);
      }
    });
    
    // Verificar si la app fue abierta desde una notificación cuando estaba cerrada
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      logInfo('Main', 'App iniciada desde notificación: ${initialMessage.messageId}');
      
      if (initialMessage.data.containsKey('callId')) {
        _manejarNotificacionLlamadaAbierta(initialMessage);
      }
    }
    
    // Guardar token FCM en Firestore
    FirebaseMessaging.instance.getToken().then((token) {
      if (token != null) {
        logInfo('Main', 'FCM Token: $token');
        // Guardar token en Firestore para cada usuario autenticado
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'fcmToken': token});
        }
      }
    });
    
    logInfo('Main', 'Sistema de notificaciones configurado correctamente');
  } catch (e, stack) {
    logError('Main', 'Error configurando notificaciones', e, stack);
  }
}

// Mostrar notificación de llamada entrante con acciones
void _mostrarNotificacionLlamadaEntrante(RemoteMessage message) async {
  try {
    // Extraer datos de la llamada
    final callData = message.data;
    final callerName = callData['callerName'] ?? 'Usuario';
    final callerId = callData['callerId'] ?? '';
    final callId = callData['callId'] ?? '';
    final callType = callData['callType'] ?? 'audio';
    final receiverId = callData['receiverId'] ?? '';
    
    logInfo('Main', 'Llamada entrante recibida de: $callerName, ID: $callId');
    
    // Guardar datos de la llamada para acceso rápido
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_call', json.encode({
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'callerPic': callData['callerPic'] ?? '',
      'callType': callType,
      'receiverId': receiverId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'hasDialled': false,
      'isGroupCall': false,
      'callStatus': 'incoming',
      'callTime': 0
    }));
    
    // PRIMERO: Intentar usar el método nativo para mostrar la pantalla de llamada directamente
    if (Platform.isAndroid) {
      try {
        // Usar canal de método para comunicarse con el código nativo
        const platform = MethodChannel('com.example.mk_mesenger/call');
        await platform.invokeMethod('showIncomingCall', {
          'callId': callId,
          'callerName': callerName,
          'callType': callType,
        });
        logInfo('Main', 'Método nativo para mostrar llamada invocado correctamente');
        return; // Si tenemos éxito, salimos aquí
      } catch (e) {
        logError('Main', 'Error al invocar método nativo para mostrar llamada', e);
        // Continuamos con el enfoque de notificación si falla el método nativo
      }
    }
    
    // SEGUNDO: Enfoque de notificación tradicional como respaldo
    if (Platform.isAndroid) {
      // Crear notificación con estilo de llamada
      final androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'call_channel',
        'Llamadas',
        channelDescription: 'Notificaciones de llamadas entrantes',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true, // Importante para despertar la pantalla
        ongoing: true, // Notificación persistente
        autoCancel: false, // No se cancela automáticamente
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.call,
        visibility: NotificationVisibility.public,
        timeoutAfter: 60000, // 60 segundos
        ticker: 'Llamada entrante',
        styleInformation: BigTextStyleInformation(
          callType == 'video' ? 'Videollamada entrante' : 'Llamada entrante',
        ),
        actions: const [
          AndroidNotificationAction(
            'accept',
            'Aceptar',
            icon: DrawableResourceAndroidBitmap('ic_call_accept'),
            contextual: true,
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'reject',
            'Rechazar',
            icon: DrawableResourceAndroidBitmap('ic_call_reject'),
            contextual: true,
            showsUserInterface: true,
          ),
        ],
      );
      
      // Configuración para iOS
      const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      final platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );
      
      // Payload para identificar la llamada
      final payload = json.encode({
        'type': 'call',
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'callType': callType,
        'receiverId': receiverId,
      });
      
      // Primero asegurarse de cancelar cualquier notificación previa con el mismo ID
      await NotificationService.flutterLocalNotificationsPlugin.cancel(callId.hashCode);
      
      // Mostrar la notificación con ID único basado en callId
      await NotificationService.flutterLocalNotificationsPlugin.show(
        callId.hashCode, // ID único para la notificación
        callerName,
        callType == 'video' ? 'Videollamada entrante' : 'Llamada entrante',
        platformChannelSpecifics,
        payload: payload,
      );
      
      logInfo('Main', 'Notificación de llamada entrante mostrada');
      
      // TERCERO: Intentar abrir la pantalla de llamada directamente después de un breve retraso
      Future.delayed(Duration(milliseconds: 500), () {
        _navegarAPantallaLlamada(callId, callerId, callerName, callType, receiverId);
      });
    }
  } catch (e) {
    logError('Main', 'Error mostrando notificación de llamada', e);
  }
}

// Método para navegar directamente a la pantalla de llamada
void _navegarAPantallaLlamada(String callId, String callerId, String callerName, String callType, String receiverId) {
  try {
    // Construir objeto Call
    final call = Call(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerPic: '', // Se actualizará al cargar los datos
      receiverId: receiverId,
      receiverName: '', // Se actualizará al cargar los datos
      receiverPic: '',
      hasDialled: false,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isGroupCall: false,
      callType: callType,
      callStatus: 'incoming',
      callTime: 0,
    );
    
    // Navegar a pantalla de llamada usando navigatorKey global
    navigatorKey.currentState?.pushNamed(
      CallScreen.routeName,
      arguments: {
        'channelId': callId,
        'call': call,
        'isGroupChat': false,
      },
    );
    
    logInfo('Main', 'Navegado a pantalla de llamada directamente');
  } catch (e) {
    logError('Main', 'Error navegando a pantalla de llamada', e);
  }
}

// Función para despertar la pantalla en Android
void _despertarPantalla(String callId, String callerName, String callType) async {
  try {
    // En versiones más recientes de Android, podemos iniciar una actividad directamente
    // para mostrar la pantalla de llamada entrante
    final prefs = await SharedPreferences.getInstance();
    final hasActiveCall = prefs.containsKey('pending_call');
    
    if (hasActiveCall) {
      // Intenta abrir la app para mostrar la pantalla de llamada entrante
      if (Platform.isAndroid) {
        // Usar método nativo para despertar la pantalla
        try {
          // Usar canal de método para comunicarse con el código nativo
          const platform = MethodChannel('com.example.mk_mesenger/call');
          await platform.invokeMethod('wakeScreen');
          logInfo('Main', 'Método wakeScreen invocado correctamente');
          
          // Mostrar la pantalla de llamada después de un breve retraso
          await Future.delayed(Duration(milliseconds: 200));
          _navegarAPantallaLlamada(callId, '', callerName, callType, '');
        } catch (e) {
          logError('Main', 'Error intentando despertar pantalla', e);
          
          // Como respaldo, intentar navegar directamente
          _navegarAPantallaLlamada(callId, '', callerName, callType, '');
        }
      }
    }
  } catch (e) {
    logError('Main', 'Error en _despertarPantalla', e);
  }
}

// Manejar respuesta a notificación
void _handleNotificationResponse(NotificationResponse response) async {
  try {
    if (response.payload == null) return;
    
    final data = json.decode(response.payload!);
    if (data['type'] != 'call') return;
    
    final String actionId = response.actionId ?? '';
    final String callId = data['callId'] ?? '';
    final String callerId = data['callerId'] ?? '';
    final String callerName = data['callerName'] ?? '';
    final String callType = data['callType'] ?? 'audio';
    final String receiverId = data['receiverId'] ?? '';
    
    // Cancelar la notificación
    await NotificationService.flutterLocalNotificationsPlugin
        .cancel(callId.hashCode);
    
    if (actionId == 'accept') {
      // Aceptar llamada
      _aceptarLlamada(callId, callerId, callerName, receiverId, callType);
    } else if (actionId == 'reject') {
      // Rechazar llamada
      _rechazarLlamada(callId, callerId, receiverId);
    }
  } catch (e) {
    logError('Main', 'Error procesando respuesta de notificación', e);
  }
}

// Función para aceptar llamada
Future<void> _aceptarLlamada(String callId, String callerId, String callerName, 
                     String receiverId, String callType) async {
  try {
    logInfo('Main', 'Aceptando llamada: $callId de $callerName');
    
    // Cancelar cualquier notificación existente
    await NotificationService.cancelCallNotification(callId);
    
    // Despertar la pantalla si es Android
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('com.example.mk_mesenger/call');
        await platform.invokeMethod('wakeScreen');
      } catch (e) {
        logError('Main', 'Error despertando pantalla', e);
      }
    }
    
    // Construir objeto Call
    final call = Call(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerPic: '', // Se actualizará al cargar los datos
      receiverId: receiverId,
      receiverName: '', // Se actualizará al cargar los datos
      receiverPic: '',
      hasDialled: false,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isGroupCall: false,
      callType: callType,
      callStatus: 'ongoing',
      callTime: 0,
    );
    
    // Actualizar estado de la llamada en Firestore
    final firestore = FirebaseFirestore.instance;
    
    // Primero verificar si el documento existe para evitar errores
    final docSnapshot = await firestore.collection('calls').doc(callId).get();
    if (docSnapshot.exists) {
      await firestore.collection('calls').doc(callId).update({
        'status': 'ongoing',
      });
      
      logInfo('Main', 'Estado de llamada actualizado a ongoing en Firestore');
    } else {
      // Si el documento no existe, probablemente la llamada ya terminó
      logWarning('Main', 'Documento de llamada no encontrado, posiblemente la llamada ya terminó');
      return;
    }
    
    // Usar Future.delayed para asegurar que el contexto esté listo
    Future.delayed(Duration(milliseconds: 500), () {
      // Navegar a pantalla de llamada usando navigatorKey global
      navigatorKey.currentState?.pushNamed(
        CallScreen.routeName,
        arguments: {
          'channelId': callId,
          'call': call,
          'isGroupChat': false,
        },
      );
      
      logInfo('Main', 'Navegado a pantalla de llamada al aceptar');
    });
  } catch (e) {
    logError('Main', 'Error aceptando llamada', e);
  }
}

// Función para rechazar llamada
void _rechazarLlamada(String callId, String callerId, String receiverId) async {
  try {
    // Actualizar estado de la llamada en Firestore
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('calls').doc(callId).update({
      'status': 'rejected',
      'endTimestamp': FieldValue.serverTimestamp(),
    });
    
    // Limpiar datos pendientes
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_call');
    
    logInfo('Main', 'Llamada rechazada exitosamente');
  } catch (e) {
    logError('Main', 'Error rechazando llamada', e);
  }
}

// Manejar notificación abierta
void _manejarNotificacionLlamadaAbierta(RemoteMessage message) {
  try {
    final callData = message.data;
    final call = Call(
      callId: callData['callId'] ?? '',
      callerId: callData['callerId'] ?? '',
      callerName: callData['callerName'] ?? 'Usuario',
      callerPic: callData['callerPic'] ?? '',
      receiverId: callData['receiverId'] ?? '',
      receiverName: callData['receiverName'] ?? '',
      receiverPic: callData['receiverPic'] ?? '',
      hasDialled: false,
      timestamp: int.tryParse(callData['timestamp'] ?? '0') ?? 
          DateTime.now().millisecondsSinceEpoch,
      isGroupCall: false,
      callType: callData['callType'] ?? 'audio',
      callStatus: 'incoming',
      callTime: 0,
    );
    
    // Verificar si la llamada aún está en curso
    FirebaseFirestore.instance.collection('calls').doc(call.callId).get().then((doc) {
      if (doc.exists) {
        final status = doc.data()?['status'];
        if (status == 'ongoing' || status == 'incoming') {
          // Navegar a pantalla de llamada
          navigatorKey.currentState?.pushNamed(
            CallScreen.routeName,
            arguments: {
              'channelId': call.callId,
              'call': call,
              'isGroupChat': false,
            },
          );
        }
      }
    });
  } catch (e) {
    logError('Main', 'Error manejando notificación abierta', e);
  }
}

// MODIFICADO: Cambiado a StatefulWidget para manejar llamadas pendientes
class MyApp extends ConsumerStatefulWidget {
  final bool firebaseInitialized;
  final bool rapydInitialized;

  const MyApp({
    Key? key,
    required this.firebaseInitialized,
    required this.rapydInitialized,
  }) : super(key: key);
  
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  MethodChannel? _channel;

  @override
  void initState() {
    super.initState();
    _checkPendingCalls();
    _setupMethodChannel();
  }
  
  // Configurar el canal de método para recibir llamadas desde el código nativo
  void _setupMethodChannel() {
    _channel = MethodChannel('com.example.mk_mesenger/call');
    _channel!.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'handleIncomingCall':
          final callId = call.arguments['callId'] as String? ?? '';
          final callerName = call.arguments['callerName'] as String? ?? '';
          final callType = call.arguments['callType'] as String? ?? '';
          
          logInfo('MyApp', 'Llamada entrante recibida desde nativo: $callerName');
          
          // Navegar a la pantalla de llamada
          _navegarAPantallaLlamada(callId, '', callerName, callType, '');
          return true;
          
        case 'acceptCall':
          final callId = call.arguments['callId'] as String? ?? '';
          final callerName = call.arguments['callerName'] as String? ?? '';
          final callType = call.arguments['callType'] as String? ?? '';
          
          logInfo('MyApp', 'Aceptando llamada desde nativo: $callerName');
          
          // Aceptar la llamada usando la función existente
          await _aceptarLlamada(callId, '', callerName, '', callType);
          return true;
          
        case 'rejectCall':
          final callId = call.arguments['callId'] as String? ?? '';
          
          logInfo('MyApp', 'Rechazando llamada desde nativo: $callId');
          
          // Rechazar la llamada usando la función existente
          _rechazarLlamada(callId, '', '');
          return true;
          
        default:
          return false;
      }
    });
  }
  
  // NUEVO: Verificar si hay llamadas pendientes al iniciar la app
  Future<void> _checkPendingCalls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingCallString = prefs.getString('pending_call');
      
      if (pendingCallString != null && pendingCallString.isNotEmpty) {
        logInfo('MyApp', 'Llamada pendiente encontrada: $pendingCallString');
        
        final callData = json.decode(pendingCallString);
        
        // Verificar que la llamada no sea muy antigua (menos de 30 segundos)
        final int timestamp = callData['timestamp'] ?? 0;
        final int now = DateTime.now().millisecondsSinceEpoch;
        
        if (now - timestamp < 30000) { // 30 segundos
          // Construir objeto Call desde los datos guardados
          final Call call = Call(
            callId: callData['callId'] ?? '',
            callerId: callData['callerId'] ?? '',
            callerName: callData['callerName'] ?? 'Usuario',
            callerPic: callData['callerPic'] ?? '',
            receiverId: callData['receiverId'] ?? '',
            receiverName: callData['receiverName'] ?? '',
            receiverPic: callData['receiverPic'] ?? '',
            hasDialled: false,
            timestamp: timestamp,
            isGroupCall: false,
            callType: callData['callType'] ?? 'audio',
            callStatus: 'incoming',
            callTime: 0,
          );
          
          // Usar Future.delayed para asegurar que el contexto esté listo
          Future.delayed(Duration(milliseconds: 1000), () {
            logInfo('MyApp', 'Navegando a pantalla de llamada pendiente');
            navigatorKey.currentState?.pushNamed(
              CallScreen.routeName,
              arguments: {
                'channelId': call.callId,
                'call': call,
                'isGroupChat': false,
              },
            );
          });
        } else {
          logInfo('MyApp', 'Llamada pendiente ignorada por antigüedad: ${(now - timestamp) / 1000} segundos');
        }
        
        // Limpiar datos pendientes
        await prefs.remove('pending_call');
      }
      
      // Comprobar también acciones pendientes (para llamadas aceptadas en background)
      final callActionString = prefs.getString('call_action');
      if (callActionString != null && callActionString.isNotEmpty) {
        final actionData = json.decode(callActionString);
        
        if (actionData['action'] == 'accept') {
          _aceptarLlamada(
            actionData['callId'] ?? '',
            actionData['callerId'] ?? '',
            actionData['callerName'] ?? 'Usuario',
            actionData['receiverId'] ?? '',
            actionData['callType'] ?? 'audio'
          );
        } else if (actionData['action'] == 'show_incoming_call') {
          // Si la acción es mostrar llamada entrante, usar NotificationService
          final callId = actionData['callId'] ?? '';
          final callerId = actionData['callerId'] ?? '';
          final callerName = actionData['callerName'] ?? 'Usuario';
          final callType = actionData['callType'] ?? 'audio';
          final receiverId = actionData['receiverId'] ?? '';
          
          // Verificar si la acción no es muy antigua (menos de 30 segundos)
          final int timestamp = actionData['timestamp'] ?? 0;
          final int now = DateTime.now().millisecondsSinceEpoch;
          
          if (now - timestamp < 30000) { // 30 segundos
            logInfo('MyApp', 'Mostrando notificación de llamada entrante pendiente');
            
            // Usar NotificationService para mostrar la notificación de llamada
            await NotificationService.showIncomingCallNotification(
              callId: callId,
              callerId: callerId,
              callerName: callerName,
              callType: callType,
              receiverId: receiverId,
            );
          } else {
            logInfo('MyApp', 'Acción de llamada ignorada por antigüedad: ${(now - timestamp) / 1000} segundos');
          }
        }
        
        // Limpiar acción pendiente
        await prefs.remove('call_action');
      }
    } catch (e) {
      logError('MyApp', 'Error verificando llamadas pendientes', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    logInfo('MyApp', '🏗️ Construyendo MyApp (Firebase: ${widget.firebaseInitialized}, Rapyd: ${widget.rapydInitialized})');
    
    return MaterialApp(
      title: 'ParlaPay Messenger',
      debugShowCheckedModeBanner: false,
      
      // IMPORTANTE: Añadimos la clave de navegador global
      navigatorKey: navigatorKey,
      
      theme: ThemeData(
        scaffoldBackgroundColor: backgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: appBarColor,
          iconTheme: IconThemeData(color: textColor),
          titleTextStyle: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: bottomNavColor,
          selectedItemColor: selectedItemColor,
          unselectedItemColor: unselectedItemColor,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: accentColor,
          foregroundColor: textColor,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: textColor,
          ),
        ),
        textTheme: const TextTheme(
            bodyMedium: TextStyle(color: textColor),
        ),
      ),
      onGenerateRoute: generateRoute,
      home: !widget.firebaseInitialized
          ? ErrorScreen(error: 'Error de conectividad con Firebase')
          : ref.watch(userDataAuthProvider).when(
                data: (user) {
                  logInfo('MyApp', '👤 Usuario: ${user?.uid ?? 'null'}');
                  return user == null ? const LandingScreen() : const MobileLayoutScreen();
                },
                loading: () => const Loader(),
                error: (e, stack) {
                  logError('MyApp', '❌ Error al cargar usuario', e, stack);
                  return ErrorScreen(error: e.toString());
                },
              ),
    );
  }
}

// Bloque para información de elecciones - mantenido según original
class ElectionInfo {
  // Información de elecciones que podría estar aquí
}