import 'package:control_gastos/screens/inicio/register_screen.dart';
import 'package:control_gastos/services/auth_service.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Importa el paquete Provider para gestionar colores

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores de texto para email y contraseña
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Instancia de AuthService para usar sus métodos
  final AuthService _authService = AuthService();

  // Método para manejar el inicio de sesión
  Future<void> _login() async {
    String email = _emailController.text;
    String password = _passwordController.text;

    // Llama al método de inicio de sesión y captura el usuario si es exitoso
    var user = await _authService.loginWithEmail(email, password);

    // Verifica si el usuario fue autenticado
    if (user != null) {
      // Si el inicio de sesión es exitoso, muestra un mensaje o navega a la pantalla principal
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicio de sesión exitoso')),
      );

      // Navega a ExpenseGroupsScreen y pasa el userUid
      // Usar pushReplacement para evitar que el usuario pueda volver atrás
      Navigator.pushReplacementNamed(
        context,
        '/home',
      );
    } else {
      // Si falla, muestra un mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al iniciar sesión')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ColorProvider>(context).colors; // Obtiene los colores del provider

    return Scaffold(
      backgroundColor: colors.backgroundColor, // Aplica el color de fondo
      appBar: AppBar(
        title: const Text('Inicio de Sesión'),
        centerTitle: true,
        backgroundColor: colors.appBarColor, // Color de AppBar
        titleTextStyle: TextStyle(color: colors.secondaryTextColor, fontSize: 20), // Color del texto del AppBar
        iconTheme: IconThemeData(color: colors.secondaryTextColor), // Color de los iconos del AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Campo de email
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: colors.primaryTextColor),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.appBarColor),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.primaryTextColor),
                ),
              ),
              style: TextStyle(color: colors.primaryTextColor),
            ),
            const SizedBox(height: 16), // Espacio entre los campos

            // Campo de contraseña
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                labelStyle: TextStyle(color: colors.primaryTextColor),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.appBarColor),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.primaryTextColor),
                ),
              ),
              obscureText: true,
              style: TextStyle(color: colors.primaryTextColor),
            ),
            const SizedBox(height: 32), // Espacio entre los campos y el botón

            // Botón de inicio de sesión
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.7, // Botón con 70% del ancho
              child: ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.appBarColor, // Color de fondo del botón
                ),
                child: Text(
                  'Iniciar Sesión',
                  style: TextStyle(color: colors.secondaryTextColor),
                ),
              ),
            ),
            const SizedBox(height: 16), // Espacio entre el botón y el texto

            // Enlace de registro
            TextButton(
              onPressed: () {
                // Navega a la pantalla de registro si el usuario no tiene cuenta
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                );
              },
              child: Text(
                '¿No tienes cuenta? Regístrate aquí',
                style: TextStyle(color: colors.primaryTextColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
