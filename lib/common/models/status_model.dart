import 'dart:convert';

enum MediaType {
  image,
  video
}

class StatusMedia {
  final String url;
  final MediaType type;
  final String caption;
  final DateTime timestamp;

  StatusMedia({
    required this.url,
    required this.type,
    required this.caption,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'type': type.toString().split('.').last,
      'caption': caption,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory StatusMedia.fromMap(Map<String, dynamic> map) {
    return StatusMedia(
      url: map['url'] ?? '',
      type: map['type'] == 'video' ? MediaType.video : MediaType.image,
      caption: map['caption'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
    );
  }
}

class Status {
  final String uid;
  final String username;
  final String phoneNumber;
  final List<StatusMedia> media;
  final List<String> whoCanSee;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String profilePic;
  final String statusId;
  final List<dynamic> viewers; // Lista de quien ha visto el estado
  final DateTime expiryTime; // Cuando expira el estado

  Status({
    required this.uid,
    required this.username,
    required this.phoneNumber,
    required this.media,
    required this.whoCanSee,
    required this.createdAt,
    required this.updatedAt,
    required this.profilePic,
    required this.statusId,
    this.viewers = const [],
    DateTime? expiryTime,
  }) : expiryTime = expiryTime ?? DateTime.now().add(const Duration(hours: 24));

  // Getter para obtener el último medio
  StatusMedia get lastMedia => media.isNotEmpty ? media.last : StatusMedia(
    url: '',
    type: MediaType.image,
    caption: '',
    timestamp: DateTime.now(),
  );
  
  // Getter para la miniatura que se mostrará en la lista
  String get thumbnailUrl => media.isNotEmpty ? media.last.url : '';
  
  // Getter para saber si el último medio es un video
  bool get isLastVideo => media.isNotEmpty && media.last.type == MediaType.video;

  // Getter para saber si el estado ha expirado
  bool get isExpired => DateTime.now().isAfter(expiryTime);

  // Getter para obtener el número de vistas
  int get viewCount => viewers.length;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'phoneNumber': phoneNumber,
      'media': media.map((m) => m.toMap()).toList(),
      'whoCanSee': whoCanSee,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'profilePic': profilePic,
      'statusId': statusId,
      'viewers': viewers,
      'expiryTime': expiryTime.millisecondsSinceEpoch,
    };
  }

  factory Status.fromMap(Map<String, dynamic> map) {
    List<StatusMedia> mediaList = [];
    
    // Intentar cargar medios del nuevo formato
    if (map['media'] != null) {
      mediaList = List<StatusMedia>.from(
        (map['media'] as List).map((m) => StatusMedia.fromMap(m))
      );
    } 
    // Compatibilidad con el modelo anterior
    else if (map['photoUrls'] != null) {
      mediaList = List<String>.from(map['photoUrls'])
          .map((url) => StatusMedia(
                url: url,
                type: MediaType.image,
                caption: map['caption'] ?? '',
                timestamp: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
              ))
          .toList();
    }
    
    return Status(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      media: mediaList,
      whoCanSee: List<String>.from(map['whoCanSee'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? map['createdAt'] ?? 0),
      profilePic: map['profilePic'] ?? '',
      statusId: map['statusId'] ?? '',
      viewers: map['viewers'] ?? [],
      expiryTime: map['expiryTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['expiryTime']) 
          : DateTime.now().add(const Duration(hours: 24)),
    );
  }

  String toJson() => json.encode(toMap());

  factory Status.fromJson(String source) => Status.fromMap(json.decode(source));
}