---
skill: screen-widget
version: 1.0.0
domain: flutter-ui
trigger_phrases:
  - "crear pantalla"
  - "nueva pantalla"
  - "nuevo widget"
  - "crear widget"
  - "agregar screen"
applies_to:
  - "lib/screens/**/*.dart"
  - "lib/widgets/**/*.dart"
---

# Skill: Pantalla o Widget Flutter

## Propósito
Guía la creación de pantallas (`Screen`) y widgets reutilizables en Flutter, respetando los patrones de estado, theming dinámico con `ColorProvider`, guard de suscripción con `AccessControlWrapper`, y organización por feature.

## Comportamiento Esperado

### Siempre hacer
- Colocar pantallas en `lib/screens/<feature>/` y widgets en `lib/widgets/` (o subcarpeta si pertenece a un dominio)
- Usar `Consumer<ColorProvider>` o `Provider.of<ColorProvider>(context)` para colores del tema
- Usar `setState` para estado local del widget; never `Provider` para estado efímero de pantalla
- Agregar `print()` en métodos de acción del usuario (onPressed, onTap) para depuración
- Envolver llamadas a servicios en `try/catch` con `ScaffoldMessenger.of(context).showSnackBar(...)` para mostrar errores al usuario
- Para pantallas con restricción premium, envolver el widget raíz con `AccessControlWrapper`

### Nunca hacer
- No usar hardcoded colors; siempre referenciar `colorProvider.colors.*`
- No usar `GetX`, `Bloc` ni `Riverpod` para estado
- No hacer llamadas directas a Firestore desde widgets; delegarlo a servicios

## Proceso Paso a Paso
1. Crear el archivo en la ruta `lib/screens/<feature>/<nombre>_screen.dart` o `lib/widgets/<nombre>_widget.dart`
2. Extender `StatefulWidget` si necesita estado local; `StatelessWidget` si es puramente presentacional
3. En el `build`, obtener `ColorProvider` via `Provider.of<ColorProvider>(context, listen: false)` o `Consumer`
4. Definir métodos privados `_handleAccion()` con `print()` al inicio y llamada al servicio correspondiente
5. Manejar estados de carga con `bool _isLoading = false` y `setState`
6. Usar `ScaffoldMessenger.of(context).showSnackBar(...)` para feedback de éxito/error
7. Ejecutar `dart analyze lib/screens/<feature>/<archivo>.dart`

## Plantilla de Salida

```dart
import 'package:control_gastos/services/mi_service.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MiNuevaPantalla extends StatefulWidget {
  final String userUid;

  const MiNuevaPantalla({super.key, required this.userUid});

  @override
  State<MiNuevaPantalla> createState() => _MiNuevaPantallaState();
}

class _MiNuevaPantallaState extends State<MiNuevaPantalla> {
  final MiService _miService = MiService();
  bool _isLoading = false;

  Future<void> _handleAccion() async {
    print('MiNuevaPantalla: _handleAccion iniciado para uid=${widget.userUid}');
    setState(() => _isLoading = true);
    try {
      final resultado = await _miService.ejecutarAccion(widget.userUid);
      if (!mounted) return;
      if (resultado != null) {
        print('MiNuevaPantalla: acción completada exitosamente');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Operación exitosa')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mi Pantalla',
          style: TextStyle(color: colorProvider.colors.primaryTextColor),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ElevatedButton(
                onPressed: _handleAccion,
                child: const Text('Ejecutar'),
              ),
            ),
    );
  }
}
```

## Criterios de Éxito
- [ ] El archivo está en la carpeta correcta por feature
- [ ] Los colores se obtienen de `colorProvider.colors.*`, nunca hardcodeados
- [ ] Los métodos de acción tienen `print()` al inicio con información contextual
- [ ] Se verifica `mounted` antes de llamar a `setState` o `ScaffoldMessenger` tras `await`
- [ ] El archivo compila sin errores (`dart analyze`)

## Referencias del Proyecto
- Archivos relacionados: `lib/services/provider_colors.dart`, `lib/widgets/access_control_wrapper.dart`, `lib/models/colors_model.dart`
- Comandos relacionados: `dart analyze lib/screens/<feature>/<archivo>.dart`
- Convenciones aplicadas: Provider para colores, setState para estado local, snake_case en archivo
