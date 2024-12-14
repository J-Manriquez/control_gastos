import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/notification_model.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class NotificationMigration {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CustomLogger _logger = CustomLogger();

  Future<void> migrateNotifications() async {
    try {
      _logger.logInfo('Iniciando migración de notificaciones');

      // Obtener todas las notificaciones existentes
      QuerySnapshot notificationsSnapshot = await _firestore
          .collectionGroup('notifications')
          .get();

      for (var doc in notificationsSnapshot.docs) {
        await _firestore.runTransaction((transaction) async {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          // Verificar si la notificación necesita migración
          if (!_isValidNotificationFormat(data)) {
            // Crear nueva estructura de notificación
            Map<String, dynamic> newData = {
              'id': doc.id,
              'title': data['title'] ?? 'Notificación',
              'message': data['message'] ?? '',
              'type': _determineNotificationType(data),
              'sourceId': data['sourceId'] ?? doc.id,
              'senderId': data['senderId'] ?? '',
              'timestamp': data['timestamp'] ?? FieldValue.serverTimestamp(),
              'isRead': data['isRead'] ?? false,
              'additionalData': _createAdditionalData(data),
            };

            // Actualizar documento con nuevo formato
            transaction.set(doc.reference, newData, SetOptions(merge: true));

            _logger.logInfo('Notificación migrada: ${doc.id}');
          }
        });
      }

      _logger.logInfo('Migración de notificaciones completada');
    } catch (e) {
      _logger.logError('Error durante la migración de notificaciones: $e');
      rethrow;
    }
  }

  bool _isValidNotificationFormat(Map<String, dynamic> data) {
    return data.containsKey('id') &&
        data.containsKey('title') &&
        data.containsKey('message') &&
        data.containsKey('type') &&
        data.containsKey('sourceId') &&
        data.containsKey('senderId') &&
        data.containsKey('timestamp') &&
        data.containsKey('isRead') &&
        data.containsKey('additionalData');
  }

  String _determineNotificationType(Map<String, dynamic> data) {
    if (data.containsKey('type')) {
      return data['type'];
    }
    
    // Intentar determinar el tipo basado en datos existentes
    if (data.containsKey('requestId')) {
      return NotificationType.friendRequest.toString();
    } else if (data.containsKey('expenseId')) {
      return NotificationType.sharedExpense.toString();
    } else if (data.containsKey('chatId')) {
      return NotificationType.chat.toString();
    }
    
    return NotificationType.friendRequest.toString(); // Tipo por defecto
  }

  Map<String, dynamic> _createAdditionalData(Map<String, dynamic> data) {
    Map<String, dynamic> additionalData = {};

    // Migrar datos específicos según el tipo
    switch (_determineNotificationType(data)) {
      case 'NotificationType.friendRequest':
        additionalData = {
          'status': data['status'] ?? 'pending',
          'senderUsername': data['senderUsername'] ?? '',
        };
        break;
      case 'NotificationType.sharedExpense':
        additionalData = {
          'status': data['status'] ?? 'pending',
          'expenseName': data['expenseName'] ?? '',
          'total': data['total'] ?? 0,
        };
        break;
      case 'NotificationType.chat':
        additionalData = {
          'chatName': data['chatName'] ?? '',
          'messagePreview': data['messagePreview'] ?? '',
        };
        break;
    }

    return additionalData;
  }
}