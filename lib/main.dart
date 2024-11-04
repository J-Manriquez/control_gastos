import 'package:control_gastos/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Asegura la inicialización de widgets
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,); // Inicializa Firebase
  runApp(const MainApp()); // Inicia la aplicación
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Hello World!'),
        ),
      ),
    );
  }
}
