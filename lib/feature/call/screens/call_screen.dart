import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mk_mesenger/common/models/call.dart';
import 'package:mk_mesenger/feature/call/controller/call_controller.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mk_mesenger/common/utils/logger.dart';

class CallScreen extends ConsumerStatefulWidget {
  static const String routeName = '/call-screen';
  final String channelId;
  final Call call;
  final bool isGroupChat;

  const CallScreen({
    Key? key,
    required this.channelId,
    required this.call,
    required this.isGroupChat,
  }) : super(key: key);

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _inCalling = false;
  String _callDuration = "00:00";
  bool _isMuted = false;
  bool _isSpeakerOn = true; // Activado por defecto para videollamadas
  bool _isVideoEnabled = true;
  int _callStartTime = 0;
  Timer? _callDurationTimer;
  bool _hasRemoteStream = false; // Para controlar si hay video remoto
  
  // Estado de la llamada
  bool _isClosing = false; // Bandera para control de cierre
  bool _isConnected = false; // Estado de conexión real
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _connectionTimeoutTimer; // Tiempo de espera máximo de conexión
  
  // Nueva variable para controlar la navegación
  bool _navigationInProgress = false;
  
  // Referencia a Firestore para la señalización
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Stream subscription para escuchar cambios en el estado de la llamada
  StreamSubscription? _callStatusSubscription;
  // Stream para candidatos ICE
  StreamSubscription? _iceCandidatesSub;

  @override
  void initState() {
    super.initState();
    // Inicializar componentes
    _initRenderers();
    _startCall();
    
    // Escuchar cambios en el estado de llamada
    _listenForCallStatusChanges();
    
    // Programar un temporizador de tiempo máximo de espera
    _connectionTimeoutTimer = Timer(Duration(seconds: 45), () {
      if (mounted && !_isConnected && !_isClosing) {
        logInfo('CallScreen', 'Tiempo de espera agotado. La llamada no se pudo establecer.');
        _handleConnectionFailure();
      }
    });
  }

  @override
  void dispose() {
    logInfo('CallScreen', 'dispose() llamado');
    
    // Marcar como cerrando para prevenir ejecución de callbacks
    _isClosing = true;
    
    // Limpiar recursos
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _disposeMediaResources();
    _callDurationTimer?.cancel();
    _callStatusSubscription?.cancel();
    _iceCandidatesSub?.cancel();
    _reconnectTimer?.cancel();
    _connectionTimeoutTimer?.cancel();
    super.dispose();
  }

