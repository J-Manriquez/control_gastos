import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/services/payment_polling_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/models/subscription_model.dart';
import 'package:control_gastos/models/user_model.dart'; // Asegúrate de que este import sea correcto
import 'package:control_gastos/services/auth_service.dart';
import 'package:control_gastos/services/mercado_pago_service.dart';
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:control_gastos/widgets/payment_webview.dart'; // Asegúrate de que este import sea correcto

class SubscriptionRestrictionModal extends StatefulWidget {
  final String userId;
  // Se necesita el ID del usuario para las operaciones

  const SubscriptionRestrictionModal({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<SubscriptionRestrictionModal> createState() =>
      _SubscriptionRestrictionModalState();
}

class _SubscriptionRestrictionModalState
    extends State<SubscriptionRestrictionModal> {
  bool _isProcessingPayment = false;

  // --- Lógica de Procesamiento de Pago ---

  void _handleUserUpgrade(bool hasAccess) {
    if (hasAccess) {
      Navigator.of(context).pop(); // Cerrar modal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 ¡Suscripción activada exitosamente!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _handlePaymentResult(String result) {
    print('📋 Resultado del WebView: $result');

    if (result == 'success') {
      // El webhook se encargará de actualizar el usuario
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏳ Procesando pago... Por favor espera'),
          backgroundColor: Colors.orange,
        ),
      );
    } else if (result == 'failure') {
      PaymentPollingService.stopListening();
      _showError('Pago cancelado o rechazado');
    }
  }

  // En el método _handleUpgrade, cambiar:
  Future<void> _handleUpgrade(SubscriptionPlan plan) async {
    print('🎯 Iniciando proceso de pago para: ${plan.type}');
    setState(() {
      _isProcessingPayment = true;
    });
  
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }
      
      // ✅ CORRECCIÓN: Mapear correctamente el tipo de plan
      String planTypeString;
      switch (plan.type) {
        case SubscriptionType.proMonthly:
          planTypeString = 'monthly';
          break;
        case SubscriptionType.proAnnual:
          planTypeString = 'annual';
          break;
        default:
          planTypeString = 'monthly';
      }
      
      final preference = await MercadoPagoService.createPaymentPreference(
        title: plan.name,
        price: plan.price.toDouble(), // ✅ Convertir a double
        userEmail: user.email!,
        userId: widget.userId,
        planType: planTypeString, // ✅ Usar string correcto
      );
      
      if (preference != null) {
        // Iniciar escucha de cambios en el usuario
        PaymentPollingService.startListeningUserChanges(
          widget.userId,
          _handleUserUpgrade,
        );

        // Navegar a WebView
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebView(
              paymentUrl:
                  preference['sandbox_init_point'] ?? preference['init_point'],
              planType: plan.type == SubscriptionType.proMonthly
                  ? 'monthly'
                  : 'annual',
              onPaymentResult: _handlePaymentResult,
            ),
          ),
        );
      } else {
        _showError('Error al crear la preferencia de pago');
      }
    } catch (e) {
      print('💥 Error en upgrade: $e');
      _showError('Error inesperado: $e');
    } finally {
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- Lógica de Eliminación de Cuenta ---

  void _showDeleteAccountConfirmation(BuildContext context) {
    print(
        '⚠️ SubscriptionRestrictionModal: Mostrando confirmación de eliminación');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar cuenta?'),
        content: const Text(
          'Esta acción no se puede deshacer. Se eliminarán todos tus datos permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              print('❌ SubscriptionRestrictionModal: Eliminación cancelada');
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              print('✅ SubscriptionRestrictionModal: Eliminación confirmada');
              Navigator.pop(context);
              _deleteAccount(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _deleteAccount(BuildContext context) async {
    print('🗑️ SubscriptionRestrictionModal: Iniciando eliminación de cuenta');
    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await AuthService().deleteAccount2();
      print('✅ SubscriptionRestrictionModal: Cuenta eliminada exitosamente');

      if (!mounted) return;
      // Cerrar loading y navegar a welcome
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    } catch (e) {
      print('💥 SubscriptionRestrictionModal: Error al eliminar cuenta: $e');
      Navigator.pop(context); // Cerrar loading
      CustomLogger().logError('Error al eliminar cuenta: $e');

      _showError('Error al eliminar la cuenta: $e');
    }
  }

  // --- Construcción del Widget ---

  @override
  Widget build(BuildContext context) {
    print(
        '🚫 SubscriptionRestrictionModal: build() - Modal de restricción mostrado');

    return WillPopScope(
      onWillPop: () async {
        print(
            '🚫 SubscriptionRestrictionModal: Intento de cerrar modal bloqueado');
        return false; // Prevenir que se cierre el modal
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.white,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono y título
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.access_time,
                  size: 48,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '¡Prueba gratuita finalizada!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Tu período de prueba de 14 días ha terminado. Para continuar usando la aplicación, elige una de las siguientes opciones:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Contenido condicional: Loading o Planes
              if (_isProcessingPayment) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                const Text(
                  'Redirigiendo a la pasarela de pago...',
                  textAlign: TextAlign.center,
                )
              ] else ...[
                // Planes de suscripción
                ...SubscriptionPlan.availablePlans
                    .map((plan) => _buildPlanCard(context, plan))
                    .toList(),

                const SizedBox(height: 20),

                // Divider
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: 16),

                // Opción de eliminar cuenta
                Text(
                  'O si prefieres:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      print(
                          '🗑️ SubscriptionRestrictionModal: Botón eliminar cuenta presionado');
                      _showDeleteAccountConfirmation(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Eliminar mi cuenta',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, SubscriptionPlan plan) {
    final isAnnual = plan.type == SubscriptionType.proAnnual;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: isAnnual ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isAnnual ? Colors.green.shade300 : Colors.grey.shade300,
            width: isAnnual ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            print(
                '💳 SubscriptionRestrictionModal: Plan seleccionado: ${plan.name}');
            _handleUpgrade(plan); // <--- Llama a la nueva función de pago
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isAnnual
                                  ? Colors.green.shade700
                                  : Colors.blue.shade700,
                            ),
                          ),
                          if (isAnnual) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'MEJOR VALOR',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${plan.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isAnnual
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                    Text(
                      isAnnual ? '/año' : '/mes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
