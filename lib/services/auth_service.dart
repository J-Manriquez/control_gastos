import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Instancia de FirebaseAuth para acceder a métodos de autenticación
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Método para registrar un nuevo usuario con email y contraseña
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      // Intento de creación de usuario con email y contraseña
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Devuelve el usuario creado en caso de éxito
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      // En caso de error, imprime el mensaje y devuelve null
      print("Error al registrar el usuario: ${e.message}");
      return null;
    }
  }

  // Método para iniciar sesión con email y contraseña
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      // Intento de autenticación con email y contraseña
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Devuelve el usuario autenticado en caso de éxito
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      // En caso de error, imprime el mensaje y devuelve null
      print("Error al iniciar sesión: ${e.message}");
      return null;
    }
  }

  // Método para cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Método para obtener el usuario actualmente autenticado
  User? get currentUser => _auth.currentUser;
}
