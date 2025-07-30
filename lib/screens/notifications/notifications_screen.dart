import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/screens/friends/pending_requests_screen.dart';
import 'package:control_gastos/screens/shared_expenses/share_expense_options_screen.dart';
import 'package:control_gastos/screens/shared_expenses/shared_edicion_gastos.dart';
import 'package:control_gastos/widgets/access_control_wrapper.dart';
import 'package:control_gastos/screens/gastos/gastos_screen.dart';
import 'package:control_gastos/screens/version_details_screen.dart';
import 'package:control_gastos/widgets/expense_details_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/notification_model.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/friends_service.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/widgets/loading_screen.dart';

class NotificationsScreen extends StatelessWidget {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FriendsService _friendsService = FriendsService();

  NotificationsScreen({super.key, required this.userId});

  // método para eliminar todas las notificaciones
  Future<void> _deleteAllNotifications(BuildContext context) async {
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);

    try {
      // Mostrar diálogo de confirmación
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: colorProvider.colors.backgroundColor,
            title: Text(
              '¿Eliminar todas las notificaciones?',
              style: TextStyle(color: colorProvider.colors.primaryTextColor),
            ),
            content: Text(
              'Esta acción no se puede deshacer',
              style: TextStyle(color: colorProvider.colors.primaryTextColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: colorProvider.colors.appBarColor),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Eliminar',
                  style: TextStyle(color: colorProvider.colors.negativeColor),
                ),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        // Mostrar indicador de progreso
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return Center(
                child: CircularProgressIndicator(
                  color: colorProvider.colors.appBarColor,
                ),
              );
            },
          );
        }

        // Obtener todas las notificaciones
        final notifications = await _firestore
            .collection('usuarios')
            .doc(userId)
            .collection('notifications')
            .get();

        // Eliminar cada notificación
        for (var doc in notifications.docs) {
          await doc.reference.delete();
        }

        // Cerrar el indicador de progreso
        if (context.mounted) {
          Navigator.of(context).pop();

          // Mostrar mensaje de éxito
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Todas las notificaciones han sido eliminadas',
                style:
                    TextStyle(color: colorProvider.colors.secondaryTextColor),
              ),
              backgroundColor: colorProvider.colors.positiveColor,
            ),
          );
        }
      }
    } catch (e) {
      // Cerrar el indicador de progreso si está visible
      if (context.mounted) {
        Navigator.of(context).pop();

        // Mostrar mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al eliminar las notificaciones: $e',
              style: TextStyle(color: colorProvider.colors.secondaryTextColor),
            ),
            backgroundColor: colorProvider.colors.negativeColor,
          ),
        );
      }
    }
  }

  // Método para manejar las notificaciones de cambios de versión
  Future<void> _handleVersionChangeNotification(
      BuildContext context,
      NotificationModel notification,
      Map<String, dynamic> additionalData) async {
    try {
      final String expenseId = notification.sourceId;
      final String version = additionalData['version'] ?? '';
      final String status = additionalData['status'] ?? '';

      if (status == 'pending') {
        // Navegar a la pantalla de detalles de versión para votar
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VersionDetailsScreen(
              expenseId: expenseId,
              version: version,
              currentUserId: userId, // Usar userId en lugar de widget.userId
            ),
          ),
        );
      } else {
        // Para estados 'applied' o 'rejected', mostrar información
        final expense = await FirestoreService()
            .sharedExpenseService
            .getSharedExpense(expenseId);

        if (context.mounted) {
          String dialogTitle =
              status == 'applied' ? 'Cambios Aplicados' : 'Cambios Rechazados';
          String dialogMessage = status == 'applied'
              ? 'Los cambios propuestos han sido aprobados y aplicados al gasto.'
              : 'Los cambios propuestos han sido rechazados.';

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(dialogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(dialogMessage),
                  if (expense != null) ...[
                    SizedBox(height: 16),
                    ExpenseDetailsWidget(group: expense, expense: expense),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cerrar'),
                ),
                if (status == 'applied')
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SharedEditGroupScreen(
                            groupId: expenseId,
                            userUid: userId,
                            participantIds: expense?.participants
                                    .map((p) => p.userId)
                                    .toList() ??
                                [],
                          ),
                        ),
                      );
                    },
                    child: Text('Ver Gasto'),
                  ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Error al manejar notificación de cambio de versión: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      backgroundColor: colorProvider.colors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Notificaciones',
          style: TextStyle(
              color: colorProvider.colors.secondaryTextColor, fontSize: 20),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme: IconThemeData(
          color: colorProvider.colors.secondaryTextColor,
          size: 30,
        ),
        // botón para eliminar todas las notificaciones
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('usuarios')
                .doc(userId)
                .collection('notifications')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Eliminar todas las notificaciones',
                onPressed: () => _deleteAllNotifications(context),
              );
            },
          ),
        ],
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error,
                    size: 80,
                    color:
                        colorProvider.colors.primaryTextColor.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar notificaciones',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorProvider.colors.primaryTextColor
                          .withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  colorProvider.colors.appBarColor,
                ),
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
                    size: 80,
                    color:
                        colorProvider.colors.primaryTextColor.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes notificaciones',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorProvider.colors.primaryTextColor
                          .withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            padding:
                const EdgeInsets.only(left: 0, right: 0, top: 8, bottom: 8),
            itemBuilder: (context, index) {
              final notification = NotificationModel.fromMap(
                snapshot.data!.docs[index].data() as Map<String, dynamic>,
              );
              return _buildNotificationCard(
                  context, notification, colorProvider);
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

    // Verificar si es una notificación de cambio de versión
    final isVersionChange =
        notification.additionalData?.containsKey('version') ?? false;

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
                  size: 40,
                ),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
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
                  size: 40,
                ),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
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
        // Solo mostrar botones de acción si NO es un cambio de versión y está pendiente
        if (!isVersionChange &&
            notification.additionalData?['status'] == 'pending') {
          actionButton = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.check_circle,
                  color: colorProvider.colors.positiveColor,
                  size: 28,
                ),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                onPressed: () => _handleSharedExpenseResponse(
                  context,
                  notification.sourceId,
                  ParticipantStatus.accepted,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.cancel,
                  color: colorProvider.colors.negativeColor,
                  size: 28,
                ),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                onPressed: () => _handleSharedExpenseResponse(
                  context,
                  notification.sourceId,
                  ParticipantStatus.rejected,
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
      margin: const EdgeInsets.only(bottom: 12.0, left: 12, right: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: notification.isRead
              ? colorProvider.colors.appBarColor
              : colorProvider.colors.negativeColor,
          width: 1.5,
        ),
      ),
      color: notification.isRead
          ? colorProvider.colors.backgroundColor
          : Colors.white70,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: iconColor.withOpacity(0.15),
          child: Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            color: colorProvider.colors.primaryTextColor,
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
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
                notification.additionalData != null &&
                !isVersionChange)
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

  void _handleNotificationTap(
    BuildContext context,
    NotificationModel notification,
  ) async {
    // Marcar como leída
    await _markNotificationAsRead(notification.id);

    // Obtener datos adicionales
    final additionalData = notification.additionalData ?? {};
    final status = additionalData['status'] ?? '';
    // Verificar si es una notificación de cambio de versión
    if (additionalData.containsKey('version')) {
      await _handleVersionChangeNotification(
          context, notification, additionalData);
      return;
    }
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
        try {
          final sharedExpense = await FirestoreService()
              .sharedExpenseService
              .getSharedExpense(notification.sourceId);

          if (context.mounted) {
            // En lugar de navegar a la pantalla de edición, mostrar un diálogo con los detalles
            showDialog(
              context: context,
              builder: (BuildContext context) {
                final colorProvider = Provider.of<ColorProvider>(context);
                return Dialog(
                  backgroundColor: colorProvider.colors.backgroundColor,
                  child: Container(
                    width: double.maxFinite,
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Encabezado del diálogo
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          color: colorProvider.colors.appBarColor,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  sharedExpense.nombre,
                                  style: TextStyle(
                                    color:
                                        colorProvider.colors.secondaryTextColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color:
                                      colorProvider.colors.secondaryTextColor,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                        // Contenido del diálogo con scroll
                        Flexible(
                          child: SingleChildScrollView(
                            child: ExpenseDetailsWidget(
                                group: sharedExpense, expense: sharedExpense),
                          ),
                        ),
                        // Botones de acción si la notificación está pendiente
                        if (notification.additionalData?['status'] == 'pending')
                          Container(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  icon: Icon(Icons.check_circle),
                                  label: Text('Aceptar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        colorProvider.colors.positiveColor,
                                    foregroundColor:
                                        colorProvider.colors.secondaryTextColor,
                                  ),
                                  onPressed: () async {
                                    // Cerrar el modal primero
                                    Navigator.of(context).pop();
                                    
                                    // Manejar la respuesta con UI completa
                                    await _handleSharedExpenseResponseWithUI(
                                      context,
                                      notification.sourceId,
                                      ParticipantStatus.accepted,
                                    );
                                  },
                                ),
                                ElevatedButton.icon(
                                  icon: Icon(Icons.cancel),
                                  label: Text('Rechazar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        colorProvider.colors.negativeColor,
                                    foregroundColor:
                                        colorProvider.colors.secondaryTextColor,
                                  ),
                                  onPressed: () async {
                                    // Cerrar el modal primero
                                    Navigator.of(context).pop();
                                    
                                    // Manejar la respuesta con UI completa
                                    await _handleSharedExpenseResponseWithUI(
                                      context,
                                      notification.sourceId,
                                      ParticipantStatus.rejected,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        // Botón para editar si ya está aceptado
                        if (notification.additionalData?['status'] != 'pending')
                          Container(
                            padding: const EdgeInsets.all(16.0),
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.edit),
                              label: Text('Editar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    colorProvider.colors.appBarColor,
                                foregroundColor:
                                    colorProvider.colors.secondaryTextColor,
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SharedEditGroupScreen(
                                      userUid: userId,
                                      groupId: notification.sourceId,
                                      participantIds: sharedExpense.participants
                                          .map((p) => p.userId)
                                          .toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al cargar el gasto compartido: $e'),
                backgroundColor:
                    Provider.of<ColorProvider>(context, listen: false)
                        .colors
                        .negativeColor,
              ),
            );
          }
        }
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
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);

    // Mostrar diálogo de carga modal apropiado
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => Dialog(
        backgroundColor: colorProvider.colors.backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_add,
                size: 48,
                color: colorProvider.colors.appBarColor,
              ),
              const SizedBox(height: 16),
              Text(
                response == 'accepted' 
                    ? 'Aceptando solicitud de amistad...'
                    : 'Rechazando solicitud de amistad...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorProvider.colors.primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Procesando tu respuesta',
                style: TextStyle(
                  fontSize: 14,
                  color: colorProvider.colors.primaryTextColor.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  colorProvider.colors.appBarColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Primero respondemos a la solicitud de amistad
      await _friendsService.respondToFriendRequest(requestId, response);

      // Luego buscamos y eliminamos la notificación relacionada
      final notificationsRef = _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('notifications')
          .where('sourceId', isEqualTo: requestId);

      final notifications = await notificationsRef.get();

      // Eliminamos todas las notificaciones relacionadas con esta solicitud
      for (var doc in notifications.docs) {
        await doc.reference.delete().catchError((error) {
          // Si hay error al eliminar, lo registramos pero no interrumpimos el flujo
          print('Error al eliminar notificación: $error');
        });
      }

      // Cerrar el diálogo de carga de forma segura
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // Mostrar mensaje de éxito
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response == 'accepted'
                ? 'Solicitud de amistad aceptada'
                : 'Solicitud de amistad rechazada'),
            backgroundColor: colorProvider.colors.positiveColor,
          ),
        );
      }
      
    } catch (e) {
      // Cerrar el diálogo de carga en caso de error
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: colorProvider.colors.negativeColor,
          ),
        );
      }
    }
  }

  // Future<void> _handleSharedExpenseResponse(
  //     String expenseId, bool accept) async {
  //   try {
  //     await FirestoreService().sharedExpenseService.respondToInvitation(
  //           expenseId,
  //           userId,
  //           accept ? ParticipantStatus.accepted : ParticipantStatus.rejected,
  //         );
  //   } catch (e) {
  //     print('Error al responder a invitación: $e');
  //   }
  // }

  Future<void> _handleSharedExpenseResponse(
    BuildContext context,
    String expenseId,
    ParticipantStatus status,
  ) async {
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);

    // Mostrar diálogo de carga modal apropiado
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => Dialog(
        backgroundColor: colorProvider.colors.backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_active,
                size: 48,
                color: colorProvider.colors.appBarColor,
              ),
              const SizedBox(height: 16),
              Text(
                status == ParticipantStatus.accepted
                    ? 'Aceptando gasto compartido...'
                    : 'Rechazando gasto compartido...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorProvider.colors.primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Procesando tu respuesta',
                style: TextStyle(
                  fontSize: 14,
                  color: colorProvider.colors.primaryTextColor.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  colorProvider.colors.appBarColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Responder a la invitación
      await FirestoreService()
          .sharedExpenseService
          .respondToInvitation(expenseId, userId, status);

      // Cerrar el diálogo de carga de forma segura
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Mostrar mensaje de éxito
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == ParticipantStatus.accepted
                  ? 'Gasto compartido aceptado'
                  : 'Gasto compartido rechazado',
            ),
            backgroundColor: status == ParticipantStatus.accepted
                ? colorProvider.colors.positiveColor
                : colorProvider.colors.negativeColor,
          ),
        );
      }
      
    } catch (e) {
      // Cerrar el diálogo de carga en caso de error
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: colorProvider.colors.negativeColor,
          ),
        );
      }
    }
  }

  // Método específico para manejar respuestas desde el modal
  Future<void> _handleSharedExpenseResponseFromModal(
    String expenseId,
    ParticipantStatus status,
  ) async {
    // Este método necesita ser llamado desde un contexto válido
    // Por ahora, simplemente procesamos la respuesta sin UI
    try {
      await FirestoreService()
          .sharedExpenseService
          .respondToInvitation(expenseId, userId, status);
    } catch (e) {
      print('Error al responder a invitación: $e');
    }
  }

  // Método para manejar respuestas con UI completa (sin pantalla de carga)
  Future<void> _handleSharedExpenseResponseWithUI(
    BuildContext context,
    String expenseId,
    ParticipantStatus status,
  ) async {
    try {
      // Responder a la invitación directamente sin mostrar pantalla de carga
      await FirestoreService()
          .sharedExpenseService
          .respondToInvitation(expenseId, userId, status);

      print('Gasto compartido ${status == ParticipantStatus.accepted ? "aceptado" : "rechazado"} exitosamente');
      
      // Navegar inmediatamente a la pantalla principal
      try {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => AccessControlWrapper(
              userUid: userId,
              child: ExpenseGroupsScreen(userUid: userId),
            ),
          ),
          (route) => false,
        );
      } catch (navError) {
        print('Error de navegación: $navError');
      }
      
    } catch (e) {
      print('Error al responder a invitación: $e');
    }
  }
}
