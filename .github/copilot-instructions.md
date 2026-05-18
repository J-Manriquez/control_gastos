# Copilot Instructions — control_gastos

## Descripción del Proyecto
Aplicación Flutter de control de gastos personales y compartidos para Android. Permite registrar gastos propios, crear grupos de gastos compartidos con distribución configurable (igualitaria o por porcentaje), gestionar amigos mediante shortId, y acceder a funciones premium mediante suscripción con integración de Mercado Pago.

## Stack Tecnológico
- **Lenguaje principal**: Dart (SDK ^3.5.3)
- **Runtime / Plataforma**: Android (target primario), Flutter
- **Framework principal**: Flutter (Material Design)
- **Frameworks secundarios / librerías clave**: Firebase Core/Auth/Firestore/Database/Functions, Provider ^6.0.5, RxDart ^0.28.0, shared_preferences, uuid, intl, webview_flutter, share_plus, flutter_image_compress, image_picker
- **Gestor de paquetes**: pub (pubspec.yaml)
- **Base de datos**: Cloud Firestore (principal), Firebase Database, SharedPreferences (local)
- **Infraestructura / Despliegue**: Firebase Hosting + Cloud Functions (Node.js), Mercado Pago API via Functions

## Estructura del Proyecto
```
lib/
├── main.dart                    # Punto de entrada, inicialización Firebase, Provider
├── firebase_options.dart        # Configuración Firebase por plataforma
├── database/
│   └── singleton_db.dart        # FirestoreService (Singleton), acceso global a Firebase
├── models/                      # Modelos de datos con toMap/fromMap para Firestore
│   ├── gastos_model.dart        # Gasto, GastoType, GroupModel
│   ├── shared_expense_models.dart  # SharedExpenseGroup, ExpenseParticipant, enums
│   ├── distribution_module_model.dart  # DistributionModule, ParticipantShare
│   ├── user_model.dart          # UserModel
│   ├── notification_model.dart  # NotificationModel
│   ├── friend_request_model.dart
│   ├── version_vote_model.dart  # Sistema de versiones y votación
│   ├── subscription_model.dart
│   └── colors_model.dart
├── services/                    # Lógica de negocio, acceso a Firebase
│   ├── auth_service.dart        # Firebase Auth, gestión sesión
│   ├── shared_expense_service.dart  # CRUD gastos compartidos, versiones
│   ├── distribution_service.dart   # Cálculo distribuciones igual/porcentaje
│   ├── friends_service.dart     # Solicitudes de amistad por shortId
│   ├── subscription_service.dart   # Validación acceso free/pro, trial 14 días
│   ├── mercado_pago_service.dart   # Integración pagos vía Firebase Functions
│   ├── payment_polling_service.dart
│   ├── payment_validation_service.dart
│   ├── storage_service.dart     # Imágenes de perfil
│   ├── firebase_interceptor_service.dart
│   ├── migration_service.dart   # Migraciones de datos de usuario
│   └── provider_colors.dart     # ColorProvider (ChangeNotifier)
├── screens/                     # UI organizada por feature
│   ├── inicio/                  # welcome, login, register, reset_password
│   ├── gastos/                  # gastos_screen, insercion, edicion, archivados
│   ├── shared_expenses/         # insercion, edicion, distribution, participants, versions
│   ├── cuenta/                  # user_profile_screen
│   ├── friends/                 # pantallas de amigos
│   ├── notifications/           # pantallas de notificaciones
│   └── version_details_screen.dart
├── widgets/                     # Widgets reutilizables
│   ├── forms/gastos/            # gasto_form, subgrupo_gastos_form
│   ├── forms/compartidos/       # shared_gasto_form, shared_subgrupo_gasto_form
│   ├── distribution/            # distribution_module_widget, summary, selector, list
│   ├── access_control_wrapper.dart  # Guard de suscripción
│   ├── expense_details_widget.dart
│   ├── expense_drawer.dart
│   └── loading_screen.dart
└── utils/
    ├── custom_logger.dart        # Logger Singleton (print + logger lib)
    ├── validators.dart
    └── images/
```

## Comandos Clave
| Propósito        | Comando                                  |
|-----------------|------------------------------------------|
| Instalar deps   | `flutter pub get`                        |
| Build APK       | `flutter build apk`                      |
| Desarrollo      | `flutter run`                            |
| Analizar código | `dart analyze lib/<ruta_al_archivo>`     |
| Limpiar build   | `flutter clean`                          |
| Deploy Functions| `firebase deploy --only functions`       |
| Deploy Hosting  | `firebase deploy --only hosting`         |

