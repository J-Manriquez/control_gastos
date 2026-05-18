---
skill: subscription-access-control
version: 1.0.0
domain: subscription
trigger_phrases:
  - "restricción de acceso"
  - "verificar suscripción"
  - "feature premium"
  - "control de acceso"
  - "usuario free"
  - "usuario pro"
  - "trial"
applies_to:
  - "lib/services/subscription_service.dart"
  - "lib/widgets/access_control_wrapper.dart"
  - "lib/screens/**/*.dart"
---

# Skill: Control de Acceso y Suscripción

## Propósito
Guía la implementación de restricciones de acceso a features premium, usando el modelo free/pro con trial de 14 días. Define cuándo y cómo usar `AccessControlWrapper`, `SubscriptionService.hasAccess()` y `SubscriptionRestrictionModal`.

## Comportamiento Esperado

### Siempre hacer
- Usar `SubscriptionService().hasAccess(user)` como único punto de verificación de acceso
- Envolver pantallas o secciones premium con `AccessControlWrapper(userUid: uid, child: ...)` a nivel de navegación
- Mostrar `SubscriptionRestrictionModal` cuando un usuario free intenta acceder a feature premium desde dentro de la app (sin navegar)
- Leer `UserModel` desde Firestore para obtener `userType` y `creationDate` frescos; no usar datos cacheados para decisiones de acceso
- Agregar `print()` al verificar acceso, indicando `userType` y resultado de `hasAccess`

### Nunca hacer
- No comparar `user.userType == 'free'` directamente en la UI; delegar siempre a `SubscriptionService`
- No bloquear features ya en uso; el bloqueo aplica al intentar acceder a pantallas o iniciar nuevas operaciones premium
- No modificar `freeTrialDays = 14` sin actualizar también la lógica de notificación de vencimiento

## Proceso Paso a Paso
1. Identificar si la feature requiere suscripción pro (regla de negocio: grupos compartidos, imágenes de perfil, etc.)
2. En la pantalla que navega hacia la feature: obtener `UserModel` via `FirestoreService`
3. Llamar `SubscriptionService().hasAccess(user)` y agregar `print()` con el resultado
4. Si `hasAccess == false`: mostrar `SubscriptionRestrictionModal` y no navegar
5. Si `hasAccess == true`: navegar normalmente o envolver la pantalla destino con `AccessControlWrapper`
6. Para features dentro de una pantalla (botón específico): usar `hasAccess` inline con dialog de restricción
7. Ejecutar `dart analyze` sobre los archivos modificados

## Plantilla de Salida

```dart
// Ejemplo en pantalla que navega a feature premium
Future<void> _navegarAFeaturePremium() async {
  print('AccessCheck: verificando acceso a feature premium para uid=$_userUid');
  try {
    final userModel = await FirestoreService().getUserById(_userUid);
    if (userModel == null) return;

    final tieneAcceso = SubscriptionService().hasAccess(userModel);
    print('AccessCheck: userType=${userModel.userType}, hasAccess=$tieneAcceso');

    if (!tieneAcceso) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => const SubscriptionRestrictionModal(),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccessControlWrapper(
          userUid: _userUid,
          child: FeaturePremiumScreen(userUid: _userUid),
        ),
      ),
    );
  } catch (e) {
    CustomLogger().logError('Error verificando acceso: $e');
  }
}
```

## Criterios de Éxito
- [ ] El acceso se verifica con `SubscriptionService().hasAccess(user)`, no con comparación directa de `userType`
- [ ] Hay `print()` con `userType` y resultado de `hasAccess` al verificar acceso
- [ ] Se muestra `SubscriptionRestrictionModal` cuando el acceso es denegado
- [ ] `AccessControlWrapper` envuelve pantallas premium en la navegación
- [ ] El `UserModel` se lee fresco de Firestore para decisiones de acceso

## Referencias del Proyecto
- Archivos relacionados: `lib/services/subscription_service.dart`, `lib/widgets/access_control_wrapper.dart`, `lib/widgets/subscription_restriction_modal.dart`, `lib/models/user_model.dart`
- Convenciones aplicadas: `SubscriptionService` como único árbitro de acceso, trial 14 días desde `creationDate`
