# Índice de Skills — control_gastos

| Skill | Dominio | Cuándo usar |
|-------|---------|-------------|
| [new-model](new-model.md) | data-modeling | Al crear o modificar un modelo de datos Dart para Firestore |
| [firebase-service](firebase-service.md) | firebase-integration | Al crear o extender un servicio que accede a Cloud Firestore |
| [screen-widget](screen-widget.md) | flutter-ui | Al crear una nueva pantalla o widget reutilizable Flutter |
| [shared-expense-feature](shared-expense-feature.md) | shared-expenses | Al modificar el sistema de gastos compartidos, distribución o versionado |
| [subscription-access-control](subscription-access-control.md) | subscription | Al agregar restricciones de acceso premium o lógica free/pro |
| [friends-notifications](friends-notifications.md) | social-features | Al trabajar con el sistema de amigos (shortId) y notificaciones |
| [migration-versioning](migration-versioning.md) | data-migration | Al agregar migraciones de datos de usuarios en Firestore |
| [payment-integration](payment-integration.md) | payments | Al implementar o extender el flujo de pago con Mercado Pago |

## Cómo usar estas skills
1. Identifica qué dominio cubre la tarea que vas a realizar.
2. Indica al asistente: "Aplica la skill [nombre]" — o simplemente usa las frases disparadoras listadas arriba.
3. El asistente seguirá el proceso definido en la skill automáticamente.

## Combinaciones frecuentes
- **Nuevo gasto compartido**: `new-model` + `firebase-service` + `shared-expense-feature`
- **Nueva feature con restricción premium**: `screen-widget` + `subscription-access-control`
- **Agregar notificación**: `firebase-service` + `friends-notifications`
- **Actualizar estructura de datos existente**: `migration-versioning` + `new-model`
