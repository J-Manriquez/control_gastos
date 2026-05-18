---
skill: new-model
version: 1.0.0
domain: data-modeling
trigger_phrases:
  - "crear modelo"
  - "nuevo modelo de datos"
  - "agregar modelo"
  - "implementar modelo"
applies_to:
  - "lib/models/*.dart"
  - "nuevos archivos en lib/models/"
---

# Skill: Nuevo Modelo de Datos

## Propósito
Guía la creación de modelos de datos Dart compatibles con Firestore, asegurando serialización correcta con `toMap()`/`fromMap()` y consistencia con los patrones del proyecto.

## Comportamiento Esperado

### Siempre hacer
- Implementar `toMap()` que retorne `Map<String, dynamic>` completo con todos los campos
- Implementar factory constructor `fromMap(Map<String, dynamic> map)` con valores por defecto para campos opcionales
- Manejar conversión de `Timestamp` de Firestore a `DateTime` en `fromMap()` y la inversa en `toMap()`
- Usar `CustomLogger().logError()` en bloques `fromMap` si hay parseo complejo
- Colocar el archivo en `lib/models/` con nombre en snake_case

### Nunca hacer
- No omitir `toMap()` ni `fromMap()` aunque el modelo parezca simple
- No usar `json_serializable` ni generación de código automático (no está en el proyecto)
- No hardcodear valores de enums como strings sin usar `.toString()` o un método `fromString()`

## Proceso Paso a Paso
1. Definir los campos del modelo con tipos Dart apropiados
2. Crear constructor `const`/normal con todos los campos requeridos y opcionales con defaults
3. Implementar `toMap()` convirtiendo `DateTime` → `Timestamp` o `toIso8601String()` según el contexto Firestore
4. Implementar `fromMap()` con null-safety y valores por defecto: `map['campo'] ?? valorDefault`
5. Implementar enums asociados dentro del mismo archivo si son exclusivos del modelo
6. Agregar `print()` de depuración en factory constructors si hay lógica compleja de parseo
7. Ejecutar `dart analyze lib/models/<archivo>.dart`

## Plantilla de Salida

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/utils/custom_logger.dart';

enum MiTipoEnum { valorA, valorB }

class MiModelo {
  final String id;
  final String nombre;
  final double monto;
  final DateTime fecha;
  final MiTipoEnum tipo;
  final bool archivado;

  MiModelo({
    required this.id,
    required this.nombre,
    required this.monto,
    required this.fecha,
    this.tipo = MiTipoEnum.valorA,
    this.archivado = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'monto': monto,
      'fecha': Timestamp.fromDate(fecha),
      'tipo': tipo.toString(),
      'archivado': archivado,
    };
  }

  factory MiModelo.fromMap(Map<String, dynamic> map) {
    try {
      return MiModelo(
        id: map['id'] as String,
        nombre: map['nombre'] ?? '',
        monto: (map['monto'] as num).toDouble(),
        fecha: (map['fecha'] as Timestamp).toDate(),
        tipo: MiTipoEnum.values.firstWhere(
          (e) => e.toString() == map['tipo'],
          orElse: () => MiTipoEnum.valorA,
        ),
        archivado: map['archivado'] ?? false,
      );
    } catch (e) {
      CustomLogger().logError('Error en MiModelo.fromMap: $e');
      rethrow;
    }
  }
}
```

## Criterios de Éxito
- [ ] El modelo compila sin errores (`dart analyze`)
- [ ] `toMap()` incluye todos los campos del constructor
- [ ] `fromMap()` maneja correctamente valores `null` con operador `??`
- [ ] Los `Timestamp` de Firestore se convierten a `DateTime` en `fromMap()`
- [ ] Los enums usan `.toString()` para serialización y `firstWhere` con `orElse` para deserialización

## Referencias del Proyecto
- Archivos relacionados: `lib/models/gastos_model.dart`, `lib/models/shared_expense_models.dart`
- Convenciones aplicadas: snake_case en archivos, PascalCase en clases, camelCase en campos
