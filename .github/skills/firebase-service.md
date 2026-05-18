---
skill: firebase-service
version: 1.0.0
domain: firebase-integration
trigger_phrases:
  - "crear servicio"
  - "nuevo servicio firebase"
  - "agregar operación firestore"
  - "implementar CRUD"
  - "operación en firestore"
applies_to:
  - "lib/services/*.dart"
  - "nuevos archivos en lib/services/"
---

# Skill: Servicio Firebase / Firestore

## Propósito
Guía la implementación de servicios de acceso a Firebase Firestore siguiendo el patrón establecido en el proyecto: manejo de errores uniforme, logging con `CustomLogger`, uso de transacciones para escrituras multi-documento y print de depuración en puntos clave.

## Comportamiento Esperado

### Siempre hacer
- Envolver toda lógica Firebase en bloque `try/catch`
- Loguear errores con `CustomLogger().logError('Descripción: $e')`
- Loguear flujo con `CustomLogger().logInfo('Descripción')` en pasos clave
- Agregar `print()` en puntos relevantes del flujo (inicio de operación, resultado, error)
- Usar `runTransaction` para operaciones que modifiquen ≥ 2 documentos
- Usar `FirebaseFirestore.instance` directamente o vía `FirestoreService()` según contexto
- Retornar `bool` o `null` en métodos que puedan fallar sin lanzar excepción al caller; lanzar excepción si el caller debe manejarla
- Usar `snapshots()` para datos que la UI debe reflejar en tiempo real; usar `get()` para datos que solo se necesitan una vez

### Nunca hacer
- No usar `await` dentro de `runTransaction` fuera de operaciones del transaction object (puede causar deadlocks)
- No hacer lecturas costosas repetidas; consolidar en una sola query cuando sea posible
- No acceder a Firestore colecciones hardcodeadas sin constantes si se usan más de una vez

## Proceso Paso a Paso
1. Declarar `final FirebaseFirestore _firestore = FirebaseFirestore.instance;` y `final CustomLogger _logger = CustomLogger();`
2. Por cada método público: agregar `print()` al inicio indicando qué operación se inicia
3. Implementar la lógica dentro de `try { ... } catch (e) { _logger.logError(...); rethrow/return false; }`
4. Para escrituras que afecten múltiples documentos, usar `_firestore.runTransaction(...)`
5. En operaciones de lectura, convertir documentos con `fromMap()` del modelo correspondiente
6. Agregar `print()` al finalizar exitosamente con datos relevantes del resultado
7. Ejecutar `dart analyze lib/services/<archivo>.dart`

## Plantilla de Salida

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/mi_modelo.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class MiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CustomLogger _logger = CustomLogger();

  // Crear registro
  Future<String?> crearRegistro(MiModelo modelo) async {
    try {
      print('MiService: iniciando creación de registro: ${modelo.nombre}');
      final docRef = _firestore.collection('miColeccion').doc();
      await docRef.set({...modelo.toMap(), 'id': docRef.id});
      print('MiService: registro creado con id=${docRef.id}');
      return docRef.id;
    } catch (e) {
      _logger.logError('Error en crearRegistro: $e');
      return null;
    }
  }

  // Actualizar varios documentos en transacción
  Future<bool> actualizarConTransaccion(String idA, String idB, Map<String, dynamic> datos) async {
    try {
      print('MiService: iniciando transacción para $idA y $idB');
      await _firestore.runTransaction((transaction) async {
        final refA = _firestore.collection('miColeccion').doc(idA);
        final refB = _firestore.collection('miColeccion').doc(idB);
        transaction.update(refA, datos);
        transaction.update(refB, {'lastModified': FieldValue.serverTimestamp()});
      });
      print('MiService: transacción completada');
      return true;
    } catch (e) {
      _logger.logError('Error en actualizarConTransaccion: $e');
      return false;
    }
  }

  // Obtener por id
  Future<MiModelo?> obtenerPorId(String id) async {
    try {
      final doc = await _firestore.collection('miColeccion').doc(id).get();
      if (!doc.exists) return null;
      return MiModelo.fromMap(doc.data()!);
    } catch (e) {
      _logger.logError('Error en obtenerPorId: $e');
      return null;
    }
  }

  // Escuchar cambios en tiempo real
  Stream<List<MiModelo>> escucharLista(String filtroId) {
    return _firestore
        .collection('miColeccion')
        .where('referenciaId', isEqualTo: filtroId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MiModelo.fromMap(doc.data()))
            .toList());
  }
}
```

## Criterios de Éxito
- [ ] Cada método tiene `try/catch` con `_logger.logError()` en el catch
- [ ] Hay al menos un `print()` al inicio de cada operación relevante
- [ ] Las escrituras multi-documento usan `runTransaction`
- [ ] Los métodos retornan `null`/`false` en error sin hacer crash silencioso
- [ ] Los métodos de datos en tiempo real retornan `Stream<List<T>>` usando `.snapshots().map(...)`
- [ ] El archivo compila sin errores (`dart analyze`)

## Referencias del Proyecto
- Archivos relacionados: `lib/services/shared_expense_service.dart`, `lib/services/friends_service.dart`
- Comandos relacionados: `dart analyze lib/services/<archivo>.dart`
- Convenciones aplicadas: `CustomLogger` para logging, `print()` para depuración, transacciones Firestore para multi-doc
