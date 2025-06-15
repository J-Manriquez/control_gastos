import 'package:control_gastos/screens/inicio/register_screen.dart';
import 'package:control_gastos/screens/gastos/gastos_screen.dart';
import 'package:control_gastos/screens/inicio/reset_password_screen.dart';
import 'package:control_gastos/services/auth_service.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:control_gastos/widgets/loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores de texto para email y contraseña
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false; // Nueva variable para controlar el estado de carga

  // Instancia de AuthService para usar sus métodos
  final AuthService _authService = AuthService();

  // Método para manejar el inicio de sesión
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ExpenseGroupsScreen(userUid: user.uid),
          ),
        );
      } else {
        // Si falla, muestra un mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al iniciar sesión')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ColorProvider>(context).colors;

    return LoadingOverlay(
      isLoading: _isLoading,
      loadingMessage: 'Iniciando sesión...',
      subtitle: 'Configurando tu cuenta y aplicando actualizaciones',
      child: Scaffold(
        backgroundColor: colors.backgroundColor,
        appBar: AppBar(
          title: const Text('Inicio de Sesión'),
          centerTitle: true,
          backgroundColor: colors.appBarColor,
          titleTextStyle: TextStyle(
              color: colors.secondaryTextColor, fontSize: 20),
          iconTheme: IconThemeData(color: colors.secondaryTextColor),
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
                  suffixIcon: IconButton( // Nuevo IconButton
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: colors.primaryTextColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_isPasswordVisible, // Controlado por _isPasswordVisible
                style: TextStyle(color: colors.primaryTextColor),
              ),
              const SizedBox(height: 32), // Espacio entre los campos y el botón

              // Botón de inicio de sesión modificado
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login, // Deshabilitar durante carga
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.appBarColor,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                colors.secondaryTextColor),
                          ),
                        )
                      : Text(
                          'Iniciar Sesión',
                          style: TextStyle(color: colors.secondaryTextColor),
                        ),
                ),
              ),
              const SizedBox(height: 16), // Espacio entre el botón y el texto
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ResetPasswordScreen()),
                  );
                },
                child: Text(
                  '¿Olvidaste tu contraseña?',
                  style: TextStyle(color: colors.primaryTextColor),
                ),
              ),
              // Enlace de registro
              TextButton(
                onPressed: () {
                  // Navega a la pantalla de registro si el usuario no tiene cuenta
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RegisterScreen()),
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
      ),
    );
  }
}
