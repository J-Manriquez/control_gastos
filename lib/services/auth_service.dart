import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/services/migration_service.dart';
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Instancia de FirebaseAuth para acceder a métodos de autenticación
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String USER_UID_KEY = 'user_uid';

  // Cambiar nombre de usuario
  Future<bool> updateUsername(String uid, String newUsername) async {
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .update({'username': newUsername});
      return true;
    } catch (e) {
      CustomLogger().logError('Error al actualizar nombre de usuario: $e');
      return false;
    }
  }

  // Verificar si el email ha sido actualizado
  Future<bool> isEmailUpdateVerified(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Recargar usuario para obtener la información más reciente
      await user.reload();

      return user.email == newEmail;
    } catch (e) {
      CustomLogger().logError('Error al verificar actualización de email: $e');
      return false;
    }
  }

  // Cambiar email
  Future<bool> updateEmail(String currentPassword, String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return false;

      // Reautenticar usuario
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      // Reautenticar
      await user.reauthenticateWithCredential(credential);

      // Enviar email de verificación y actualizar email
      await user.verifyBeforeUpdateEmail(newEmail);

      // Configurar listener para cambios de auth
      _auth.authStateChanges().listen((User? updatedUser) async {
        if (updatedUser != null && updatedUser.email == newEmail) {
          // El email ha sido verificado y actualizado, ahora actualizamos Firestore
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .update({'email': newEmail});
          CustomLogger()
              .logInfo('Email actualizado correctamente en Firestore');
        }
      });

      CustomLogger().logInfo('Email de verificación enviado correctamente');
      return true;
    } catch (e) {
      CustomLogger().logError('Error al actualizar email: $e');
      rethrow;
    }
  }

  // Cambiar contraseña
  Future<bool> updatePassword(
      String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Reautenticar usuario
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Cambiar contraseña
      await user.updatePassword(newPassword);
      return true;
    } catch (e) {
      CustomLogger().logError('Error al actualizar contraseña: $e');
      return false;
    }
  }

  // Eliminar cuenta
  Future<bool> deleteAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Reautenticar usuario
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Eliminar datos de Firestore
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .delete();

      // Eliminar cuenta de Authentication
      await user.delete();
      return true;
    } catch (e) {
      CustomLogger().logError('Error al eliminar cuenta: $e');
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      CustomLogger().logInfo(
          'Iniciando proceso de restablecimiento de contraseña para: $email');
      await _auth.sendPasswordResetEmail(email: email);
      CustomLogger().logInfo('Email de restablecimiento enviado exitosamente');
      return true;
    } catch (e) {
      CustomLogger().logError('Error al enviar email de restablecimiento: $e');
      return false;
    }
  }

  // Método para guardar el UID del usuario
  Future<void> saveUserSession(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(USER_UID_KEY, uid);
  }

  // Método para obtener el UID del usuario guardado
  Future<String?> getSavedUserUID() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(USER_UID_KEY);
  }

  // Método para cerrar sesión
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(USER_UID_KEY);
    await _auth.signOut();
  }

  // Método para registrar un nuevo usuario con email y contraseña
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      // Intento de creación de usuario con email y contraseña
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
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

  Future<bool> verifyAndRefreshToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Verificar si el token necesita renovación
      IdTokenResult tokenResult = await user.getIdTokenResult(true);
      DateTime expirationTime = tokenResult.expirationTime!;

      // Si el token expira en menos de 5 minutos, renovarlo
      if (expirationTime.difference(DateTime.now()).inMinutes < 5) {
        await user.getIdToken(true); // Fuerza renovación del token
        CustomLogger().logInfo('Token renovado exitosamente');
      }

      return true;
    } catch (e) {
      CustomLogger().logError('Error al verificar/renovar token: $e');
      return false;
    }
  }

  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        // Inicializar Firestore con manejo de errores
        try {
          await FirestoreService().initializePostAuth();
        } catch (e) {
          CustomLogger().logError('Error al inicializar Firestore: $e');
          // Continuar con el proceso de login a pesar del error
        }

        // Verificar y renovar token con manejo de errores
        try {
          await verifyAndRefreshToken();
        } catch (e) {
          CustomLogger().logError('Error al verificar token: $e');
          // Continuar con el proceso de login a pesar del error
        }

        // Ejecutar migración si es necesario con manejo de errores
        try {
          await MigrationService().migrateUserIfNeeded(user.uid);
        } catch (e) {
          CustomLogger().logError('Error en migración: $e');
          // No propagar el error de migración para permitir el login
        }

        // Guardar la sesión
        await saveUserSession(user.uid);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      CustomLogger().logError("Error al iniciar sesión: ${e.message}");
      return null;
    }
  }

  // Método actualizado para cerrar sesión
  Future<void> signOut() async {
    try {
      CustomLogger().logInfo('Iniciando proceso de cierre de sesión');

      // Limpiar SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Limpia todas las preferencias
      // O si prefieres ser más específico:
      // await prefs.remove(USER_UID_KEY);

      // Cerrar sesión en Firebase
      await _auth.signOut();

      CustomLogger().logInfo('Sesión cerrada exitosamente');
    } catch (e) {
      CustomLogger().logError('Error al cerrar sesión: $e');
      throw Exception('Error al cerrar sesión: $e');
    }
  }

  // Método para obtener el usuario actualmente autenticado
  User? get currentUser => _auth.currentUser;
}
