---
skill: migration-versioning
version: 1.0.0
domain: data-migration
trigger_phrases:
  - "migración de datos"
  - "migrar usuario"
  - "migrar colección"
  - "actualizar estructura de datos"
  - "MigrationService"
  - "versión de datos"
applies_to:
  - "lib/services/migration_service.dart"
  - "lib/migrations/*.dart"
---

# Skill: Migraciones de Datos

## Propósito
Guía la implementación de migraciones de datos de usuario en Firestore. Las migraciones se ejecutan en cada inicio de sesión via `MigrationService.migrateUserIfNeeded()` y deben ser idempotentes y atómicas.

## Comportamiento Esperado

### Siempre hacer
- Hacer cada migración idempotente: verificar si ya fue aplicada antes de ejecutar (campo de versión o flag en el documento del usuario)
- Usar transacciones Firestore cuando la migración modifica múltiples documentos
- Loguear con `CustomLogger().logInfo()` el inicio y fin de cada migración, y con `logError()` en fallos
- Agregar `print()` al inicio de cada migración con el nombre y el UID del usuario
- Proteger con `try/catch` cada migración individual para que un fallo no bloquee las siguientes

### Nunca hacer
- No hacer migraciones destructivas sin backup implícito (guardar versión anterior antes de sobrescribir)
- No ejecutar migraciones que lean toda la colección de usuarios (costo alto); acotar siempre al usuario actual
- No bloquear el inicio de sesión si una migración falla; loguear y continuar

## Proceso Paso a Paso
1. Definir la migration en `lib/migrations/` o dentro de `MigrationService` como método privado `_migrarVX(String uid)`
2. Al inicio del método: leer el documento del usuario y verificar si ya tiene el campo/versión esperado
3. Si ya está migrado: retornar inmediatamente con `print('Migration VX: ya aplicada para $uid')`
4. Ejecutar la transformación de datos (renombrar campos, agregar campos nuevos, mover subcolecciones)
5. Usar `runTransaction` si se modifican ≥ 2 documentos; `update` simple si es solo 1 campo
6. Marcar la migración como aplicada actualizando el campo de versión en el documento del usuario
7. En `migrateUserIfNeeded`: ejecutar migraciones en orden secuencial, cada una en su propio try/catch

## Plantilla de Salida

```dart
// En MigrationService
Future<void> migrateUserIfNeeded(String uid) async {
  CustomLogger().logInfo('MigrationService: verificando migraciones para $uid');
  await _migrarV1(uid);
  await _migrarV2(uid);
  // Agregar nuevas migraciones aquí
}

Future<void> _migrarV2(String uid) async {
  print('MigrationService: evaluando migración V2 para $uid');
  try {
    final userRef = FirebaseFirestore.instance.collection('usuarios').doc(uid);
    final snap = await userRef.get();
    if (!snap.exists) return;

    final data = snap.data()!;

    // Verificar si ya fue aplicada
    if (data['migrationV2Applied'] == true) {
      print('MigrationService: migración V2 ya aplicada para $uid');
      return;
    }

    // Aplicar la transformación
    await userRef.update({
      'nuevoCampo': data['campoAntiguo'] ?? 'valorDefault',
      'migrationV2Applied': true,
    });

    CustomLogger().logInfo('MigrationService: migración V2 aplicada para $uid');
  } catch (e) {
    CustomLogger().logError('MigrationService: error en migración V2 para $uid: $e');
    // No relanzar — no bloquear el inicio de sesión
  }
}
```

## Criterios de Éxito
- [ ] Cada migración verifica si ya fue aplicada antes de ejecutar
- [ ] Las migraciones fallidas no bloquean el inicio de sesión (no se relanza la excepción)
- [ ] Hay `print()` al evaluar y al completar o saltar cada migración
- [ ] Las operaciones multi-documento usan `runTransaction`
- [ ] El campo de control (`migrationVXApplied`) se escribe al finalizar exitosamente

## Referencias del Proyecto
- Archivos relacionados: `lib/services/migration_service.dart`, `lib/main.dart` (punto de llamada)
- Colecciones Firestore: `usuarios/{uid}`
- Convenciones aplicadas: idempotencia, aislamiento por usuario, no bloqueo de sesión en fallo
