import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/screens/inicio/welcome_screen.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase y FirestoreService
  try {
    await FirestoreService().initialize();
  } on FirebaseException catch (e) {
    // Imprimir el mensaje de error y el código
    print(
        "Error durante la inicialización de Firebase: ${e.message} (code: ${e.code})");
    return; // No continuar si hay un error
  } catch (e) {
    // Capturar otros errores
    print("Error inesperado: $e");
    return; // No continuar si hay un error
  }

  runApp(const MainApp()); // Inicia la aplicación
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Oculta el banner de depuración
      title: 'Control de Gastos',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WelcomeScreen(),
    );
  }
}
