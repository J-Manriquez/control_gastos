---
skill: shared-expense-feature
version: 1.0.0
domain: shared-expenses
trigger_phrases:
  - "gasto compartido"
  - "modificar gasto compartido"
  - "nueva versión de gasto"
  - "distribución de gastos"
  - "participantes"
  - "votación de versión"
applies_to:
  - "lib/screens/shared_expenses/*.dart"
  - "lib/services/shared_expense_service.dart"
  - "lib/services/distribution_service.dart"
  - "lib/widgets/distribution/*.dart"
---

# Skill: Feature de Gastos Compartidos

## Propósito
Guía cualquier modificación o extensión del sistema de gastos compartidos: distribución (igualitaria/porcentaje), versionado con votación, gestión de participantes y acceso según `permissionType`.

## Comportamiento Esperado

### Siempre hacer
- Verificar `permissionType` (`SharingPermissionType.creatorOnly` vs `allParticipants`) antes de permitir modificaciones
- Incrementar la versión al crear cambios en un `SharedExpenseGroup` (formato `"X.Y"` donde Y sube por cada modificación)
- Crear un documento en la subcolección `versions/{versionId}` al registrar cambios, con los campos `data`, `modifierId`, `votes`, `status: 'pending'`, `changeTypes`, `changeDetails`
- Enviar notificaciones a todos los participantes con `status == ParticipantStatus.accepted` cuando se crea una nueva versión
- Usar `DistributionService` para calcular distribuciones; nunca calcular montos manualmente en la UI
- Validar que la suma de porcentajes sea 100% antes de guardar con `DistributionService.validateDistribution()`
- Actualizar `sharedExpensesMap` en el documento del usuario al asociar/desasociar un gasto compartido
- Al votar una versión: actualizar el array `votes` del documento `versions/{versionId}`; si todos los participantes aceptados han votado `accepted`, marcar `status='accepted'` y copiar `data` al documento principal actualizando `currentVersion`

### Nunca hacer
- No modificar directamente el documento `sharedExpenses/{id}` sin crear una versión pendiente si `permissionType == creatorOnly` y el modificador no es el creador
- No omitir la actualización de `currentVersion` en el documento principal al aprobar una versión
- No calcular distribuciones fuera de `DistributionService`

## Proceso Paso a Paso
1. Leer el `SharedExpenseGroup` actual de Firestore incluyendo `permissionType` y `currentVersion`
2. Validar que el usuario actual tiene permisos según `permissionType`
3. Preparar el objeto modificado con los nuevos datos
4. Crear el snapshot de versión como `VersionVoteModel` con `status: 'pending'` y votos vacíos
5. En una transacción Firestore: actualizar documento principal + crear documento en subcolección `versions/`
6. Enviar notificaciones via `FirestoreService` a participantes aceptados
7. En UI: escuchar el stream del documento para reflejar el estado de votación en tiempo real
8. Ejecutar `dart analyze` sobre los archivos modificados

## Plantilla de Salida

```dart
// En SharedExpenseService — ejemplo de método que crea nueva versión
Future<bool> proponerCambios(
  String expenseId,
  SharedExpenseGroup grupoModificado,
  String modificadorId,
  List<String> changeTypes,
) async {
  try {
    print('SharedExpenseService: proponiendo cambios para $expenseId por $modificadorId');

    final docRef = _firestore.collection('sharedExpenses').doc(expenseId);
    final versionRef = docRef.collection('versions').doc();

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) throw Exception('Gasto compartido no encontrado');

      final actual = SharedExpenseGroup.fromMap(snap.data()!);

      // Verificar permisos
      if (actual.permissionType == SharingPermissionType.creatorOnly &&
          actual.creatorId != modificadorId) {
        throw Exception('Sin permisos para modificar');
      }

      final nuevaVersion = VersionVoteModel(
        id: versionRef.id,
        timestamp: DateTime.now(),
        data: grupoModificado.toMap(),
        previousVersion: actual.currentVersion,
        modifierId: modificadorId,
        votes: [],
        status: 'pending',
        changeTypes: changeTypes,
        changeDetails: {},
      );

      transaction.set(versionRef, nuevaVersion.toMap());
      transaction.update(docRef, {
        'version': _incrementarVersion(actual.version),
        'lastModified': FieldValue.serverTimestamp(),
      });
    });

    print('SharedExpenseService: versión propuesta creada con id=${versionRef.id}');
    return true;
  } catch (e) {
    _logger.logError('Error en proponerCambios: $e');
    return false;
  }
}

String _incrementarVersion(String version) {
  final partes = version.split('.');
  final minor = int.parse(partes[1]) + 1;
  return '${partes[0]}.$minor';
}
```

## Criterios de Éxito
- [ ] Las modificaciones verifican `permissionType` antes de proceder
- [ ] Se crea un documento en `versions/` por cada cambio propuesto
- [ ] Las distribuciones se calculan siempre con `DistributionService`
- [ ] La transacción Firestore incluye actualización del documento principal y creación de versión
- [ ] Los porcentajes se validan con `validateDistribution()` antes de guardar
- [ ] Al votar, si todos aprueban, se copia `data` al documento principal y se actualiza `currentVersion`

## Referencias del Proyecto
- Archivos relacionados: `lib/services/shared_expense_service.dart`, `lib/services/distribution_service.dart`, `lib/models/shared_expense_models.dart`, `lib/models/version_vote_model.dart`, `lib/models/distribution_module_model.dart`
- Colecciones Firestore: `sharedExpenses/{id}`, `sharedExpenses/{id}/versions/{versionId}`
- Convenciones aplicadas: transacciones para multi-doc, validación de permisos, versionado incremental