  // Método para limpiar recursos multimedia
  void _disposeMediaResources() {
    logInfo('CallScreen', 'Limpiando recursos multimedia');
    
    // Detener todas las pistas de audio/video
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        track.stop();
        logInfo('CallScreen', 'Pista local detenida: ${track.kind}');
      });
      _localStream!.dispose();
      _localStream = null;
    }
    
    // Cerrar conexión peer
    if (_peerConnection != null) {
      _peerConnection!.close();
      _peerConnection = null;
    }
  }

  // Escuchar cambios en el estado de la llamada
  void _listenForCallStatusChanges() {
    _callStatusSubscription = _firestore
        .collection('calls')
        .doc(widget.channelId)
        .snapshots()
        .listen((snapshot) {
      if (_isClosing) return; // Evitar procesamiento durante el cierre
      
      if (!snapshot.exists) {
        // Si el documento fue eliminado, colgar la llamada
        if (mounted && _inCalling && !_navigationInProgress) {
          logInfo('CallScreen', 'Documento de llamada eliminado, colgando llamada');
          _cleanupAndPop('ended');
        }
        return;
      }
      
      final data = snapshot.data();
      if (data != null) {
        final status = data['status'] as String?;
        // Verificar si el estado cambió a 'ended' o 'rejected'
        if (status == 'ended' || status == 'rejected') {
          logInfo('CallScreen', 'Estado de llamada cambiado a "$status"');
          // Si el estado cambió a 'ended' o 'rejected', colgar la llamada
          if (mounted && _inCalling && !_navigationInProgress) {
            logInfo('CallScreen', 'Ejecutando cleanup debido a cambio de estado remoto');
            _cleanupAndPop(status ?? 'ended');
          }
        }
      }
    }, onError: (e) {
      logError('CallScreen', 'Error escuchando cambios de estado de llamada', e);
    });
  }

  Future<void> _initRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      logInfo('CallScreen', 'Renderers inicializados correctamente');
    } catch (e) {
      logError('CallScreen', 'Error inicializando renderers', e);
    }
  }

  Future<void> _startCall() async {
    try {
      // Solicitar permisos explícitamente
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
        Permission.camera,
      ].request();
      
      logInfo('CallScreen', 'Permisos de micrófono: ${statuses[Permission.microphone]}');
      logInfo('CallScreen', 'Permisos de cámara: ${statuses[Permission.camera]}');

      // Configuración mejorada de STUN/TURN con más servidores
      final Map<String, dynamic> configuration = {
        'iceServers': [
          {'urls': ['stun:stun.l.google.com:19302']},
          {'urls': ['stun:stun1.l.google.com:19302']},
          {'urls': ['stun:stun2.l.google.com:19302']},
          {
            'urls': ['turn:numb.viagenie.ca'],
            'username': 'webrtc@live.com',
            'credential': 'muazkh'
          }
        ],
        'sdpSemantics': 'unified-plan',
        'iceCandidatePoolSize': 10,
      };

      // Crear peer connection con configuración actualizada
      _peerConnection = await createPeerConnection(configuration);

      logInfo('CallScreen', 'PeerConnection creada correctamente');

      // Configurar constraints de medios con opciones específicas
      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true
        },
        'video': widget.call.callType == 'video' ? {
          'facingMode': 'user',
          'width': {'ideal': 640, 'max': 1280},
          'height': {'ideal': 480, 'max': 720},
          'frameRate': {'ideal': 24, 'max': 30}
        } : false
      };

      logInfo('CallScreen', 'Solicitando MediaStream local con constraints: $mediaConstraints');
      
      // Obtener stream local
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      
      // Verificar stream local
      if (_localStream == null) {
        logError('CallScreen', 'No se pudo obtener el stream local');
        _handleCallError();
        return;
      }
      
      // Asignar stream local al renderizador
      _localRenderer.srcObject = _localStream;
      
      // Debug: Listar tracks en el stream local
      _localStream!.getTracks().forEach((track) {
        track.enabled = true;
        logInfo('CallScreen', 'Pista local: ${track.kind}, enabled: ${track.enabled}');
      });
      
      // Añadir tracks uno a uno para mejor depuración
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
        logInfo('CallScreen', 'Añadida pista al PeerConnection: ${track.kind}');
      });

      // Configurar manejadores de eventos
      _setupPeerConnectionListeners();
      
      logInfo('CallScreen', 'PeerConnection y MediaStream inicializados correctamente');

      // Iniciar señalización según rol
      if (widget.call.hasDialled) {
        logInfo('CallScreen', 'Iniciando como llamante - creando oferta');
        await _createOffer();
      } else {
        logInfo('CallScreen', 'Iniciando como receptor - esperando oferta');
        await _listenForOffer();
      }

      // Escuchar respuesta si somos llamante
      if (widget.call.hasDialled) {
        logInfo('CallScreen', 'Esperando respuesta como llamante');
        await _listenForAnswer();
      }
      
      // Escuchar candidatos ICE
      _listenForIceCandidates();

      // Solo activamos _inCalling, pero NO iniciamos el timer
      // El timer se activará cuando se establezca la conexión
      setState(() => _inCalling = true);
      
      // Configurar audio según tipo de llamada
      await _configureSpeakerphone();
      
    } catch (e) {
      logError('CallScreen', 'Error iniciando llamada: $e');
      _handleCallError();
    }
  }

  // Método para configurar speakers
  Future<void> _configureSpeakerphone() async {
    try {
      // Para videollamadas, usar altavoz por defecto
      if (widget.call.callType == 'video') {
        await Helper.setSpeakerphoneOn(true);
        setState(() => _isSpeakerOn = true);
        logInfo('CallScreen', 'Altavoz activado para videollamada');
      } else {
        // Para llamadas de voz, usar auricular por defecto
        await Helper.setSpeakerphoneOn(false);
        setState(() => _isSpeakerOn = false);
        logInfo('CallScreen', 'Auricular activado para llamada de voz');
      }
    } catch (e) {
      logError('CallScreen', 'Error configurando altavoz: $e');
    }
  }

  // Método para configurar listeners del PeerConnection
  void _setupPeerConnectionListeners() {
    if (_peerConnection == null) return;
    
    // Manejo de pistas remotas
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (_isClosing) return; // No procesar si estamos cerrando
      
      logInfo('CallScreen', 'onTrack llamado - stream recibido: ${event.streams.length} - tipo: ${event.track.kind}');
      
      if (event.streams.isEmpty) {
        logError('CallScreen', 'onTrack llamado pero streams está vacío');
        return;
      }
      
      final MediaStream stream = event.streams[0];
      
      // IMPORTANTE: Asignar SIEMPRE el stream al renderer, sin importar el tipo de pista
      _remoteRenderer.srcObject = stream;
      
      // Habilitar pista explícitamente
      event.track.enabled = true;
      
      logInfo('CallScreen', 'Pista remota habilitada: ${event.track.kind}, ID: ${event.track.id}');
      
      // Verificar pistas de audio y video
      final bool hasVideo = stream.getVideoTracks().isNotEmpty;
      final bool hasAudio = stream.getAudioTracks().isNotEmpty;
      
      logInfo('CallScreen', 'Stream remoto recibido - Video: $hasVideo, Audio: $hasAudio');
      
      // Actualizar UI cuando hay video disponible (con retraso para permitir inicialización)
      if (mounted && !_isClosing) {
        // Retraso más largo para dar tiempo a que se estabilice el video
        Future.delayed(Duration(milliseconds: 1000), () {
          if (!mounted || _isClosing) return;
          setState(() {
            _hasRemoteStream = hasVideo;
            
            // Marcar como conectado y empezar el temporizador solo ahora
            if (!_isConnected) {
              _isConnected = true;
              _reconnectAttempts = 0;
              
              // INICIAR TIMER SOLO CUANDO HAY CONEXIÓN REAL
              _callStartTime = DateTime.now().millisecondsSinceEpoch;
              _startDurationTimer();
              
              // Cancelar timer de timeout
              _connectionTimeoutTimer?.cancel();
            }
          });
        });
      }
      
      // Debug: Monitorear si la pista termina o se mutea
      event.track.onEnded = () {
        if (_isClosing) return;
        logInfo('CallScreen', 'Track remoto terminado: ${event.track.kind}');
      };
      
      event.track.onMute = () {
        if (_isClosing) return;
        logInfo('CallScreen', 'Track remoto muteado: ${event.track.kind}');
      };
      
      event.track.onUnMute = () {
        if (_isClosing) return;
        logInfo('CallScreen', 'Track remoto desmuteado: ${event.track.kind}');
      };
    };
    
    // Manejar también eventos de addStream (algunos dispositivos usan esto en lugar de onTrack)
    _peerConnection!.onAddStream = (MediaStream stream) {
      if (_isClosing) return; // No procesar si estamos cerrando
      
      logInfo('CallScreen', 'onAddStream: recibido stream con ${stream.getTracks().length} pistas');
      
      // Asignar stream al renderer
      _remoteRenderer.srcObject = stream;
      
      // Habilitar todas las pistas
      stream.getTracks().forEach((track) {
        track.enabled = true;
        logInfo('CallScreen', 'Pista habilitada desde onAddStream: ${track.kind}');
      });
      
      // Verificar pistas de video
      final bool hasVideo = stream.getVideoTracks().isNotEmpty;
      
      if (mounted && !_isClosing) {
        setState(() {
          _hasRemoteStream = hasVideo;
          
          // Marcar como conectado y empezar el temporizador solo ahora
          if (!_isConnected) {
            _isConnected = true;
            _reconnectAttempts = 0;
            
            // INICIAR TIMER SOLO CUANDO HAY CONEXIÓN REAL
            _callStartTime = DateTime.now().millisecondsSinceEpoch;
            _startDurationTimer();
            
            // Cancelar timer de timeout
            _connectionTimeoutTimer?.cancel();
          }
        });
      }
    };

    // Manejar candidato ICE
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_isClosing) return; // No procesar si estamos cerrando
      
      logInfo('CallScreen', 'Se generó candidato ICE local');
      _sendIceCandidate(candidate);
    };

    // Manejar cambios en el estado de la conexión ICE
    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      if (_isClosing) return; // No procesar si estamos cerrando
      
      logInfo('CallScreen', 'Estado de conexión ICE: $state');
      
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
          logInfo('CallScreen', 'Conexión ICE establecida');
          if (mounted && !_isClosing) {
            setState(() {
              // Iniciar el temporizador solo cuando la conexión se establece realmente
              if (!_isConnected) {
                _isConnected = true;
                _reconnectAttempts = 0;
                
                // INICIAR TIMER SOLO CUANDO HAY CONEXIÓN REAL
                _callStartTime = DateTime.now().millisecondsSinceEpoch;
                _startDurationTimer();
                
                // Cancelar timer de timeout
                _connectionTimeoutTimer?.cancel();
              }
            });
          }
          break;
          
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          logInfo('CallScreen', 'Conexión ICE completada');
          break;
          
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          logError('CallScreen', 'Conexión ICE fallida');
          // Intentar reiniciar ICE
          if (!_isClosing && _peerConnection != null) {
            _peerConnection!.restartIce();
            
            // Si los intentos son pocos, programar un reinicio más completo
            if (_reconnectAttempts < 2 && !_isClosing) {
              _reconnectAttempts++;
              _reconnectTimer?.cancel();
              _reconnectTimer = Timer(Duration(seconds: 2), () {
                if (!_isClosing) _restartConnection();
              });
            } else if (mounted && !_isClosing && !_navigationInProgress) {
              _handleConnectionFailure();
            }
          }
          break;
          
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          logError('CallScreen', 'Conexión ICE desconectada');
          if (_inCalling && !_isClosing && _peerConnection != null) {
            // Intentar reconectar
            _peerConnection!.restartIce();
          }
          break;
          
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          logError('CallScreen', 'Conexión ICE cerrada');
          // No hacer nada si ya no estamos en llamada (cierre normal)
          if (_inCalling && !_isClosing && !_navigationInProgress) {
            _handleConnectionFailure();
          }
          break;
          
        default:
          // Otros estados: checking, new, etc.
          break;
      }
    };
    
    // Monitorear estado de la conexión para depuración
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      if (_isClosing) return; // No procesar si estamos cerrando
      
      logInfo('CallScreen', 'Estado de la conexión peer: $state');
      
      // Cuando la conexión se establece, forzar actualización
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        logInfo('CallScreen', '🔥 Conexión WebRTC establecida - verificando video remoto');
        
        // Pequeño retraso para asegurar que todo esté inicializado
        Future.delayed(Duration(milliseconds: 1000), () {
          if (mounted && !_isClosing) {
            setState(() {
              // Iniciar el temporizador solo cuando la conexión se establece realmente
              if (!_isConnected) {
                _isConnected = true;
                _reconnectAttempts = 0;
                
                // INICIAR TIMER SOLO CUANDO HAY CONEXIÓN REAL
                _callStartTime = DateTime.now().millisecondsSinceEpoch;
                _startDurationTimer();
                
                // Cancelar timer de timeout
                _connectionTimeoutTimer?.cancel();
              }
              
              if (_remoteRenderer.srcObject != null) {
                _hasRemoteStream = _remoteRenderer.srcObject!.getVideoTracks().isNotEmpty;
                // Log detallado para debug
                final videoTracks = _remoteRenderer.srcObject!.getVideoTracks();
                logInfo('CallScreen', 'Video remoto: ${videoTracks.length} pistas, habilitadas: ${videoTracks.isNotEmpty ? videoTracks.first.enabled : false}');
              }
            });
          }
        });
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        if (!_isClosing && _reconnectAttempts < 2) {
          _reconnectAttempts++;
          _reconnectTimer?.cancel();
          _reconnectTimer = Timer(Duration(seconds: 2), () {
            if (!_isClosing) _restartConnection();
          });
        } else if (!_isClosing && !_navigationInProgress) {
          _handleConnectionFailure();
        }
      }
    };
    
    // Monitorear estado de la señalización para depuración
    _peerConnection!.onSignalingState = (RTCSignalingState state) {
      if (_isClosing) return; // No procesar si estamos cerrando
      
      logInfo('CallScreen', 'Estado de señalización: $state');
    };
  }

  // Método para reintentar la conexión
  Future<void> _restartConnection() async {
    if (_isClosing || _peerConnection == null) return;
    
    logInfo('CallScreen', 'Intentando reiniciar conexión (intento $_reconnectAttempts)');
    
    try {
      if (widget.call.hasDialled) {
        // Si somos el llamante, crear una nueva oferta con iceRestart
        RTCSessionDescription description = await _peerConnection!.createOffer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': widget.call.callType == 'video',
          'iceRestart': true, // Forzar reinicio ICE
        });
        
        await _peerConnection!.setLocalDescription(description);
        
        // Enviar nueva oferta
        await _firestore.collection('calls').doc(widget.channelId).update({
          'offer': {
            'type': description.type,
            'sdp': description.sdp,
          },
          'status': 'reconnecting',
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        logInfo('CallScreen', 'Oferta de reinicio enviada');
      }
    } catch (e) {
      logError('CallScreen', 'Error en reinicio de conexión: $e');
    }
  }

  // Enviar candidato ICE - Mejorado con retry
  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    if (_isClosing) return; // No enviar si estamos cerrando
    
    try {
      // Colección para candidatos del llamante o receptor
      final String collectionPath = widget.call.hasDialled 
          ? 'caller_candidates' 
          : 'callee_candidates';
      
      await _firestore
          .collection('calls')
          .doc(widget.channelId)
          .collection('candidates')
          .doc(collectionPath)
          .collection('list')
          .add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'serverTimestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Reintentar una vez en caso de error
      logError('CallScreen', 'Error enviando candidato ICE, reintentando: $e');
      try {
        if (_isClosing) return; // No reintentar si estamos cerrando
        
        await Future.delayed(Duration(milliseconds: 500));
        
        // Colección para candidatos del llamante o receptor
        final String collectionPath = widget.call.hasDialled 
            ? 'caller_candidates' 
            : 'callee_candidates';
        
        await _firestore
            .collection('calls')
            .doc(widget.channelId)
            .collection('candidates')
            .doc(collectionPath)
            .collection('list')
            .add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'serverTimestamp': FieldValue.serverTimestamp(),
        });
      } catch (retryError) {
        logError('CallScreen', 'Error en segundo intento enviando candidato ICE: $retryError');
      }
    }
  }

  // Escuchar candidatos ICE - MEJORADO con mejor manejo de errores
  void _listenForIceCandidates() {
    final String candidatesPath = widget.call.hasDialled 
        ? 'callee_candidates' 
        : 'caller_candidates';
    
    _iceCandidatesSub = _firestore
        .collection('calls')
        .doc(widget.channelId)
        .collection('candidates')
        .doc(candidatesPath)
        .collection('list')
        .snapshots()
        .listen((snapshot) {
      if (_isClosing) return; // No procesar si estamos cerrando
      
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;
          
          logInfo('CallScreen', 'Candidato ICE remoto recibido');
          
          try {
            if (_peerConnection != null) {
              _peerConnection!.addCandidate(RTCIceCandidate(
                data['candidate'],
                data['sdpMid'],
                data['sdpMLineIndex'],
              ));
            }
          } catch (e) {
            logError('CallScreen', 'Error añadiendo candidato ICE: $e');
          }
        }
      }
    }, onError: (e) {
      logError('CallScreen', 'Error escuchando candidatos ICE: $e');
    });
  }

  // Crear oferta SDP - MEJORADA con optimizaciones explícitas
  Future<void> _createOffer() async {
    if (_isClosing || _peerConnection == null) return;
    
    try {
      // Configuración explícita para solicitar audio y video
      RTCSessionDescription description = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': widget.call.callType == 'video',
      });
      
      logInfo('CallScreen', 'Oferta SDP creada: ${description.type}');
      
      // Modificar SDP para optimizar codecs
      String sdp = description.sdp!;
      
      // Forzar opus como codec de audio con parámetros optimizados
      sdp = sdp.replaceAllMapped(
        RegExp(r'a=rtpmap:(\d+) opus/48000/2'), 
        (Match match) => 'a=rtpmap:${match.group(1)} opus/48000/2\r\na=fmtp:${match.group(1)} minptime=10;useinbandfec=1;stereo=1'
      );
      
      // Actualizar SDP con modificaciones
      description.sdp = sdp;
      
      // Establecer descripción local
      await _peerConnection!.setLocalDescription(description);
      
      // Guardar oferta en Firestore
      await _firestore.collection('calls').doc(widget.channelId).set({
        'offer': {
          'type': description.type,
          'sdp': description.sdp,
        },
        'callerId': widget.call.callerId,
        'callType': widget.call.callType,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'ongoing', // Estado explícito
      }, SetOptions(merge: true));
      
      logInfo('CallScreen', 'Oferta enviada a Firestore');
    } catch (e) {
      logError('CallScreen', 'Error creando oferta: $e');
      if (!_isClosing) _handleCallError();
    }
  }

  // Escuchar por la oferta SDP - MEJORADO con optimizaciones
  Future<void> _listenForOffer() async {
    if (_isClosing || _peerConnection == null) return;
    
    try {
      final callDoc = await _firestore.collection('calls').doc(widget.channelId).get();
      if (!callDoc.exists) {
        logError('CallScreen', 'Documento de llamada no encontrado');
        if (!_isClosing) _handleCallError();
        return;
      }
      
      final data = callDoc.data();
      if (data == null || !data.containsKey('offer')) {
        logError('CallScreen', 'Datos de oferta no encontrados');
        if (!_isClosing) _handleCallError();
        return;
      }
      
      final offer = data['offer'];
      logInfo('CallScreen', 'Oferta SDP recibida');
      
      // Verificar que la oferta tenga los campos necesarios
      if (offer == null || !offer.containsKey('sdp') || !offer.containsKey('type')) {
        logError('CallScreen', 'Oferta SDP incompleta o inválida');
        if (!_isClosing) _handleCallError();
        return;
      }
      
      // Establecer descripción remota
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(
        offer['sdp'],
        offer['type'],
      ));
      
      // Configuración explícita para respuesta optimizada
      RTCSessionDescription answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': widget.call.callType == 'video',
      });
      
      // Modificar SDP de respuesta para optimizar
      String sdp = answer.sdp!;
      
      // Forzar opus como codec de audio con parámetros optimizados
      sdp = sdp.replaceAllMapped(
        RegExp(r'a=rtpmap:(\d+) opus/48000/2'), 
        (Match match) => 'a=rtpmap:${match.group(1)} opus/48000/2\r\na=fmtp:${match.group(1)} minptime=10;useinbandfec=1;stereo=1'
      );
      
      // Actualizar SDP con modificaciones
      answer.sdp = sdp;
      
      // Establecer descripción local
      await _peerConnection!.setLocalDescription(answer);
      
      // Guardar respuesta en Firestore
      await _firestore.collection('calls').doc(widget.channelId).update({
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'ongoing', // Estado explícito
      });
      
      logInfo('CallScreen', 'Respuesta SDP enviada');
    } catch (e) {
      logError('CallScreen', 'Error procesando oferta: $e');
      if (!_isClosing) _handleCallError();
    }
  }

  // Escuchar por la respuesta SDP - MEJORADO para mejor manejo de errores
  Future<void> _listenForAnswer() async {
    _firestore
        .collection('calls')
        .doc(widget.channelId)
        .snapshots()
        .listen((snapshot) async {
      // No procesar si estamos finalizando o PeerConnection es nulo
      if (_isClosing || _peerConnection == null) return;
          
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data.containsKey('answer')) {
          final answer = data['answer'];
          
          // Verificar que la respuesta tenga los campos necesarios
          if (answer == null || !answer.containsKey('sdp') || !answer.containsKey('type')) {
            logError('CallScreen', 'Respuesta SDP incompleta o inválida');
            return;
          }
          
          // Solo procesar si aún no tenemos descripción remota
          RTCSessionDescription? remoteDesc = await _peerConnection?.getRemoteDescription();
          if (remoteDesc == null) {
            logInfo('CallScreen', 'Respuesta SDP recibida');
            
            try {
              await _peerConnection!.setRemoteDescription(RTCSessionDescription(
                answer['sdp'],
                answer['type'],
              ));
              logInfo('CallScreen', 'Descripción remota establecida correctamente');
            } catch (e) {
              logError('CallScreen', 'Error estableciendo descripción remota: $e');
            }
          }
        }
      }
    }, onError: (e) {
      logError('CallScreen', 'Error escuchando respuesta: $e');
    });
  }

  // Manejar error de conexión
  void _handleConnectionFailure() {
    if (!mounted || _isClosing || _navigationInProgress) return;
    
    logInfo('CallScreen', 'Manejando fallo de conexión');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Conexión perdida. Intente nuevamente.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
    
    _hangUp(status: 'error');
  }

  // Manejar error general de llamada
  void _handleCallError() {
    if (!mounted || _isClosing || _navigationInProgress) return;
    
    logInfo('CallScreen', 'Manejando error general de llamada');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error al iniciar la llamada. Intente nuevamente.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
    
    _hangUp(status: 'error');
  }

  // Timer para la duración de la llamada
  void _startDurationTimer() {
    _callDurationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted && _inCalling && !_isClosing) {
        final parts = _callDuration.split(':');
        var minutes = int.parse(parts[0]);
        var seconds = int.parse(parts[1]);
        
        seconds++;
        if (seconds == 60) {
          minutes++;
          seconds = 0;
        }
        
        setState(() {
          _callDuration = '${minutes.toString().padLeft(2,'0')}:${seconds.toString().padLeft(2,'0')}';
        });
      } else {
        timer.cancel();
      }
    });
  }

  // REESCRITO: Método para limpiar y salir de manera segura
  void _cleanupAndPop(String status) {
    if (!mounted || _isClosing || _navigationInProgress) {
      logInfo('CallScreen', '_cleanupAndPop: ya está cerrando o navegando');
      return;
    }
    
    logInfo('CallScreen', 'Iniciando _cleanupAndPop con estado: $status');
    
    // Marcar banderas de estado
    _isClosing = true;
    _navigationInProgress = true;
    
    // Detener todos los timers
    _callDurationTimer?.cancel();
    _reconnectTimer?.cancel();
    _connectionTimeoutTimer?.cancel();
    
    // Cancelar suscripciones
    _callStatusSubscription?.cancel();
    _iceCandidatesSub?.cancel();
    
    // Limpiar recursos multimedia de WebRTC
    _disposeMediaResources();
    
    // Actualizar estado para reflejar que ya no estamos en llamada
    if (mounted) {
      setState(() {
        _inCalling = false;
      });
    }
    
    // Usar un pequeño retraso para asegurar que todo esté limpio antes de navegar
    Future.delayed(Duration(milliseconds: 100), () {
      // Comprobar nuevamente si el widget está montado
      if (mounted) {
        logInfo('CallScreen', 'Navegando fuera de la pantalla de llamada');
        Navigator.of(context).pop();
      }
    });
  }

  // COMPLETAMENTE REESCRITO: Colgar llamada con limpieza mejorada
  Future<void> _hangUp({String status = 'ended'}) async {
    if (!mounted || !_inCalling || _isClosing || _navigationInProgress) {
      logInfo('CallScreen', 'hangUp: condición de salida temprana: mounted=$mounted, inCalling=$_inCalling, isClosing=$_isClosing, navigationInProgress=$_navigationInProgress');
      return;
    }
    
    logInfo('CallScreen', 'Iniciando proceso de colgar llamada con estado: $status');
    
    try {
      // 1. Calcular duración de la llamada
      final callEndTime = DateTime.now().millisecondsSinceEpoch;
      final callDurationSeconds = ((callEndTime - _callStartTime) / 1000).round();
      
      // 2. Actualizar objeto Call con duración
      final updatedCall = Call(
        callerId: widget.call.callerId,
        callerName: widget.call.callerName,
        callerPic: widget.call.callerPic,
        receiverId: widget.call.receiverId,
        receiverName: widget.call.receiverName,
        receiverPic: widget.call.receiverPic,
        callId: widget.call.callId,
        hasDialled: widget.call.hasDialled,
        timestamp: widget.call.timestamp,
        isGroupCall: widget.call.isGroupCall,
        callType: widget.call.callType,
        callStatus: status,
        callTime: callDurationSeconds,
      );
      
      // 3. Marcar la llamada como finalizada en Firestore
      // para que el otro dispositivo sepa que debe colgar
      try {
        await _firestore.collection('calls').doc(widget.channelId).update({
          'status': status,
          'endTimestamp': FieldValue.serverTimestamp(),
          'duration': callDurationSeconds,
        });
        logInfo('CallScreen', 'Estado de llamada actualizado a: $status');
      } catch (e) {
        logError('CallScreen', 'Error actualizando estado de llamada en Firestore: $e');
      }
      
      // 4. Finalizar llamada en el controlador (en un bloque try-catch separado)
      try {
        if (mounted) {
          await ref.read(callControllerProvider).endCall(
            widget.call.callerId,
            widget.call.receiverId,
            context,
            status: status,
          );
          
          // 5. Guardar en historial
          await ref.read(callControllerProvider).saveCallToHistory(
            updatedCall,
            status: status,
          );
        }
      } catch (e) {
        logError('CallScreen', 'Error al finalizar llamada en el controlador: $e');
      }
      
      // 6. IMPORTANTE: Ahora sí, después de que todo el procesamiento Firestore
      // esté completo, limpiar recursos y navegar
      _cleanupAndPop(status);
      
    } catch (e) {
      logError('CallScreen', 'Error general durante _hangUp: $e');
      // Asegurarnos de limpiar y salir incluso si hay error
      _cleanupAndPop(status);
    }
  }

  // Alternar micrófono - MEJORADO
  void _toggleMute() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      
      // Verificar que hay pistas de audio antes de manipularlas
      if (audioTracks.isNotEmpty) {
        // Cambiar estado de todas las pistas de audio
        for (var track in audioTracks) {
          track.enabled = !track.enabled;
          logInfo('CallScreen', 'Pista de audio ${track.id} - Enabled: ${track.enabled}');
        }
        
        // Actualizar estado
        setState(() {
          _isMuted = audioTracks.first.enabled == false;
        });
        
        logInfo('CallScreen', 'Micrófono: ${_isMuted ? 'silenciado' : 'activado'}');
      } else {
        logError('CallScreen', 'No se encontraron pistas de audio para silenciar');
      }
    }
  }

  // Alternar altavoz - MEJORADO
  Future<void> _toggleSpeaker() async {
    try {
      // Cambiar estado
      _isSpeakerOn = !_isSpeakerOn;
      
      // Aplicar cambio usando Helper
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
      
      // Actualizar UI
      setState(() {});
      
      logInfo('CallScreen', 'Altavoz: ${_isSpeakerOn ? 'activado' : 'desactivado'}');
    } catch (e) {
      logError('CallScreen', 'Error cambiando altavoz: $e');
      
      // Revertir cambio en caso de error
      _isSpeakerOn = !_isSpeakerOn;
      setState(() {});
    }
  }

  // Alternar cámara - MEJORADO
  void _toggleVideo() {
    if (widget.call.callType == 'video' && _localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      
      // Verificar que hay pistas de video antes de manipularlas
      if (videoTracks.isNotEmpty) {
        // Cambiar estado de todas las pistas de video
        for (var track in videoTracks) {
          track.enabled = !track.enabled;
          logInfo('CallScreen', 'Pista de video ${track.id} - Enabled: ${track.enabled}');
        }
        
        // Actualizar estado
        setState(() {
          _isVideoEnabled = videoTracks.first.enabled;
        });
        
        logInfo('CallScreen', 'Cámara: ${_isVideoEnabled ? 'activada' : 'desactivada'}');
      } else {
        logError('CallScreen', 'No se encontraron pistas de video para alternar');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_isClosing && !_navigationInProgress) {
          _hangUp();
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Fondo
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1A1F38),
                      Color(0xFF2D3250),
                    ],
                  ),
                ),
              ),
            ),
            
            // VÍDEO REMOTO
            if (widget.call.callType == 'video')
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: RTCVideoView(
                    _remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    mirror: false,
                  ),
                ),
              ),
            
            // Interfaz para llamadas de voz o videollamada sin stream remoto
            if (widget.call.callType != 'video' || !_hasRemoteStream)
              Positioned.fill(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Color(0xFF3E63A8), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF3E63A8).withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          backgroundImage: widget.call.hasDialled
                              ? widget.call.receiverPic.isNotEmpty
                                  ? NetworkImage(widget.call.receiverPic)
                                  : null
                              : widget.call.callerPic.isNotEmpty
                                  ? NetworkImage(widget.call.callerPic)
                                  : null,
                          backgroundColor: Color(0xFF3E63A8),
                          radius: 80,
                          child: (widget.call.hasDialled
                                  ? widget.call.receiverPic.isEmpty
                                  : widget.call.callerPic.isEmpty)
                              ? Text(
                                  widget.call.hasDialled
                                      ? widget.call.receiverName.isNotEmpty
                                          ? widget.call.receiverName[0].toUpperCase()
                                          : '?'
                                      : widget.call.callerName.isNotEmpty
                                          ? widget.call.callerName[0].toUpperCase()
                                          : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 60,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      SizedBox(height: 30),
                      // Nombre
                      Text(
                        widget.call.hasDialled
                            ? widget.call.receiverName
                            : widget.call.callerName,
                        style: const TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 10),
                      // Mostrar estado según conexión
                      Text(
                        widget.call.callType == 'video' ? 'Videollamada' : 'Llamada de voz',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[300],
                        ),
                      ),
                      
                      // Solo mostrar duración si hay conexión
                      if (_isConnected)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _callDuration,
                            style: TextStyle(
                              fontSize: 16, 
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      
                      // Mostrar indicador de conectando si no hay conexión todavía
                      if (!_isConnected && _inCalling && !_isClosing)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Conectando...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            
            // Video local (para videollamadas)
            if (widget.call.callType == 'video')
              Positioned(
                top: 40,
                right: 20,
                width: 120,
                height: 160,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _isVideoEnabled 
                      ? RTCVideoView(
                          _localRenderer, 
                          mirror: true,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : Container(
                          color: Colors.black54,
                          child: Center(
                            child: Icon(
                              Icons.videocam_off,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                  ),
                ),
              ),
            
            // Duración (para videollamadas cuando hay conexión)
            if (widget.call.callType == 'video' && _isConnected)
              Positioned(
                top: 40,
                left: 20,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _callDuration,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            
            // Controles de llamada
            if (!_isClosing) // Solo mostrar controles si no estamos cerrando
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Controles principales
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Botón de micrófono
                        _buildControlButton(
                          icon: _isMuted ? Icons.mic_off : Icons.mic,
                          label: _isMuted ? 'Activar' : 'Silenciar',
                          onPressed: _toggleMute,
                        ),
                        SizedBox(width: 16),
                        // Botón de colgar
                        _buildControlButton(
                          icon: Icons.call_end,
                          backgroundColor: Colors.red,
                          label: 'Colgar',
                          onPressed: () => _hangUp(),
                          large: true,
                        ),
                        SizedBox(width: 16),
                        // Botón de altavoz
                        _buildControlButton(
                          icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                          label: _isSpeakerOn ? 'Altavoz' : 'Auricular',
                          onPressed: _toggleSpeaker,
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Botón de vídeo (solo para videollamadas)
                    if (widget.call.callType == 'video')
                      _buildControlButton(
                        icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                        label: _isVideoEnabled ? 'Apagar cámara' : 'Encender cámara',
                        onPressed: _toggleVideo,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // Widget para botones de control
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color backgroundColor = Colors.grey,
    bool large = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: large ? 70 : 56,
          width: large ? 70 : 56,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withOpacity(0.3),
                blurRadius: 5,
                spreadRadius: 2,
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: large ? 32 : 24),
            onPressed: _isClosing ? null : onPressed, // Deshabilitar botones durante el cierre
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}