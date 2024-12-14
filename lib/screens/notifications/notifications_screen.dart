import 'package:control_gastos/models/shared_expense_models.dart';
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

  NotificationsScreen({Key? key, required this.userId}) : super(key: key);

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
                onPressed: () => _handleSharedExpense(
                  context,
                  notification.sourceId,
                  true,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.cancel,
                  color: colorProvider.colors.negativeColor,
                ),
                onPressed: () => _handleSharedExpense(
                  context,
                  notification.sourceId,
                  false,
                ),
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
            Text(
              _formatTimestamp(notification.timestamp),
              style: TextStyle(
                color: colorProvider.colors.primaryTextColor.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: actionButton,
        onTap: () => _handleNotificationTap(context, notification),
      ),
    );
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

  Future<void> _handleSharedExpense(
    BuildContext context,
    String expenseId,
    bool accept,
  ) async {
    try {
      if (accept) {
        await FirestoreService().sharedExpenseService.respondToInvitation(
          expenseId,
          userId,
          ParticipantStatus.accepted,
        );
      } else {
        await FirestoreService().sharedExpenseService.respondToInvitation(
          expenseId,
          userId,
          ParticipantStatus.rejected,
        );
      }
      // Marcar la notificación como leída
      await _markNotificationAsRead(expenseId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    await _firestore
        .collection('usuarios')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  void _handleNotificationTap(BuildContext context, NotificationModel notification) {
    // Navegar según el tipo de notificación
    switch (notification.type) {
      case NotificationType.friendRequest:
        // Navegar a la pantalla de amigos
        Navigator.pushNamed(context, '/friends');
        break;
      case NotificationType.sharedExpense:
        // Navegar al gasto compartido
        Navigator.pushNamed(
          context,
          '/shared_expense',
          arguments: notification.sourceId,
        );
        break;
      case NotificationType.chat:
        // Navegar al chat
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: notification.sourceId,
        );
        break;
    }
  }

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
}