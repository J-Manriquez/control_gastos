import 'package:control_gastos/services/provider_colors.dart'; // Importa el proveedor de colores
import 'package:control_gastos/screens/inicio/login_screen.dart';
import 'package:control_gastos/screens/inicio/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Importa el paquete Provider para gestionar colores

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ColorProvider>(context).colors; // Obtiene los colores del provider

    return Scaffold(
      backgroundColor: colors.backgroundColor, // Aplica el color de fondo
      appBar: AppBar(
        title: const Text('Control de Gastos'),
        centerTitle: true,
        backgroundColor: colors.appBarColor, // Color de AppBar
        titleTextStyle: TextStyle(color: colors.secondaryTextColor, fontSize: 20), // Color del texto del AppBar
        iconTheme: IconThemeData(color: colors.secondaryTextColor), // Color de los iconos del AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Agrega padding para la pantalla
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Texto de bienvenida
              Text(
                'Bienvenido a Control de Gastos',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryTextColor, // Color del texto
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16), // Espacio entre el texto y los botones

              Text(
                'Gestiona y organiza tus gastos de manera sencilla y eficiente.',
                style: TextStyle(
                  fontSize: 16,
                  color: colors.primaryTextColor, // Color del texto
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32), // Espacio entre el texto y los botones

              // Botón para iniciar sesión
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7, // Botón con 70% del ancho
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.appBarColor, // Color de fondo del botón
                  ),
                  child: Text('Iniciar Sesión', style: TextStyle(color: colors.secondaryTextColor),),
                ),
              ),
              const SizedBox(height: 16), // Espacio entre los botones

              // Botón para registrarse
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7, // Botón con 70% del ancho
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.positiveColor, // Color de fondo del botón de registro
                  ),
                  child: Text('Registrarse', style: TextStyle(color: colors.secondaryTextColor),),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
