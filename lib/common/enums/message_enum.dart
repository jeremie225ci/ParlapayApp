// lib/common/enums/message_enum.dart

// Asegúrate de que este archivo tenga todas las constantes necesarias
enum MessageEnum {
  text('text'),
  image('image'),
  audio('audio'),
  video('video'),
  gif('gif'),
  money('money'),
  eventNotification('eventNotification'),     // Adaptado al formato del enum con constructor
  eventContribution('eventContribution'),     // Adaptado al formato del enum con constructor
  eventCompleted('eventCompleted'),           // Adaptado al formato del enum con constructor
  marketplaceNotification('marketplaceNotification'); // Adaptado al formato del enum con constructor

  final String type;
  const MessageEnum(this.type);
}

extension ConvertMessage on String {
  MessageEnum toEnum() {
    switch (this) {
      case 'text':
        return MessageEnum.text;
      case 'image':
        return MessageEnum.image;
      case 'audio':
        return MessageEnum.audio;
      case 'video':
        return MessageEnum.video;
      case 'gif':
        return MessageEnum.gif;
      case 'money':
        return MessageEnum.money;
      case 'eventNotification':
        return MessageEnum.eventNotification;
      case 'eventContribution':
        return MessageEnum.eventContribution;
      case 'eventCompleted':
        return MessageEnum.eventCompleted;
      case 'marketplaceNotification':
        return MessageEnum.marketplaceNotification;
      // Mantener compatibilidad con los valores anteriores
      case 'event_notification':
        return MessageEnum.eventNotification;
      case 'event_contribution':
        return MessageEnum.eventContribution;
      case 'event_completed':
        return MessageEnum.eventCompleted;
      case 'marketplace_notification':
        return MessageEnum.marketplaceNotification;
      default:
        return MessageEnum.text;
    }
  }
}