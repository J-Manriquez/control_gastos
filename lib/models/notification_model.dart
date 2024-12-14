import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  friendRequest,
  sharedExpense,
  chat,
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final String sourceId; // ID de la solicitud de amistad o gasto compartido
  final String senderId;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? additionalData;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.sourceId,
    required this.senderId,
    required this.timestamp,
    this.isRead = false,
    this.additionalData,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.toString(),
      'sourceId': sourceId,
      'senderId': senderId,
      'timestamp': timestamp,
      'isRead': isRead,
      'additionalData': additionalData,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'],
      title: map['title'],
      message: map['message'],
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => NotificationType.friendRequest,
      ),
      sourceId: map['sourceId'],
      senderId: map['senderId'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
      additionalData: map['additionalData'],
    );
  }
}