## Convenciones de Código
- **Estilo**: 2 espacios de indentación, comillas simples
- **Naming archivos**: snake_case (`gastos_screen.dart`, `auth_service.dart`)
- **Naming clases**: PascalCase (`FirestoreService`, `SharedExpenseGroup`)
- **Naming variables/métodos**: camelCase (`expenseId`, `hasAccess()`)
- **Naming enums**: PascalCase con valores camelCase (`GastoType.normal`, `ParticipantStatus.pending`)
- **Idioma en código**: variables y comentarios en español; enums en inglés cuando son técnicos
- **Prints de depuración**: usar `print()` directamente, sin `kDebugMode`, en puntos clave del flujo
- **Logging de errores/info**: usar `CustomLogger().logError()` / `CustomLogger().logInfo()`
- **Modelos**: siempre implementar `toMap()` y `fromMap()` para serialización Firestore

## Patrones y Arquitectura
- **Patrón principal**: Feature-based screens + Service Layer + Singleton DB
- **Singleton**: `FirestoreService` (acceso global a Firestore), `CustomLogger`
- **Estado global**: Provider (`ColorProvider`) vía `MultiProvider` en `main.dart`
- **Manejo de errores**: try/catch en todos los métodos de servicio; errores logeados con `CustomLogger().logError()`, lanzar excepción o retornar `false`/`null` según contexto
- **Autenticación**: Firebase Auth + `SharedPreferences` para persistir UID entre sesiones
- **Control de acceso**: `AccessControlWrapper` valida suscripción antes de mostrar pantallas
- **Suscripción**: modelo free/pro; free tiene 14 días de trial desde `creationDate`
- **Versiones de gastos compartidos**: sistema de versionado con votación entre participantes

## Testing
- **Framework**: flutter_test (incluido en dev_dependencies)
- **Ubicación de tests**: [No configurado — completar manualmente]
- **Cobertura mínima requerida**: [No configurada]

## Variables de Entorno
- Configuración Firebase en `lib/firebase_options.dart` (generado por FlutterFire CLI)
- `google-services.json` en `android/app/` (no versionar claves reales)
- Credenciales Mercado Pago en Firebase Functions environment (no en cliente)

## Lo que Copilot DEBE hacer en este proyecto
- Usar `CustomLogger().logInfo()` / `CustomLogger().logError()` para logging de app
- Agregar `print()` directo en puntos clave de nuevas funcionalidades para depuración (sin `kDebugMode`)
- Implementar `toMap()` y `fromMap()` en todos los modelos nuevos
- Usar transacciones Firestore (`runTransaction`) para operaciones que modifiquen múltiples documentos
- Seguir la estructura de carpetas: modelos en `lib/models/`, servicios en `lib/services/`, pantallas en `lib/screens/<feature>/`
- Usar `Provider` para estado global; `setState` para estado local de widget
- Ejecutar `dart analyze lib/<archivo>` después de cada modificación para verificar errores
- Manejar el modelo free/pro al crear features que requieran restricción de acceso

## Lo que Copilot NO debe hacer en este proyecto
- No usar `kDebugMode` ni `developer.log` para prints de depuración
- No remover variables sin uso ni resolver warnings de linting salvo que se solicite explícitamente
- No eliminar prints existentes usados para depuración en consola
- No crear archivos fuera de la estructura establecida sin confirmación
- No sugerir dependencias nuevas sin advertirlo explícitamente
- No usar `GetX`, `Bloc` ni otros gestores de estado distintos a `Provider`
- No generar código que omita manejo de errores en métodos de servicio
- No modificar `firebase_options.dart` ni `google-services.json`
- No levantar servidores web para verificar errores; usar `dart analyze`

## Contexto Adicional
- **Target primario**: Android únicamente; archivos iOS/web/desktop existen pero no son el foco
- **Pagos**: Mercado Pago integrado via Firebase Cloud Functions (Node.js en `/functions/`); el cliente llama `MercadoPagoService` que invoca la Function
- **Migración de datos**: `MigrationService.migrateUserIfNeeded()` se ejecuta en cada inicio de sesión
- **shortId**: sistema para búsqueda de amigos sin compartir UID interno
- **Versiones compartidas**: los gastos compartidos tienen un sistema de versionado con votación; cambios requieren aprobación de todos los participantes según `permissionType`
