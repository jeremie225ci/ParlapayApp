package com.example.mk_mesenger

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.view.WindowManager
import android.app.KeyguardManager
import android.os.Bundle
import android.content.Intent
import android.app.PendingIntent
import android.app.NotificationManager
import android.app.NotificationChannel
import android.util.Log
import androidx.core.app.NotificationCompat
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.content.ContentResolver
import android.app.ActivityManager
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings

/**
 * Actividad principal que maneja llamadas entrantes y la comunicación con Flutter.
 * Incluye mejoras para asegurar que las llamadas entrantes puedan ser mostradas adecuadamente
 * incluso cuando el dispositivo está bloqueado o la aplicación en segundo plano.
 */
class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.example.mk_mesenger/call"
    private val TAG = "MainActivity"
    private var pendingCallData: Map<String, Any>? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Configurar canal de método bidireccional
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "wakeScreen" -> {
                    Log.d(TAG, "Llamando a wakeUpDevice desde Flutter")
                    wakeUpDevice()
                    result.success(true)
                }
                "showIncomingCall" -> {
                    val callId = call.argument<String>("callId") ?: ""
                    val callerName = call.argument<String>("callerName") ?: "Usuario"
                    val callType = call.argument<String>("callType") ?: "audio"
                    Log.d(TAG, "Mostrando llamada entrante: $callerName")
                    showIncomingCallScreen(callId, callerName, callType)
                    result.success(true)
                }
                "createHighPriorityNotification" -> {
                    try {
                        val callId = call.argument<String>("callId") ?: ""
                        val callerName = call.argument<String>("callerName") ?: "Usuario"
                        val callType = call.argument<String>("callType") ?: "audio"
                        
                        createFullScreenNotification(callId, callerName, callType)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error creando notificación de alta prioridad: ${e.message}")
                        result.error("ERROR", e.message, null)
                    }
                }
                "cancelNotification" -> {
                    val callId = call.argument<String>("callId") ?: ""
                    cancelCallNotification(callId)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Si tenemos datos pendientes de una llamada, enviarlos a Flutter ahora
        pendingCallData?.let {
            try {
                Log.d(TAG, "Enviando datos de llamada pendientes a Flutter")
                methodChannel.invokeMethod("handleIncomingCall", it)
                pendingCallData = null
            } catch (e: Exception) {
                Log.e(TAG, "Error enviando datos pendientes a Flutter: ${e.message}")
            }
        }
    }

    private fun wakeUpDevice() {
        try {
            Log.d(TAG, "Despertando dispositivo")
            
            // 1. Solicitar permisos relevantes en versiones recientes
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (!Settings.canDrawOverlays(this)) {
                    Log.w(TAG, "No se tienen permisos para mostrar sobre otras apps")
                }
                
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                val packageName = packageName
                if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                    Log.w(TAG, "No se tienen permisos para ignorar optimizaciones de batería")
                }
            }
            
            // 2. Asegurar que la actividad despierte la pantalla y pase el keyguard
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
                val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                keyguardManager.requestDismissKeyguard(this, null)
            } else {
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
                )
            }
            
            // 3. Adquirir wake lock para despertar la CPU
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE, "MK:WakeLock"
            )
            wakeLock?.acquire(60000) // Adquirir por 60 segundos máximo
            
            // 4. Liberar el wake lock después de un corto período
            android.os.Handler().postDelayed({
                if (wakeLock?.isHeld == true) {
                    try {
                        wakeLock?.release()
                    } catch (e: Exception) {
                        Log.e(TAG, "Error al liberar wakeLock: ${e.message}")
                    }
                }
            }, 30000) // Liberar después de 30 segundos
            
            // 5. Traer la aplicación al frente
            bringAppToForeground()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error al despertar el dispositivo: ${e.message}")
        }
    }
    
    private fun showIncomingCallScreen(callId: String, callerName: String, callType: String) {
        try {
            Log.d(TAG, "Mostrando pantalla de llamada entrante para: $callerName")
            
            // Despertar el dispositivo primero
            wakeUpDevice()
            
            // Crear un intent para abrir la actividad principal con datos de la llamada
            val intent = Intent(this, MainActivity::class.java).apply {
                action = "INCOMING_CALL"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("callId", callId)
                putExtra("callerName", callerName)
                putExtra("callType", callType)
                putExtra("action", "INCOMING_CALL")
                
                // Añadir flags adicionales en Android 12+
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
                }
            }
            
            // Iniciar la actividad
            startActivity(intent)
            
            // También crear una notificación de pantalla completa como respaldo
            createFullScreenNotification(callId, callerName, callType)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error mostrando pantalla de llamada entrante: ${e.message}")
        }
    }
    
    private fun createFullScreenNotification(callId: String, callerName: String, callType: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                // Obtener el NotificationManager
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                
                // Crear canal de notificación de alta prioridad si no existe
                val channelId = "call_channel"
                var channel = notificationManager.getNotificationChannel(channelId)
                
                if (channel == null) {
                    channel = NotificationChannel(
                        channelId,
                        "Llamadas",
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "Notificaciones de llamadas entrantes"
                        enableLights(true)
                        enableVibration(true)
                        setSound(
                            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE),
                            AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build()
                        )
                        lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                    }
                    notificationManager.createNotificationChannel(channel)
                }
                
                // Intent para pantalla completa (abrir app)
                val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
                    action = "INCOMING_CALL"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("callId", callId)
                    putExtra("callerName", callerName)
                    putExtra("callType", callType)
                }
                
                // Intent para aceptar llamada
                val acceptIntent = Intent("ANSWER_CALL").apply {
                    putExtra("callId", callId)
                    putExtra("callerName", callerName)
                    putExtra("callType", callType)
                }
                
                // Intent para rechazar llamada
                val rejectIntent = Intent("REJECT_CALL").apply {
                    putExtra("callId", callId)
                }
                
                // Configurar PendingIntent con flags según la versión de Android
                val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                
                val fullScreenPendingIntent = PendingIntent.getActivity(
                    this, 
                    callId.hashCode(), 
                    fullScreenIntent, 
                    pendingIntentFlags
                )
                
                val acceptPendingIntent = PendingIntent.getBroadcast(
                    this,
                    callId.hashCode() + 1,
                    acceptIntent,
                    pendingIntentFlags
                )
                
                val rejectPendingIntent = PendingIntent.getBroadcast(
                    this,
                    callId.hashCode() + 2,
                    rejectIntent,
                    pendingIntentFlags
                )
                
                // Crear notificación de pantalla completa
                val notification = NotificationCompat.Builder(this, channelId)
                    .setSmallIcon(android.R.drawable.ic_dialog_info)
                    .setContentTitle(callerName)
                    .setContentText(if (callType == "video") "Videollamada entrante" else "Llamada entrante")
                    .setPriority(NotificationCompat.PRIORITY_MAX)
                    .setCategory(NotificationCompat.CATEGORY_CALL)
                    .setFullScreenIntent(fullScreenPendingIntent, true)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setOngoing(true)
                    .setAutoCancel(false)
                    .setTimeoutAfter(60000) // 1 minuto
                    .setContentIntent(fullScreenPendingIntent)
                    .addAction(
                        android.R.drawable.ic_menu_call,
                        "Aceptar",
                        acceptPendingIntent
                    )
                    .addAction(
                        android.R.drawable.ic_menu_close_clear_cancel,
                        "Rechazar",
                        rejectPendingIntent
                    )
                    .build()
                
                // Mostrar notificación
                notificationManager.notify(callId.hashCode(), notification)
                Log.d(TAG, "Notificación de pantalla completa creada para llamada")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error creando notificación de pantalla completa: ${e.message}")
            }
        }
    }
    
    private fun cancelCallNotification(callId: String) {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(callId.hashCode())
            Log.d(TAG, "Notificación de llamada cancelada: $callId")
        } catch (e: Exception) {
            Log.e(TAG, "Error cancelando notificación: ${e.message}")
        }
    }
    
    private fun bringAppToForeground() {
        try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val appTasks = activityManager.appTasks
            
            if (appTasks.isNotEmpty()) {
                appTasks[0].moveToFront()
                Log.d(TAG, "Aplicación traída al frente")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error trayendo la app al frente: ${e.message}")
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Establecer la ventana para pantalla completa con prioridad alta
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )
        
        // Verificar si este inicio fue desde una notificación de llamada
        handleIncomingCallIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingCallIntent(intent)
    }
    
    private fun handleIncomingCallIntent(intent: Intent?) {
        if (intent == null) return
        
        when (intent.action) {
            "INCOMING_CALL" -> handleIncomingCall(intent)
            "ANSWER_CALL" -> handleAnswerCall(intent)
            "REJECT_CALL" -> handleRejectCall(intent)
            "UNLOCK_SCREEN" -> {
                // Esta acción solo sirve para desbloquear la pantalla
                wakeUpDevice()
            }
        }
    }
    
    private fun handleIncomingCall(intent: Intent) {
        try {
            Log.d(TAG, "Actividad iniciada desde notificación de llamada")
            
            // Despertar la pantalla inmediatamente
            wakeUpDevice()
            
            // Pasar los datos a Flutter a través de un mecanismo de comunicación
            val callId = intent.getStringExtra("callId") ?: ""
            val callerName = intent.getStringExtra("callerName") ?: ""
            val callType = intent.getStringExtra("callType") ?: ""
            
            // Crear objeto de datos para enviar a Flutter
            val callData = mapOf(
                "callId" to callId,
                "callerName" to callerName,
                "callType" to callType
            )
            
            // Si el motor Flutter está inicializado, enviar los datos
            if (flutterEngine != null) {
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).invokeMethod(
                    "handleIncomingCall",
                    callData
                )
                Log.d(TAG, "Datos de llamada enviados a Flutter")
            } else {
                // Guardar los datos para enviar cuando el motor esté listo
                Log.d(TAG, "FlutterEngine aún no inicializado, guardando datos de llamada para envío posterior")
                pendingCallData = callData
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error comunicando llamada a Flutter: ${e.message}")
        }
    }
    
    private fun handleAnswerCall(intent: Intent) {
        try {
            Log.d(TAG, "Procesando acción de aceptar llamada")
            
            // Despertar la pantalla
            wakeUpDevice()
            
            // Obtener datos de la llamada
            val callId = intent.getStringExtra("callId") ?: ""
            val callerName = intent.getStringExtra("callerName") ?: ""
            val callType = intent.getStringExtra("callType") ?: ""
            
            // Enviar a Flutter que debe aceptar la llamada
            if (flutterEngine != null) {
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).invokeMethod(
                    "acceptCall",
                    mapOf(
                        "callId" to callId,
                        "callerName" to callerName,
                        "callType" to callType
                    )
                )
                Log.d(TAG, "Acción de aceptar llamada enviada a Flutter")
            } else {
                Log.e(TAG, "No se puede aceptar la llamada, Flutter no inicializado")
            }
            
            // Cancelar notificación
            cancelCallNotification(callId)
        } catch (e: Exception) {
            Log.e(TAG, "Error aceptando llamada: ${e.message}")
        }
    }
    
    private fun handleRejectCall(intent: Intent) {
        try {
            Log.d(TAG, "Procesando acción de rechazar llamada")
            
            // Obtener ID de llamada
            val callId = intent.getStringExtra("callId") ?: ""
            
            // Enviar a Flutter que debe rechazar la llamada
            if (flutterEngine != null) {
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).invokeMethod(
                    "rejectCall",
                    mapOf("callId" to callId)
                )
                Log.d(TAG, "Acción de rechazar llamada enviada a Flutter")
            } else {
                Log.e(TAG, "No se puede rechazar la llamada, Flutter no inicializado")
            }
            
            // Cancelar notificación
            cancelCallNotification(callId)
        } catch (e: Exception) {
            Log.e(TAG, "Error rechazando llamada: ${e.message}")
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Liberar wake lock si existe
        if (wakeLock?.isHeld == true) {
            try {
                wakeLock?.release()
            } catch (e: Exception) {
                Log.e(TAG, "Error liberando wakeLock en onDestroy: ${e.message}")
            }
        }
    }
}