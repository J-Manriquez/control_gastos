import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/services/friends_service.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:provider/provider.dart';

class PendingRequestsScreen extends StatelessWidget {
  final String userId;
  final FriendsService _friendsService = FriendsService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PendingRequestsScreen({super.key, required this.userId});

  // Método para marcar como leídas todas las notificaciones de solicitud de amistad
  Future<void> _markFriendRequestNotificationsAsRead() async {
    try {
      // Obtener todas las notificaciones de solicitud de amistad no leídas
      final QuerySnapshot notificationsSnapshot = await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('notifications')
          .where('type', isEqualTo: 'friendRequest')
          .where('isRead', isEqualTo: false)
          .get();

      // Actualizar cada notificación como leída
      final batch = _firestore.batch();
      for (var doc in notificationsSnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error al marcar notificaciones como leídas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);
    
    // Marcar notificaciones como leídas al entrar a la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markFriendRequestNotificationsAsRead();
    });

    return Scaffold(
      backgroundColor: colorProvider.colors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Solicitudes Pendientes',
          style: TextStyle(color: colorProvider.colors.secondaryTextColor),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _friendsService.getPendingFriendRequests(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar solicitudes',
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
              child: Text(
                'No hay solicitudes pendientes',
                style: TextStyle(color: colorProvider.colors.primaryTextColor),
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final request = snapshot.data!.docs[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(request['fromUserId'])
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorProvider.colors.appBarColor,
                      child: Text(
                        userData['username'][0].toUpperCase(),
                        style: TextStyle(
                          color: colorProvider.colors.secondaryTextColor,
                        ),
                      ),
                    ),
                    title: Text(
                      userData['username'],
                      style: TextStyle(color: colorProvider.colors.primaryTextColor),
                    ),
                    subtitle: Text(
                      'ID: ${userData['userShortId']}',
                      style: TextStyle(
                        color: colorProvider.colors.primaryTextColor.withOpacity(0.7),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.check,
                            color: colorProvider.colors.positiveColor,
                          ),
                          onPressed: () async {
                            await _friendsService.respondToFriendRequest(
                              request.id,
                              'accepted',
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: colorProvider.colors.negativeColor,
                          ),
                          onPressed: () async {
                            await _friendsService.respondToFriendRequest(
                              request.id,
                              'rejected',
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}