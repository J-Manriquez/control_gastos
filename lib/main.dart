import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/screens/gastos/gastos_screen.dart';
import 'package:control_gastos/screens/inicio/welcome_screen.dart';
import 'package:control_gastos/services/auth_service.dart';
import 'package:control_gastos/services/migration_service.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final firestore = FirestoreService();
    await firestore.initialize();

    // Verificar si hay un usuario con sesión activa
    final prefs = await SharedPreferences.getInstance();
    final String? savedUID = await AuthService().getSavedUserUID();

    if (savedUID != null) {
      // Reinicializar con autenticación
      await firestore.initializePostAuth();
      // Ejecutar migración si es necesario
      await MigrationService().migrateUserIfNeeded(savedUID);
    }

    runApp(MyApp(savedUID: savedUID));
  } catch (e) {
    CustomLogger().logError("Error durante la inicialización: $e");
    // Iniciar la app de todos modos, pero en un estado "degradado"
    runApp(const MyApp(savedUID: null));
  }
}

class MyApp extends StatefulWidget {
  final String? savedUID;

  const MyApp({super.key, this.savedUID});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ColorProvider()),
      ],
      child: Consumer<ColorProvider>(
        builder: (context, colorProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Control de Gastos',
            theme: ThemeData(
              scaffoldBackgroundColor: colorProvider.colors.backgroundColor,
              appBarTheme: AppBarTheme(
                backgroundColor: colorProvider.colors.appBarColor,
                titleTextStyle:
                    TextStyle(color: colorProvider.colors.primaryTextColor),
              ),
              textTheme: TextTheme(
                bodyMedium:
                    TextStyle(color: colorProvider.colors.primaryTextColor),
                bodyLarge:
                    TextStyle(color: colorProvider.colors.secondaryTextColor),
              ),
            ),
            home: widget.savedUID != null
                ? ExpenseGroupsScreen(userUid: widget.savedUID!)
                : WelcomeScreen(),
          );
        },
      ),
    );
  }
}
