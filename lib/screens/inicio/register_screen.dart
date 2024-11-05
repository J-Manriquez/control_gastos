import 'package:control_gastos/screens/inicio/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa Firestore
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores de texto para email, contraseña y nombre de usuario
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  // Instancia de AuthService para usar sus métodos
  final AuthService _authService = AuthService();

  // Instancia de Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Método para manejar el registro de usuario
  Future<void> _register() async {
    String email = _emailController.text;
    String password = _passwordController.text;
    String username = _usernameController.text;

    // Llama al método de registro de AuthService y captura el usuario si es exitoso
    var user = await _authService.registerWithEmail(email, password);

    if (user != null) {
      // Obtiene la fecha actual
      DateTime creationDate = DateTime.now();

      // Crea el documento de usuario en Firestore
      await _firestore.collection('usuarios').doc(user.uid).set({
        'username': username,
        'email': email,
        'creationDate': creationDate,
        'userType': 'free', // Tipo de usuario por defecto
        'expenseGroups': [], // Lista vacía para los grupos de gastos
      });

      // Mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario registrado con éxito')),
      );

      // Navega de vuelta a la pantalla de bienvenida
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => WelcomeScreen()),
      );
      // Si necesitas asegurar que la pantalla de bienvenida se muestre correctamente, puedes hacer uso de Navigator.pushReplacement
    } else {
      // Mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al registrar usuario')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de Usuario')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Nombre de usuario'),
            ),
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
              onPressed: _register,
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }
}
