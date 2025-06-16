import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/user_model.dart';
import 'package:control_gastos/models/subscription_model.dart';
import 'package:control_gastos/services/subscription_service.dart';
import 'package:control_gastos/widgets/subscription_restriction_modal.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class AccessControlWrapper extends StatefulWidget {
  final Widget child;
  final String userUid;

  const AccessControlWrapper({
    Key? key,
    required this.child,
    required this.userUid,
  }) : super(key: key);

  @override
  State<AccessControlWrapper> createState() => _AccessControlWrapperState();
}

class _AccessControlWrapperState extends State<AccessControlWrapper> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final CustomLogger _logger = CustomLogger();
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _showRestrictionModal = false;

  @override
  void initState() {
    super.initState();
    print('🔄 AccessControlWrapper: initState() - Iniciando verificación de acceso para usuario: ${widget.userUid}');
    _checkUserAccess();
  }

  Future<UserModel?> _getUserData() async {
    print('📡 AccessControlWrapper: _getUserData() - Obteniendo datos del usuario: ${widget.userUid}');
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.userUid)
          .get();

      print('📄 AccessControlWrapper: Documento obtenido - exists: ${doc.exists}');
      
      if (doc.exists) {
        final userData = doc.data() as Map<String, dynamic>;
        print('📋 AccessControlWrapper: Datos del usuario: $userData');
        
        final user = UserModel.fromMap(userData);
        print('👤 AccessControlWrapper: Usuario creado - userType: ${user.userType}, creationDate: ${user.creationDate}');
        
        return user;
      } else {
        print('❌ AccessControlWrapper: Documento del usuario no existe');
        return null;
      }
    } catch (e) {
      print('💥 AccessControlWrapper: Error al obtener datos del usuario: $e');
      return null;
    }
  }

  Future<void> _checkUserAccess() async {
    print('🔍 AccessControlWrapper: _checkUserAccess() - Iniciando verificación');
    try {
      final user = await _getUserData();
      
      if (user == null) {
        print('⚠️ AccessControlWrapper: Usuario es null, mostrando modal por seguridad');
        setState(() {
          _currentUser = null;
          _isLoading = false;
          _showRestrictionModal = true;
        });
        return;
      }

      print('✅ AccessControlWrapper: Usuario obtenido correctamente');
      print('📊 AccessControlWrapper: Verificando acceso...');
      
      final hasAccess = _subscriptionService.hasAccess(user);
      final isTrialExpired = _subscriptionService.isTrialExpired(user);
      final remainingDays = _subscriptionService.getRemainingTrialDays(user);
      
      print('🔐 AccessControlWrapper: Resultados de verificación:');
      print('   - userType: ${user.userType}');
      print('   - hasAccess: $hasAccess');
      print('   - isTrialExpired: $isTrialExpired');
      print('   - remainingDays: $remainingDays');
      print('   - creationDate: ${user.creationDate}');
      print('   - daysSinceCreation: ${DateTime.now().difference(user.creationDate).inDays}');
      
      setState(() {
        _currentUser = user;
        _isLoading = false;
        _showRestrictionModal = !hasAccess;
      });

      print('🎯 AccessControlWrapper: Estado actualizado - showModal: $_showRestrictionModal');
      
      _logger.logInfo('Usuario verificado: ${user.userType}, acceso: $hasAccess');
    } catch (e) {
      print('💥 AccessControlWrapper: Error en _checkUserAccess: $e');
      _logger.logError('Error al verificar acceso del usuario: $e');
      setState(() {
        _isLoading = false;
        _showRestrictionModal = true; // Por seguridad, mostrar restricción si hay error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 AccessControlWrapper: build() - isLoading: $_isLoading, showModal: $_showRestrictionModal');
    
    if (_isLoading) {
      print('⏳ AccessControlWrapper: Mostrando pantalla de carga');
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    print('🏗️ AccessControlWrapper: Construyendo Stack con modal: $_showRestrictionModal');
    
    return Stack(
      children: [
        widget.child,
        if (_showRestrictionModal) ...[
          Container(
            color: Colors.black54,
            child: Center(
              child: SubscriptionRestrictionModal(
                onSelectPlan: _handlePlanSelection,
                onDeleteAccount: _handleDeleteAccount,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _handlePlanSelection(SubscriptionPlan plan) {
    print('💳 AccessControlWrapper: Plan seleccionado: ${plan.name}');
    _logger.logInfo('Plan seleccionado: ${plan.name}');
    // TODO: Implementar navegación a la pasarela de pagos
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Redirigiendo a pago para ${plan.name}...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _handleDeleteAccount() {
    print('🗑️ AccessControlWrapper: Usuario eligió eliminar cuenta');
    _logger.logInfo('Usuario eligió eliminar cuenta');
    // La lógica de eliminación se maneja en el modal
  }
}