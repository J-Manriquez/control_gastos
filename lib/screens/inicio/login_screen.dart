import 'package:control_gastos/screens/gastos/gastos_screen.dart';
import 'package:control_gastos/screens/inicio/register_screen.dart';
import 'package:control_gastos/services/auth_service.dart';
import 'package:flutter/material.dart';

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
      String userUid = user.uid; // Obtén el userUid del objeto user

      // Si el inicio de sesión es exitoso, muestra un mensaje o navega a la pantalla principal
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicio de sesión exitoso')),
      );

      // Navega a ExpenseGroupsScreen y pasa el userUid
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExpenseGroupsScreen(userUid: userUid),
        ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio de Sesión')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text('Iniciar Sesión'),
            ),
            TextButton(
              onPressed: () {
                // Navega a la pantalla de registro si el usuario no tiene cuenta
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                );
              },
              child: const Text('¿No tienes cuenta? Regístrate aquí'),
            ),
          ],
        ),
      ),
    );
  }
}
