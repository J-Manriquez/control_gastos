import 'package:flutter/material.dart';
import 'package:control_gastos/models/subscription_model.dart';
import 'package:control_gastos/services/auth_service.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class SubscriptionRestrictionModal extends StatelessWidget {
  final VoidCallback? onDeleteAccount;
  final Function(SubscriptionPlan)? onSelectPlan;

  const SubscriptionRestrictionModal({
    Key? key,
    this.onDeleteAccount,
    this.onSelectPlan,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('🚫 SubscriptionRestrictionModal: build() - Modal de restricción mostrado');
    
    return WillPopScope(
      onWillPop: () async {
        print('🚫 SubscriptionRestrictionModal: Intento de cerrar modal bloqueado');
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
              
              // Planes de suscripción
              ...SubscriptionPlan.availablePlans.map((plan) => 
                _buildPlanCard(context, plan)
              ).toList(),
              
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
                    print('🗑️ SubscriptionRestrictionModal: Botón eliminar cuenta presionado');
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
            print('💳 SubscriptionRestrictionModal: Plan seleccionado: ${plan.name}');
            onSelectPlan?.call(plan);
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
                              color: isAnnual ? Colors.green.shade700 : Colors.blue.shade700,
                            ),
                          ),
                          if (isAnnual) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                        color: isAnnual ? Colors.green.shade700 : Colors.blue.shade700,
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

  void _showDeleteAccountConfirmation(BuildContext context) {
    print('⚠️ SubscriptionRestrictionModal: Mostrando confirmación de eliminación');
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
      
      // Cerrar loading y navegar a welcome
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    } catch (e) {
      print('💥 SubscriptionRestrictionModal: Error al eliminar cuenta: $e');
      Navigator.pop(context); // Cerrar loading
      CustomLogger().logError('Error al eliminar cuenta: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar la cuenta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}