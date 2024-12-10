import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/friend_request_model.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class FriendsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CustomLogger _logger = CustomLogger();

  // Enviar solicitud de amistad
  Future<void> sendFriendRequest(String fromUserId, String toShortId) async {
    try {
      // Primero, buscar el usuario por shortId
      final querySnapshot = await _firestore
          .collection('usuarios')
          .where('userShortId', isEqualTo: toShortId.toLowerCase())
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Usuario no encontrado');
      }

      final toUserId = querySnapshot.docs.first.id;

      // Verificar que no son ya amigos
      final fromUserDoc =
          await _firestore.collection('usuarios').doc(fromUserId).get();
      final toUserDoc =
          await _firestore.collection('usuarios').doc(toUserId).get();

      if (fromUserDoc.data()?['friendsList']?['accepted']?.contains(toUserId) ??
          false) {
        throw Exception('Ya son amigos');
      }

      // Verificar que no existe una solicitud pendiente en ninguna dirección
      final existingRequests = await _firestore
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

      // Crear nueva solicitud
      final requestId = _firestore.collection('friendRequests').doc().id;
      final request = FriendRequestModel(
        requestId: requestId,
        fromUserId: fromUserId,
        toUserId: toUserId,
        status: 'pending',
        timestamp: DateTime.now(),
      );

      await _firestore
          .collection('friendRequests')
          .doc(requestId)
          .set(request.toMap());

      _logger.logInfo('Solicitud de amistad enviada: $requestId');
    } catch (e) {
      _logger.logError('Error al enviar solicitud de amistad: $e');
      rethrow;
    }
  }

  // Responder a una solicitud de amistad
  Future<void> respondToFriendRequest(String requestId, String response) async {
    try {
      final requestDoc =
          await _firestore.collection('friendRequests').doc(requestId).get();

      if (!requestDoc.exists) {
        throw Exception('Solicitud no encontrada');
      }

      final request = FriendRequestModel.fromMap(requestDoc.data()!);

      // Actualizar estado de la solicitud
      await _firestore
          .collection('friendRequests')
          .doc(requestId)
          .update({'status': response});

      // Si fue aceptada, actualizar las listas de amigos de ambos usuarios
      if (response == 'accepted') {
        final batch = _firestore.batch();

        // Actualizar lista de amigos del remitente
        batch
            .update(_firestore.collection('usuarios').doc(request.fromUserId), {
          'friendsList.accepted': FieldValue.arrayUnion([request.toUserId])
        });

        // Actualizar lista de amigos del destinatario
        batch.update(_firestore.collection('usuarios').doc(request.toUserId), {
          'friendsList.accepted': FieldValue.arrayUnion([request.fromUserId])
        });

        await batch.commit();
      }

      _logger.logInfo('Solicitud $requestId: $response');
    } catch (e) {
      _logger.logError('Error al responder solicitud: $e');
      rethrow;
    }
  }

  // Cancelar solicitud de amistad enviada
  Future<void> cancelFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friendRequests').doc(requestId).delete();

      _logger.logInfo('Solicitud de amistad cancelada: $requestId');
    } catch (e) {
      _logger.logError('Error al cancelar solicitud: $e');
      rethrow;
    }
  }

  // Obtener solicitudes enviadas pendientes
  Stream<QuerySnapshot> getSentPendingRequests(String userId) {
    return _firestore
        .collection('friendRequests')
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Obtener solicitudes recibidas pendientes
  Stream<QuerySnapshot> getReceivedPendingRequests(String userId) {
    return _firestore
        .collection('friendRequests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Actualizar lista de amigos
  Future<void> _updateFriendsList(String userId, String friendId) async {
    try {
      await _firestore.collection('usuarios').doc(userId).update({
        'friendsList.accepted': FieldValue.arrayUnion([friendId])
      });
    } catch (e) {
      _logger.logError('Error al actualizar lista de amigos: $e');
      rethrow;
    }
  }

  // Bloquear usuario
  Future<void> blockUser(String userId, String userToBlockId) async {
    try {
      // Mover a la lista de bloqueados
      await _firestore.collection('usuarios').doc(userId).update({
        'friendsList.blocked': FieldValue.arrayUnion([userToBlockId]),
        'friendsList.accepted': FieldValue.arrayRemove([userToBlockId]),
        'friendsList.pending': FieldValue.arrayRemove([userToBlockId])
      });

      // Eliminar de la lista de amigos del otro usuario
      await _firestore.collection('usuarios').doc(userToBlockId).update({
        'friendsList.accepted': FieldValue.arrayRemove([userId]),
        'friendsList.pending': FieldValue.arrayRemove([userId])
      });

      _logger.logInfo('Usuario bloqueado: $userToBlockId');
    } catch (e) {
      _logger.logError('Error al bloquear usuario: $e');
      rethrow;
    }
  }

  // Desbloquear usuario
  Future<void> unblockUser(String userId, String blockedUserId) async {
    try {
      await _firestore.collection('usuarios').doc(userId).update({
        'friendsList.blocked': FieldValue.arrayRemove([blockedUserId])
      });

      _logger.logInfo('Usuario desbloqueado: $blockedUserId');
    } catch (e) {
      _logger.logError('Error al desbloquear usuario: $e');
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

      // Obtener los documentos de todos los amigos
      List<DocumentSnapshot> friendDocs = await Future.wait(
        friendIds.map((friendId) =>
            _firestore.collection('usuarios').doc(friendId).get()),
      );

      return friendDocs.where((doc) => doc.exists).toList();
    });
  }

// Obtener lista de usuarios bloqueados
  Stream<QuerySnapshot> getBlockedUsers(String userId) {
    return _firestore
        .collection('usuarios')
        .doc(userId)
        .collection('friendsList')
        .where('type', isEqualTo: 'blocked')
        .snapshots();
  }
}
