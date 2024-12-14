import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/screens/friends/pending_requests_screen.dart';
import 'package:control_gastos/screens/gastos/share_expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/notification_model.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/friends_service.dart';
import 'package:control_gastos/database/singleton_db.dart';

class NotificationsScreen extends StatelessWidget {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FriendsService _friendsService = FriendsService();

  NotificationsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      backgroundColor: colorProvider.colors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Notificaciones',
          style: TextStyle(color: colorProvider.colors.secondaryTextColor),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme: IconThemeData(color: colorProvider.colors.secondaryTextColor),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('usuarios')
            .doc(userId)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar notificaciones',
                style: TextStyle(color: colorProvider.colors.negativeColor),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: colorProvider.colors.appBarColor,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: colorProvider.colors.primaryTextColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay notificaciones',
                    style: TextStyle(
                      color: colorProvider.colors.primaryTextColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final notification = NotificationModel.fromMap(
                snapshot.data!.docs[index].data() as Map<String, dynamic>,
              );
              return _buildNotificationCard(context, notification, colorProvider);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
  BuildContext context,
  NotificationModel notification,
  ColorProvider colorProvider,
) {
  IconData icon;
  Color iconColor;
  Widget? actionButton;

  switch (notification.type) {
    case NotificationType.friendRequest:
      icon = Icons.person_add;
      iconColor = colorProvider.colors.appBarColor;
      if (notification.additionalData?['status'] == 'pending') {
        actionButton = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.check_circle,
                color: colorProvider.colors.positiveColor,
              ),
              onPressed: () => _handleFriendRequest(
                context,
                notification.sourceId,
                'accepted',
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.cancel,
                color: colorProvider.colors.negativeColor,
              ),
              onPressed: () => _handleFriendRequest(
                context,
                notification.sourceId,
                'rejected',
              ),
            ),
          ],
        );
      }
      break;

    case NotificationType.sharedExpense:
      icon = Icons.account_balance_wallet;
      iconColor = colorProvider.colors.appBarColor;
      if (notification.additionalData?['status'] == 'pending') {
        actionButton = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.check_circle,
                color: colorProvider.colors.positiveColor,
              ),
              onPressed: () {
                FirestoreService()
                    .sharedExpenseService
                    .respondToInvitation(
                      notification.sourceId,
                      userId,
                      ParticipantStatus.accepted,
                    );
                _markNotificationAsRead(notification.id);
              },
            ),
            IconButton(
              icon: Icon(
                Icons.cancel,
                color: colorProvider.colors.negativeColor,
              ),
              onPressed: () {
                FirestoreService()
                    .sharedExpenseService
                    .respondToInvitation(
                      notification.sourceId,
                      userId,
                      ParticipantStatus.rejected,
                    );
                _markNotificationAsRead(notification.id);
              },
            ),
          ],
        );
      }
      break;

    case NotificationType.chat:
      icon = Icons.chat;
      iconColor = colorProvider.colors.appBarColor;
      break;
  }

  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    color: notification.isRead
        ? colorProvider.colors.backgroundColor
        : colorProvider.colors.appBarColor.withOpacity(0.1),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.2),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          color: colorProvider.colors.primaryTextColor,
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification.message,
            style: TextStyle(
              color: colorProvider.colors.primaryTextColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(notification.timestamp),
            style: TextStyle(
              color: colorProvider.colors.primaryTextColor.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
          if (notification.type == NotificationType.sharedExpense &&
              notification.additionalData != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Total: \$${notification.additionalData!['total']?.toString() ?? '0'}',
                style: TextStyle(
                  color: colorProvider.colors.primaryTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      trailing: actionButton,
      onTap: () {
        _handleNotificationTap(context, notification);
        if (!notification.isRead) {
          _markNotificationAsRead(notification.id);
        }
      },
    ),
  );
}

// Método auxiliar para formatear la marca de tiempo
String _formatTimestamp(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  if (difference.inDays > 7) {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  } else if (difference.inDays > 0) {
    return 'Hace ${difference.inDays} días';
  } else if (difference.inHours > 0) {
    return 'Hace ${difference.inHours} horas';
  } else if (difference.inMinutes > 0) {
    return 'Hace ${difference.inMinutes} minutos';
  } else {
    return 'Ahora';
  }
}

// Método para marcar una notificación como leída
Future<void> _markNotificationAsRead(String notificationId) async {
  await _firestore
      .collection('usuarios')
      .doc(userId)
      .collection('notifications')
      .doc(notificationId)
      .update({'isRead': true});
}

// Método para manejar el tap en la notificación
void _handleNotificationTap(BuildContext context, NotificationModel notification) {
  switch (notification.type) {
    case NotificationType.friendRequest:
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PendingRequestsScreen(userId: userId),
        ),
      );
      break;
    case NotificationType.sharedExpense:
      // Primero obtener el grupo de gastos
      FirestoreService()
          .sharedExpenseService
          .getSharedExpense(notification.sourceId)
          .first
          .then((group) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShareExpenseScreen(
              userUid: userId,
              existingGroup: group,
            ),
          ),
        );
      });
      break;
    case NotificationType.chat:
      // Implementar navegación al chat cuando esté disponible
      break;
  }
}
  Future<void> _handleFriendRequest(
    BuildContext context,
    String requestId,
    String response,
  ) async {
    try {
      await _friendsService.respondToFriendRequest(requestId, response);
      // Marcar la notificación como leída
      await _markNotificationAsRead(requestId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

}