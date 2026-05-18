---
skill: friends-notifications
version: 1.0.0
domain: social-features
trigger_phrases:
  - "solicitud de amistad"
  - "agregar amigo"
  - "enviar notificación"
  - "notificación"
  - "buscar amigo"
  - "shortId"
applies_to:
  - "lib/services/friends_service.dart"
  - "lib/screens/friends/*.dart"
  - "lib/screens/notifications/*.dart"
  - "lib/models/notification_model.dart"
  - "lib/models/friend_request_model.dart"
---

# Skill: Amigos y Notificaciones

## Propósito
Guía la implementación de features relacionadas con el sistema de amigos (búsqueda por `shortId`, solicitudes, aceptación/rechazo) y el envío/lectura de notificaciones en Firestore.

## Comportamiento Esperado

### Siempre hacer
- Buscar usuarios siempre por `userShortId` (lowercase), nunca por UID directo en flujos de búsqueda de amigos
- Usar transacciones Firestore para: enviar solicitud + actualizar estado del usuario receptor
- Crear documentos de `NotificationModel` en la subcolección `usuarios/{userId}/notifications/` al enviar solicitudes o cambios relevantes
- Verificar que no exista solicitud pendiente antes de crear una nueva (evitar duplicados)
- Agregar `print()` al iniciar búsqueda, al encontrar usuario y al completar la operación

### Nunca hacer
- No exponer el UID de Firebase a otros usuarios; usar `shortId` para búsquedas y referencias externas
- No crear notificaciones fuera de la subcolección `usuarios/{userId}/notifications/`
- No omitir la verificación de amistad existente antes de enviar solicitud

## Proceso Paso a Paso
1. Para buscar un amigo: normalizar `shortId` a lowercase, query en colección `usuarios` por `userShortId`
2. Verificar que el usuario encontrado no sea el mismo usuario actual
3. Verificar en `friendsList.accepted` que no sean ya amigos
4. Verificar en `friendRequests` que no haya solicitud pendiente bidireccional
5. En una transacción: crear documento en `friendRequests/` + crear `NotificationModel` en `usuarios/{toUserId}/notifications/`
6. Para aceptar solicitud: transacción que actualiza `friendRequests/{id}.status = 'accepted'` + agrega IDs mutuamente en `friendsList.accepted` de ambos usuarios + actualiza `pending` y `accepted` en los mapas correspondientes
7. Para rechazar solicitud: actualizar `friendRequests/{id}.status = 'rejected'` sin modificar `friendsList`
8. Ejecutar `dart analyze` sobre los archivos modificados

## Plantilla de Salida

```dart
// Enviar notificación a un usuario
Future<bool> enviarNotificacion(String toUserId, NotificationModel notif) async {
  try {
    print('FriendsService: enviando notificación tipo=${notif.type} a $toUserId');
    await _firestore
        .collection('usuarios')
        .doc(toUserId)
        .collection('notifications')
        .doc(notif.id)
        .set(notif.toMap());
    print('FriendsService: notificación enviada con id=${notif.id}');
    return true;
  } catch (e) {
    _logger.logError('Error enviando notificación: $e');
    return false;
  }
}

// Construir NotificationModel para solicitud de amistad
NotificationModel buildFriendRequestNotification(String fromUserId, String requestId) {
  return NotificationModel(
    id: const Uuid().v4(),
    title: 'Nueva solicitud de amistad',
    message: 'Tienes una nueva solicitud de amistad',
    type: 'friendRequest',
    sourceId: requestId,
    senderId: fromUserId,
    timestamp: DateTime.now(),
    isRead: false,
    additionalData: {},
  );
}

// Aceptar solicitud de amistad (transacción)
Future<bool> aceptarSolicitud(String requestId, String fromUserId, String toUserId) async {
  try {
    print('FriendsService: aceptando solicitud $requestId entre $fromUserId y $toUserId');
    await _firestore.runTransaction((transaction) async {
      final requestRef = _firestore.collection('friendRequests').doc(requestId);
      final fromRef = _firestore.collection('usuarios').doc(fromUserId);
      final toRef = _firestore.collection('usuarios').doc(toUserId);

      transaction.update(requestRef, {'status': 'accepted'});
      transaction.update(fromRef, {
        'friendsList.accepted': FieldValue.arrayUnion([toUserId]),
        'friendsList.pending': FieldValue.arrayRemove([toUserId]),
      });
      transaction.update(toRef, {
        'friendsList.accepted': FieldValue.arrayUnion([fromUserId]),
        'friendsList.pending': FieldValue.arrayRemove([fromUserId]),
      });
    });
    print('FriendsService: solicitud $requestId aceptada');
    return true;
  } catch (e) {
    _logger.logError('Error en aceptarSolicitud: $e');
    return false;
  }
}
```

## Criterios de Éxito
- [ ] Las búsquedas de usuario usan `userShortId` en lowercase
- [ ] Se verifica amistad existente y solicitud pendiente antes de crear nueva
- [ ] Las transacciones cubren la escritura en múltiples colecciones
- [ ] Las notificaciones se crean en `usuarios/{userId}/notifications/`
- [ ] El flujo de aceptar solicitud usa transacción que actualiza `friendRequests` y `friendsList` de ambos usuarios
- [ ] Hay `print()` en inicio, resultado y error de las operaciones

## Referencias del Proyecto
- Archivos relacionados: `lib/services/friends_service.dart`, `lib/models/notification_model.dart`, `lib/models/friend_request_model.dart`
- Colecciones Firestore: `usuarios/{id}/notifications/`, `friendRequests/`
- Convenciones aplicadas: `shortId` para búsqueda pública, transacciones para escrituras multi-doc
