package com.example.mk_mesenger

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.view.WindowManager
import android.app.KeyguardManager
import android.util.Log
import android.app.PendingIntent
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.RingtoneManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Receptor de difusión especializado para manejar notificaciones de llamadas entrantes.
 * Se asegura de que las llamadas puedan despertar el dispositivo y mostrar la pantalla
 * incluso cuando está bloqueado o en modo de ahorro de energía.
 */
class CallNotificationReceiver : BroadcastReceiver() {
    private val TAG = "CallNotificationReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received broadcast: ${intent.action}")
        
        when (intent.action) {
            "com.example.mk_mesenger.INCOMING_CALL" -> {
                handleIncomingCall(context, intent)
            }
            "ANSWER_CALL" -> {
                handleAnswerCall(context, intent)
            }
            "REJECT_CALL" -> {
                handleRejectCall(context, intent)
            }
        }
    }
    
    private fun handleIncomingCall(context: Context, intent: Intent) {
        try {
            // Extraer datos de la llamada
            val callId = intent.getStringExtra("callId") ?: ""
            val callerName = intent.getStringExtra("callerName") ?: "Usuario"
            val callType = intent.getStringExtra("callType") ?: "audio"
            
            Log.d(TAG, "Procesando llamada entrante de: $callerName")
            
            // 1. Activar vibración y sonido para asegurar que la llamada sea notada
            playRingtoneAndVibrate(context)
            
            // 2. Despertar el dispositivo y desbloquear la pantalla si es necesario
            val wakeLock = wakeUpDevice(context)
            
            // 3. Crear intent para abrir la app con flags de alta prioridad
            val mainIntent = Intent(context, MainActivity::class.java).apply {
                action = "INCOMING_CALL"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("callId", callId)
                putExtra("callerName", callerName)
                putExtra("callType", callType)
                putExtra("action", "INCOMING_CALL")
                
                // Agregar flags adicionales para forzar que se muestre
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
                }
            }
            
            try {
                // Desbloquear la pantalla
                unlockScreen(context)
                
                // Iniciar actividad con alta prioridad
                context.startActivity(mainIntent)
                
                Log.d(TAG, "Actividad iniciada con éxito para mostrar llamada entrante")
                
                // Cancelar notificaciones existentes con el mismo ID para evitar duplicados
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.cancel(callId.hashCode())
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error iniciando actividad: ${e.message}")
            }
            
            // Liberar el wakeLock después de un tiempo
            android.os.Handler().postDelayed({
                if (wakeLock.isHeld) {
                    try {
                        wakeLock.release()
                        Log.d(TAG, "WakeLock liberado correctamente")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error liberando wakeLock: ${e.message}")
                    }
                }
            }, 60000) // 60 segundos máximo
            
        } catch (e: Exception) {
            Log.e(TAG, "Error procesando llamada entrante: ${e.message}")
        }
    }
    
    private fun handleAnswerCall(context: Context, intent: Intent) {
        try {
            val callId = intent.getStringExtra("callId") ?: ""
            val callerName = intent.getStringExtra("callerName") ?: ""
            val callType = intent.getStringExtra("callType") ?: "audio"
            
            Log.d(TAG, "Respondiendo llamada de: $callerName")
            
            // Despertar el dispositivo primero
            wakeUpDevice(context)
            
            // Crear intent para abrir la app y aceptar la llamada
            val mainIntent = Intent(context, MainActivity::class.java).apply {
                action = "ANSWER_CALL"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("callId", callId)
                putExtra("callerName", callerName)
                putExtra("callType", callType)
                putExtra("action", "ANSWER_CALL")
            }
            
            // Iniciar actividad
            context.startActivity(mainIntent)
            
            // Cancelar notificación
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(callId.hashCode())
            
        } catch (e: Exception) {
            Log.e(TAG, "Error respondiendo llamada: ${e.message}")
        }
    }
    
    private fun handleRejectCall(context: Context, intent: Intent) {
        try {
            val callId = intent.getStringExtra("callId") ?: ""
            
            Log.d(TAG, "Rechazando llamada ID: $callId")
            
            // Crear intent para rechazar la llamada sin abrir la app
            val mainIntent = Intent(context, MainActivity::class.java).apply {
                action = "REJECT_CALL"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra("callId", callId)
                putExtra("action", "REJECT_CALL")
            }
            
            // Iniciar actividad
            context.startActivity(mainIntent)
            
            // Cancelar notificación
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(callId.hashCode())
            
        } catch (e: Exception) {
            Log.e(TAG, "Error rechazando llamada: ${e.message}")
        }
    }
    
    private fun wakeUpDevice(context: Context): PowerManager.WakeLock {
        try {
            Log.d(TAG, "Despertando dispositivo")
            
            // Adquirir wake lock para despertar la CPU y la pantalla
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE, 
                "MK:CallWakeLock"
            )
            
            // Adquirir por tiempo indefinido (se liberará manualmente)
            wakeLock.acquire(60000)
            Log.d(TAG, "WakeLock adquirido correctamente")
            
            return wakeLock
        } catch (e: Exception) {
            Log.e(TAG, "Error al despertar el dispositivo: ${e.message}")
            // Crear un wake lock vacío que no hará nada al liberarse
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            return powerManager.newWakeLock(0, "MK:DummyWakeLock")
        }
    }
    
    private fun unlockScreen(context: Context) {
        try {
            // Intentar desbloquear la pantalla en versiones recientes
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                if (keyguardManager.isKeyguardLocked) {
                    Log.d(TAG, "Pantalla bloqueada, intentando desbloquear")
                    
                    // En versiones recientes, necesitamos una actividad para desbloquear
                    val intent = Intent(context, MainActivity::class.java).apply {
                        action = "UNLOCK_SCREEN"
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                Intent.FLAG_ACTIVITY_CLEAR_TASK
                    }
                    context.startActivity(intent)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error desbloqueando pantalla: ${e.message}")
        }
    }
    
    private fun playRingtoneAndVibrate(context: Context) {
        try {
            // 1. Reproducir tono de llamada
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            // Asegurarse de que el volumen esté alto para llamadas
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_RING)
            audioManager.setStreamVolume(AudioManager.STREAM_RING, (maxVolume * 0.8).toInt(), 0)
            
            // Reproducir sonido de llamada
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            val ringtone = RingtoneManager.getRingtone(context, ringtoneUri)
            
            // Configurar atributos de audio
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                ringtone.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            }
            
            // Reproducir el tono
            ringtone.play()
            
            // 2. Vibrar en patrón de llamada
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                val vibrator = vibratorManager.defaultVibrator
                
                val pattern = longArrayOf(0, 500, 500, 500, 500, 500)
                val amplitudes = intArrayOf(0, 255, 0, 255, 0, 255)
                
                val effect = VibrationEffect.createWaveform(pattern, amplitudes, 0)
                vibrator.vibrate(effect)
            } else {
                val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val pattern = longArrayOf(0, 500, 500, 500, 500, 500)
                    val amplitudes = intArrayOf(0, 255, 0, 255, 0, 255)
                    
                    val effect = VibrationEffect.createWaveform(pattern, amplitudes, 0)
                    vibrator.vibrate(effect)
                } else {
                    val pattern = longArrayOf(0, 500, 500, 500, 500, 500)
                    vibrator.vibrate(pattern, 0)
                }
            }
            
            Log.d(TAG, "Sonido y vibración de llamada activados")
        } catch (e: Exception) {
            Log.e(TAG, "Error al reproducir sonido/vibración: ${e.message}")
        }
    }
} 