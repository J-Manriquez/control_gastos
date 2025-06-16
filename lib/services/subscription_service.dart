import 'package:control_gastos/models/user_model.dart';
import 'package:control_gastos/models/subscription_model.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class SubscriptionService {
  static const int freeTrialDays = 14;
  final CustomLogger _logger = CustomLogger();

  /// Verifica si el usuario tiene acceso a la aplicación
  bool hasAccess(UserModel user) {
    print('🔐 SubscriptionService: hasAccess() - Verificando acceso para usuario');
    print('   - userType: ${user.userType}');
    print('   - creationDate: ${user.creationDate}');
    
    if (user.userType != 'free') {
      print('✅ SubscriptionService: Usuario PRO detectado - acceso completo');
      return true; // Usuario pro tiene acceso completo
    }

    // Usuario free: verificar si está dentro del período de prueba
    final daysSinceCreation = DateTime.now().difference(user.creationDate).inDays;
    final hasAccessResult = daysSinceCreation <= freeTrialDays;
    
    print('📅 SubscriptionService: Usuario FREE:');
    print('   - daysSinceCreation: $daysSinceCreation');
    print('   - freeTrialDays: $freeTrialDays');
    print('   - hasAccess: $hasAccessResult');
    
    return hasAccessResult;
  }

  /// Obtiene los días restantes de la prueba gratuita
  int getRemainingTrialDays(UserModel user) {
    print('📊 SubscriptionService: getRemainingTrialDays() - Calculando días restantes');
    
    if (user.userType != 'free') {
      print('   - Usuario PRO: no aplica');
      return -1; // No aplica para usuarios pro
    }

    final daysSinceCreation = DateTime.now().difference(user.creationDate).inDays;
    final remainingDays = freeTrialDays - daysSinceCreation;
    final result = remainingDays > 0 ? remainingDays : 0;
    
    print('   - daysSinceCreation: $daysSinceCreation');
    print('   - remainingDays: $result');
    
    return result;
  }

  /// Verifica si la prueba gratuita ha expirado
  bool isTrialExpired(UserModel user) {
    print('⏰ SubscriptionService: isTrialExpired() - Verificando expiración');
    
    if (user.userType != 'free') {
      print('   - Usuario PRO: no expira');
      return false;
    }

    final daysSinceCreation = DateTime.now().difference(user.creationDate).inDays;
    final isExpired = daysSinceCreation > freeTrialDays;
    
    print('   - daysSinceCreation: $daysSinceCreation');
    print('   - isExpired: $isExpired');
    
    return isExpired;
  }

  /// Obtiene el estado de la suscripción como texto
  String getSubscriptionStatus(UserModel user) {
    if (user.userType == 'proMonthly') {
      return 'Pro Mensual';
    } else if (user.userType == 'proAnnual') {
      return 'Pro Anual';
    } else {
      final remainingDays = getRemainingTrialDays(user);
      if (remainingDays > 0) {
        return 'Prueba gratuita ($remainingDays días restantes)';
      } else {
        return 'Prueba gratuita expirada';
      }
    }
  }
}