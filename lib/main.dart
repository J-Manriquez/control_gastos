import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/screens/gastos/gastos_screen.dart';
import 'package:control_gastos/screens/inicio/welcome_screen.dart';
import 'package:control_gastos/services/auth_service.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await FirestoreService().initialize();
  } on FirebaseException catch (e) {
    CustomLogger().logError(
        "Error durante la inicialización de Firebase: ${e.message} (code: ${e.code})");
    return;
  } catch (e) {
    CustomLogger().logError("Error inesperado: $e");
    return;
  }

  // Verifica si hay una sesión guardada
  // ignore: unused_local_variable
  final prefs = await SharedPreferences.getInstance();
  final String? savedUID = await AuthService().getSavedUserUID();

  runApp(MyApp(savedUID: savedUID));
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
                titleTextStyle: TextStyle(color: colorProvider.colors.primaryTextColor),
              ),
              textTheme: TextTheme(
                bodyMedium: TextStyle(color: colorProvider.colors.primaryTextColor),
                bodyLarge: TextStyle(color: colorProvider.colors.secondaryTextColor),
              ),
            ),
            home: widget.savedUID != null ? ExpenseGroupsScreen(userUid: widget.savedUID!) : WelcomeScreen(),
          );
        },
      ),
    );
  }
}