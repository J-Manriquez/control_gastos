---
skill: payment-integration
version: 1.0.0
domain: payments
trigger_phrases:
  - "pago"
  - "Mercado Pago"
  - "suscripción de pago"
  - "procesar pago"
  - "preferencia de pago"
  - "webview de pago"
applies_to:
  - "lib/services/mercado_pago_service.dart"
  - "lib/services/payment_polling_service.dart"
  - "lib/services/payment_validation_service.dart"
  - "lib/widgets/payment_webview.dart"
---

# Skill: Integración de Pagos (Mercado Pago)

## Propósito
Guía la implementación del flujo de pago con Mercado Pago: creación de preferencia vía Firebase Function, apertura en WebView, polling de estado y validación del pago con actualización de `userType`.

## Comportamiento Esperado

### Siempre hacer
- Crear la preferencia de pago SIEMPRE vía `MercadoPagoService.createPaymentPreference(...)` que llama a la Firebase Function; nunca llamar a la API de Mercado Pago directamente desde el cliente
- Abrir el flujo de pago en `PaymentWebview` (WebView interno), nunca en browser externo a menos que sea fallback
- Usar `PaymentPollingService` para verificar el estado del pago de forma periódica; no bloquear la UI
- Al confirmar pago exitoso: actualizar `userType = 'pro'` en Firestore vía `PaymentValidationService`
- Agregar `print()` en cada etapa: creación de preferencia, apertura de WebView, resultado de polling, actualización de userType
- Manejar explícitamente estados `rejected` e `in_process` del polling mostrando feedback apropiado al usuario

### Nunca hacer
- No hardcodear credenciales de Mercado Pago en el cliente (van en Firebase Functions environment)
- No modificar `userType` directamente desde el cliente sin pasar por `PaymentValidationService`
- No mostrar el `paymentId` en logs de producción; usar solo para debugging interno

## Proceso Paso a Paso
1. Recopilar datos del usuario (`userEmail`, `userId`) y del plan (`title`, `price`, `planType`)
2. Llamar `MercadoPagoService.createPaymentPreference(...)` y obtener la URL de checkout
3. Mostrar `PaymentWebview` con la URL; escuchar callbacks de retorno/cancelación
4. Al detectar retorno exitoso (URL de success): llamar a `PaymentPollingService.startPolling(paymentId)`
5. Al polling confirmar pago `approved`: llamar `PaymentValidationService.validateAndUpgrade(userId)` que actualiza Firestore
6. Mostrar feedback al usuario y navegar a pantalla apropiada
7. Ejecutar `dart analyze` sobre los archivos modificados

## Plantilla de Salida

```dart
// Flujo de pago en pantalla de suscripción
Future<void> _iniciarFlujoSuscripcion() async {
  print('PaymentFlow: iniciando flujo de suscripción para uid=$_userUid');
  setState(() => _isLoading = true);
  try {
    final preferencia = await MercadoPagoService.createPaymentPreference(
      title: 'Control Gastos Pro - Mensual',
      price: 499.0,
      userEmail: _userEmail,
      userId: _userUid,
      planType: 'monthly',
    );

    if (preferencia == null) {
      throw Exception('No se pudo crear la preferencia de pago');
    }

    print('PaymentFlow: preferencia creada, abriendo WebView');
    if (!mounted) return;

    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentWebview(
          checkoutUrl: preferencia['checkoutUrl'],
          paymentId: preferencia['paymentId'],
        ),
      ),
    );

    if (resultado == true) {
      print('PaymentFlow: pago confirmado, actualizando usuario');
      await PaymentValidationService().validateAndUpgrade(_userUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Suscripción activada!')),
      );
    } else {
      print('PaymentFlow: pago cancelado o rechazado');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago cancelado o rechazado. Podés intentarlo de nuevo.')),
      );
    }
  } catch (e) {
    CustomLogger().logError('Error en flujo de suscripción: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error al procesar el pago')),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

## Criterios de Éxito
- [ ] La preferencia se crea via `MercadoPagoService` (Firebase Function), nunca directo a API
- [ ] El flujo de pago ocurre en `PaymentWebview`
- [ ] La actualización de `userType` ocurre solo tras confirmación de `PaymentValidationService`
- [ ] Los estados `rejected` e `in_process` se manejan con feedback explícito al usuario
- [ ] Hay `print()` en cada etapa del flujo (creación, apertura, confirmación, actualización)
- [ ] Errores se loguean con `CustomLogger().logError()` y se muestran al usuario con SnackBar

## Referencias del Proyecto
- Archivos relacionados: `lib/services/mercado_pago_service.dart`, `lib/services/payment_polling_service.dart`, `lib/services/payment_validation_service.dart`, `lib/widgets/payment_webview.dart`
- Infraestructura: Firebase Cloud Functions en `/functions/index.js` manejan la lógica de Mercado Pago
- Convenciones aplicadas: credenciales en Functions, no en cliente; validación server-side del pago
