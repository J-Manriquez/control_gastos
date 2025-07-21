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
          style: TextStyle(color: colorProvider.colors.secondaryTextColor, fontSize: 20),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme: IconThemeData(color: colorProvider.colors.secondaryTextColor),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _friendsService.getPendingFriendRequests(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: colorProvider.colors.negativeColor,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar solicitudes',
                    style: TextStyle(
                      color: colorProvider.colors.negativeColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
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
                    Icons.people_outline,
                    color: colorProvider.colors.primaryTextColor.withOpacity(0.5),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay solicitudes pendientes',
                    style: TextStyle(
                      color: colorProvider.colors.primaryTextColor.withOpacity(0.7),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(left: 0, right: 0, top: 8, bottom: 80),
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
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0, left: 12, right: 12),
                    color: colorProvider.colors.backgroundColor,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: colorProvider.colors.appBarColor,
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: colorProvider.colors.appBarColor,
                        radius: 24,
                        child: Text(
                          userData['username'][0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      title: Text(
                        userData['username'],
                        style: TextStyle(
                          color: colorProvider.colors.primaryTextColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        'ID: ${userData['userShortId']}',
                        style: TextStyle(
                          color: colorProvider.colors.primaryTextColor.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () async {
                              await _friendsService.respondToFriendRequest(
                                request.id,
                                'accepted',
                              );
                            },
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
                          ),
                          IconButton(
                            onPressed: () async {
                              await _friendsService.respondToFriendRequest(
                                request.id,
                                'rejected',
                              );
                            },
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
                          ),
                        ],
                      ),
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