import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';

enum LoadingType {
  general,
  notifications,
  payment,
  sync,
}

class LoadingScreen extends StatelessWidget {
  final String message;
  final String? subtitle;
  final bool showProgress;
  final double? progress; // Para progreso determinado (0.0 - 1.0)
  final LoadingType type;

  const LoadingScreen({
    Key? key,
    required this.message,
    this.subtitle,
    this.showProgress = true,
    this.progress,
    this.type = LoadingType.general,
  }) : super(key: key);

  // Constructor específico para notificaciones
  const LoadingScreen.notifications({
    Key? key,
    this.message = 'Procesando notificación...',
    this.subtitle = 'Por favor espera mientras procesamos tu solicitud',
    this.showProgress = true,
    this.progress,
  }) : type = LoadingType.notifications, super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ColorProvider>(context).colors;

    // Configuración específica según el tipo
    IconData icon;
    Color iconColor;
    
    switch (type) {
      case LoadingType.notifications:
        icon = Icons.notifications_active;
        iconColor = colors.appBarColor;
        break;
      case LoadingType.payment:
        icon = Icons.payment;
        iconColor = colors.positiveColor;
        break;
      case LoadingType.sync:
        icon = Icons.sync;
        iconColor = colors.appBarColor;
        break;
      case LoadingType.general:
      default:
        icon = Icons.account_balance_wallet;
        iconColor = colors.appBarColor;
        break;
    }

    return Scaffold(
      backgroundColor: colors.backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono dinámico según el tipo
              Icon(
                icon,
                size: 80,
                color: iconColor,
              ),
              const SizedBox(height: 32),
              
              // Mensaje principal
              Text(
                message,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              
              if (subtitle != null) ...[
                const SizedBox(height: 16),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 16,
                    color: colors.primaryTextColor.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Indicador de progreso
              if (showProgress) ...[
                SizedBox(
                  width: 200,
                  child: progress != null
                      ? LinearProgressIndicator(
                          value: progress,
                          backgroundColor: colors.primaryTextColor.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(colors.appBarColor),
                        )
                      : LinearProgressIndicator(
                          backgroundColor: colors.primaryTextColor.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(colors.appBarColor),
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Por favor espera...',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.primaryTextColor.withOpacity(0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Widget para overlay de carga sobre contenido existente
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String loadingMessage;
  final String? subtitle;
  final LoadingType type;

  const LoadingOverlay({
    Key? key,
    required this.child,
    required this.isLoading,
    this.loadingMessage = 'Cargando...',
    this.subtitle,
    this.type = LoadingType.general,
  }) : super(key: key);

  // Constructor específico para notificaciones
  const LoadingOverlay.notifications({
    super.key,
    required this.child,
    required this.isLoading,
    this.loadingMessage = 'Procesando notificación...',
    this.subtitle = 'Por favor espera mientras procesamos tu solicitud',
  }) : type = LoadingType.notifications;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: LoadingScreen(
              message: loadingMessage,
              subtitle: subtitle,
              type: type,
            ),
          ),
      ],
    );
  }
}