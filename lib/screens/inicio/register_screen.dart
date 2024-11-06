import 'package:control_gastos/screens/inicio/welcome_screen.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa Firestore
import '../../services/auth_service.dart';
import 'package:provider/provider.dart'; // Importa el paquete Provider para gestionar colores

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
    } else {
      // Mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al registrar usuario')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ColorProvider>(context).colors; // Obtiene los colores del provider

    return Scaffold(
      backgroundColor: colors.backgroundColor, // Aplica el color de fondo
      appBar: AppBar(
        title: const Text('Registro de Usuario'),
        centerTitle: true,
        backgroundColor: colors.appBarColor, // Color de AppBar
        titleTextStyle: TextStyle(color: colors.secondaryTextColor, fontSize: 20), // Color del texto del AppBar
        iconTheme: IconThemeData(color: colors.secondaryTextColor), // Color de los iconos del AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Campo de nombre de usuario
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Nombre de usuario',
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

            // Botón de registro
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.7, // Botón con 70% del ancho
              child: ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.positiveColor, // Color de fondo del botón
                ),
                child: Text(
                  'Registrar',
                  style: TextStyle(color: colors.secondaryTextColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
