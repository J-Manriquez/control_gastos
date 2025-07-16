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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    color: colorProvider.colors.primaryTextColor.withOpacity(0.5),
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay solicitudes pendientes',
                    style: TextStyle(
                      color: colorProvider.colors.primaryTextColor,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            padding: const EdgeInsets.all(8),
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
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 12.0),
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: colorProvider.colors.appBarColor,
                            radius: 25,
                            child: Text(
                              userData['username'][0].toUpperCase(),
                              style: TextStyle(
                                color: colorProvider.colors.secondaryTextColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userData['username'],
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ID: ${userData['userShortId']}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: colorProvider.colors.positiveColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    await _friendsService.respondToFriendRequest(
                                      request.id,
                                      'accepted',
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: colorProvider.colors.negativeColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    await _friendsService.respondToFriendRequest(
                                      request.id,
                                      'rejected',
                                    );
                                  },
                                ),
                              ),
                            ],
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