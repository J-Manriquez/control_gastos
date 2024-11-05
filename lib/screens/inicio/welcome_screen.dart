import 'package:control_gastos/screens/gastos/gastos_screen.dart';
import 'package:control_gastos/screens/inicio/login_screen.dart';
import 'package:control_gastos/screens/inicio/register_screen.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Definimos la AppBar con el título de la app
      appBar: AppBar(
        title: const Text('Bienvenido a Control de Gastos'),
        centerTitle: true,
      ),
      // Contenido principal de la pantalla
      body: Center(
        // Column para organizar el texto de bienvenida y los botones
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Texto de bienvenida
            const Text(
              'Bienvenido a Control de Gastos',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16), // Espacio entre el texto y los botones

            const Text(
              'Gestiona y organiza tus gastos de manera sencilla y eficiente.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32), // Espacio entre el texto y los botones

            // Botón para iniciar sesión
            ElevatedButton(
              onPressed: () {
                // Navega a la pantalla de inicio de sesión
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Iniciar Sesión'),
            ),
            const SizedBox(height: 16), // Espacio entre los botones

            // Botón para registrarse
            ElevatedButton(
              onPressed: () {
                // Navega a la pantalla de registro
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const RegisterScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors
                    .green, // Cambia el color del botón de registro a verde
              ),
              child: const Text('Registrarse'),
            ),

            const SizedBox(height: 32), // Espacio entre el texto y los botones

            // Botón para iniciar sesión
            ElevatedButton(
              onPressed: () {
                // Navega a la pantalla de inicio de sesión
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ExpenseGroupsScreen(userUid: 'D2W0NUtFMlMnceGWKUlGJFuierz1',)),
                );
              },
              child: const Text('otro'),
            ),
          ],
        ),
      ),
    );
  }
}
