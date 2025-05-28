import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/friend_request_model.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class FriendsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CustomLogger _logger = CustomLogger();

  // Enviar solicitud de amistad
  Future<void> sendFriendRequest(String fromUserId, String toShortId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Buscar usuario por shortId
        QuerySnapshot userQuery = await _firestore
            .collection('usuarios')
            .where('userShortId', isEqualTo: toShortId.toLowerCase())
            .get();

        if (userQuery.docs.isEmpty) {
          throw Exception('Usuario no encontrado');
        }

        String toUserId = userQuery.docs.first.id;

        // 2. Verificar que no son ya amigos y no hay solicitudes pendientes
        DocumentSnapshot fromUserDoc = await transaction
            .get(_firestore.collection('usuarios').doc(fromUserId));

        Map<String, dynamic>? fromUserData =
            fromUserDoc.data() as Map<String, dynamic>?;

        if (fromUserData?['friendsList']?['accepted']?.contains(toUserId) ??
            false) {
          throw Exception('Ya son amigos');
        }

        // 3. Verificar solicitudes pendientes existentes
        QuerySnapshot existingRequests = await _firestore
            .collection('friendRequests')
            .where('status', isEqualTo: 'pending')
            .where(Filter.or(
              Filter.and(
                Filter('fromUserId', isEqualTo: fromUserId),
                Filter('toUserId', isEqualTo: toUserId),
              ),
              Filter.and(
                Filter('fromUserId', isEqualTo: toUserId),
                Filter('toUserId', isEqualTo: fromUserId),
              ),
            ))
            .get();

        if (existingRequests.docs.isNotEmpty) {
          throw Exception('Ya existe una solicitud pendiente');
        }

        // 4. Crear la solicitud
        DocumentReference requestRef =
            _firestore.collection('friendRequests').doc();

        transaction.set(requestRef, {
          'requestId': requestRef.id,
          'fromUserId': fromUserId,
          'toUserId': toUserId,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Después de crear la solicitud, crear la notificación
        DocumentReference notificationRef = _firestore
            .collection('usuarios')
            .doc(toUserId)
            .collection('notifications')
            .doc();

        transaction.set(notificationRef, {
          'id': notificationRef.id,
          'title': 'Nueva solicitud de amistad',
          'message': '${fromUserData?['username']} quiere ser tu amigo',
          'type': 'friendRequest',
          'sourceId': requestRef.id, // ID de la solicitud de amistad
          'senderId': fromUserId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'additionalData': {
            'status': 'pending',
            'senderUsername': fromUserData?['username'],
          }
        });

        _logger.logInfo(
            'Solicitud de amistad y notificación enviadas exitosamente');

        // 5. Actualizar las listas de solicitudes pendientes de ambos usuarios
        transaction.update(_firestore.collection('usuarios').doc(fromUserId), {
          'friendsList.pending': FieldValue.arrayUnion([toUserId])
        });

        transaction.update(_firestore.collection('usuarios').doc(toUserId), {
          'friendsList.pending': FieldValue.arrayUnion([fromUserId])
        });
      });

      _logger.logInfo('Solicitud de amistad enviada exitosamente');
    } catch (e) {
      _logger.logError('Error al enviar solicitud de amistad: $e');
      rethrow;
    }
  }

  // Obtener solicitudes pendientes
  Stream<QuerySnapshot> getPendingFriendRequests(String userId) {
    return _firestore
        .collection('friendRequests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Obtener solicitudes enviadas pendientes
  Stream<QuerySnapshot> getSentPendingRequests(String userId) {
    return _firestore
        .collection('friendRequests')
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Responder a una solicitud de amistad
  Future<void> respondToFriendRequest(String requestId, String response) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot requestDoc = await transaction
            .get(_firestore.collection('friendRequests').doc(requestId));

        if (!requestDoc.exists) {
          throw Exception('Solicitud no encontrada');
        }

        Map<String, dynamic> requestData =
            requestDoc.data() as Map<String, dynamic>;

        if (requestData['status'] != 'pending') {
          throw Exception('La solicitud ya no está pendiente');
        }

        String fromUserId = requestData['fromUserId'];
        String toUserId = requestData['toUserId'];

        // Actualizar el estado de la solicitud
        transaction.update(
            _firestore.collection('friendRequests').doc(requestId),
            {'status': response});

        if (response == 'accepted') {
          // Actualizar listas de amigos de ambos usuarios
          transaction
              .update(_firestore.collection('usuarios').doc(fromUserId), {
            'friendsList.accepted': FieldValue.arrayUnion([toUserId]),
            'friendsList.pending': FieldValue.arrayRemove([toUserId])
          });

          transaction.update(_firestore.collection('usuarios').doc(toUserId), {
            'friendsList.accepted': FieldValue.arrayUnion([fromUserId]),
            'friendsList.pending': FieldValue.arrayRemove([fromUserId])
          });

          // Crear notificación para el remitente
          DocumentReference notificationRef = _firestore
              .collection('usuarios')
              .doc(fromUserId)
              .collection('notifications')
              .doc();

          transaction.set(notificationRef, {
            'id': notificationRef.id,
            'title': 'Solicitud de amistad aceptada',
            'message': 'Tu solicitud de amistad ha sido aceptada',
            'type': 'friendRequest',
            'sourceId': requestId,
            'senderId': toUserId,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'additionalData': {'status': 'accepted'}
          });
          
          // NUEVO: Actualizar la notificación original en el receptor
          // Buscar la notificación original relacionada con esta solicitud
          QuerySnapshot originalNotifications = await _firestore
              .collection('usuarios')
              .doc(toUserId)
              .collection('notifications')
              .where('sourceId', isEqualTo: requestId)
              .limit(1)
              .get();
          
          // Si existe, actualizar su estado
          if (originalNotifications.docs.isNotEmpty) {
            transaction.update(
              originalNotifications.docs.first.reference, 
              {
                'additionalData.status': response,
                'isRead': true // Marcar como leída también
              }
            );
          }
        } else {
          // Si se rechaza, solo remover de pendientes
          transaction
              .update(_firestore.collection('usuarios').doc(fromUserId), {
            'friendsList.pending': FieldValue.arrayRemove([toUserId])
          });

          transaction.update(_firestore.collection('usuarios').doc(toUserId), {
            'friendsList.pending': FieldValue.arrayRemove([fromUserId])
          });
          
          // NUEVO: Actualizar la notificación original en el receptor
          QuerySnapshot originalNotifications = await _firestore
              .collection('usuarios')
              .doc(toUserId)
              .collection('notifications')
              .where('sourceId', isEqualTo: requestId)
              .limit(1)
              .get();
          
          if (originalNotifications.docs.isNotEmpty) {
            transaction.update(
              originalNotifications.docs.first.reference, 
              {
                'additionalData.status': response,
                'isRead': true // Marcar como leída también
              }
            );
          }
        }
      });

      _logger.logInfo('Solicitud de amistad procesada: $response');
    } catch (e) {
      _logger.logError('Error al procesar solicitud de amistad: $e');
      rethrow;
    }
  }

  // Obtener lista de amigos
  Stream<List<DocumentSnapshot>> getFriendsList(String userId) {
    return _firestore
        .collection('usuarios')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      if (!userDoc.exists || !userDoc.data()!.containsKey('friendsList')) {
        return [];
      }

      List<String> friendIds =
          List<String>.from(userDoc.data()!['friendsList']['accepted'] ?? []);

      if (friendIds.isEmpty) {
        return [];
      }

      List<DocumentSnapshot> friendDocs = await Future.wait(
        friendIds.map((friendId) =>
            _firestore.collection('usuarios').doc(friendId).get()),
      );

      return friendDocs.where((doc) => doc.exists).toList();
    });
  }

  // Bloquear usuario
  Future<void> blockUser(String userId, String userToBlockId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Actualizar listas del usuario que bloquea
        transaction.update(_firestore.collection('usuarios').doc(userId), {
          'friendsList.blocked': FieldValue.arrayUnion([userToBlockId]),
          'friendsList.accepted': FieldValue.arrayRemove([userToBlockId]),
          'friendsList.pending': FieldValue.arrayRemove([userToBlockId])
        });

        // Actualizar listas del usuario bloqueado
        transaction
            .update(_firestore.collection('usuarios').doc(userToBlockId), {
          'friendsList.accepted': FieldValue.arrayRemove([userId]),
          'friendsList.pending': FieldValue.arrayRemove([userId])
        });

        // Cancelar solicitudes pendientes
        QuerySnapshot pendingRequests = await _firestore
            .collection('friendRequests')
            .where('status', isEqualTo: 'pending')
            .where(Filter.or(
              Filter.and(
                Filter('fromUserId', isEqualTo: userId),
                Filter('toUserId', isEqualTo: userToBlockId),
              ),
              Filter.and(
                Filter('fromUserId', isEqualTo: userToBlockId),
                Filter('toUserId', isEqualTo: userId),
              ),
            ))
            .get();

        for (var doc in pendingRequests.docs) {
          transaction.update(doc.reference, {'status': 'cancelled'});
        }
      });

      _logger.logInfo('Usuario bloqueado exitosamente');
    } catch (e) {
      _logger.logError('Error al bloquear usuario: $e');
      rethrow;
    }
  }

  // Desbloquear usuario
  Future<void> unblockUser(String userId, String blockedUserId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Actualizar el documento del usuario que desbloquea
        await _firestore.collection('usuarios').doc(userId).update({
          'friendsList.blocked': FieldValue.arrayRemove([blockedUserId])
        });

        // Limpiar cualquier solicitud anterior entre estos usuarios
        await _firestore
            .collection('friendRequests')
            .where(Filter.or(
              Filter.and(
                Filter('fromUserId', isEqualTo: userId),
                Filter('toUserId', isEqualTo: blockedUserId),
              ),
              Filter.and(
                Filter('fromUserId', isEqualTo: blockedUserId),
                Filter('toUserId', isEqualTo: userId),
              ),
            ))
            .get()
            .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.delete();
          }
        });

        _logger.logInfo('Usuario desbloqueado exitosamente');
      });
    } catch (e) {
      _logger.logError('Error al desbloquear usuario: $e');
      rethrow;
    }
  }

  Future<void> removeFriend(String userId, String friendId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Eliminar de la lista de amigos del usuario actual
        transaction.update(_firestore.collection('usuarios').doc(userId), {
          'friendsList.accepted': FieldValue.arrayRemove([friendId])
        });

        // Eliminar de la lista de amigos del otro usuario
        transaction.update(_firestore.collection('usuarios').doc(friendId), {
          'friendsList.accepted': FieldValue.arrayRemove([userId])
        });

        // Eliminar cualquier solicitud existente entre los usuarios
        QuerySnapshot requests = await _firestore
            .collection('friendRequests')
            .where(Filter.or(
              Filter.and(
                Filter('fromUserId', isEqualTo: userId),
                Filter('toUserId', isEqualTo: friendId),
              ),
              Filter.and(
                Filter('fromUserId', isEqualTo: friendId),
                Filter('toUserId', isEqualTo: userId),
              ),
            ))
            .get();

        for (var doc in requests.docs) {
          transaction.delete(doc.reference);
        }
      });

      _logger.logInfo('Amigo eliminado exitosamente');
    } catch (e) {
      _logger.logError('Error al eliminar amigo: $e');
      rethrow;
    }
  }

  // Obtener usuarios bloqueados
  Stream<QuerySnapshot> getBlockedUsers(String userId) {
    return _firestore
        .collection('usuarios')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      if (!userDoc.exists) {
        throw Exception('Usuario no encontrado');
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      List<String> blockedIds = List<String>.from(
          (userData['friendsList']?['blocked'] ?? []) as List<dynamic>);

      if (blockedIds.isEmpty) {
        // Retornar un QuerySnapshot vacío pero válido
        return await _firestore
            .collection('usuarios')
            .where('userShortId', isEqualTo: 'NO_USERS')
            .get();
      }

      return await _firestore
          .collection('usuarios')
          .where(FieldPath.documentId, whereIn: blockedIds)
          .get();
    });
  }

  // Cancelar solicitud de amistad
  Future<void> cancelFriendRequest(String requestId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot request = await transaction
            .get(_firestore.collection('friendRequests').doc(requestId));

        if (!request.exists) {
          throw Exception('Solicitud no encontrada');
        }

        Map<String, dynamic> requestData =
            request.data() as Map<String, dynamic>;

        // Actualizar estado de la solicitud
        transaction.update(request.reference, {'status': 'cancelled'});

        // Remover de las listas pendientes
        transaction.update(
            _firestore.collection('usuarios').doc(requestData['fromUserId']), {
          'friendsList.pending':
              FieldValue.arrayRemove([requestData['toUserId']])
        });

        transaction.update(
            _firestore.collection('usuarios').doc(requestData['toUserId']), {
          'friendsList.pending':
              FieldValue.arrayRemove([requestData['fromUserId']])
        });
      });

      _logger.logInfo('Solicitud cancelada exitosamente');
    } catch (e) {
      _logger.logError('Error al cancelar solicitud: $e');
      rethrow;
    }
  }
}
