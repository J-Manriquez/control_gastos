import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/services/friends_service.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:provider/provider.dart';

class BlockedUsersScreen extends StatelessWidget {
  final String userId;
  final FriendsService _friendsService = FriendsService();

  BlockedUsersScreen({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      backgroundColor: colorProvider.colors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Usuarios Bloqueados',
          style: TextStyle(color: colorProvider.colors.secondaryTextColor),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme: IconThemeData(color: colorProvider.colors.secondaryTextColor),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _friendsService.getBlockedUsers(userId),
        builder: (context, snapshot) {
          // Manejar error
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: colorProvider.colors.negativeColor,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar usuarios bloqueados',
                    style: TextStyle(color: colorProvider.colors.negativeColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Manejar estado de carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: colorProvider.colors.appBarColor,
              ),
            );
          }

          // Obtener usuarios bloqueados
          final blockedUsers = snapshot.data?.docs ?? [];

          // Mostrar mensaje cuando no hay usuarios bloqueados
          if (blockedUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.block_outlined,
                    color: colorProvider.colors.primaryTextColor.withOpacity(0.5),
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay usuarios bloqueados',
                    style: TextStyle(
                      color: colorProvider.colors.primaryTextColor,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Mostrar lista de usuarios bloqueados
          return ListView.builder(
            itemCount: blockedUsers.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final userData = blockedUsers[index].data() as Map<String, dynamic>;
              final username = userData['username'] as String? ?? 'Usuario';
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                color: colorProvider.colors.backgroundColor,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: colorProvider.colors.negativeColor,
                    child: Text(
                      username[0].toUpperCase(),
                      style: TextStyle(
                        color: colorProvider.colors.secondaryTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    username,
                    style: TextStyle(
                      color: colorProvider.colors.primaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${userData['userShortId'] ?? ''}',
                        style: TextStyle(
                          color: colorProvider.colors.primaryTextColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  trailing: ElevatedButton.icon(
                    icon: Icon(
                      Icons.person_add,
                      color: colorProvider.colors.secondaryTextColor,
                      size: 20,
                    ),
                    label: Text(
                      'Desbloquear',
                      style: TextStyle(
                        color: colorProvider.colors.secondaryTextColor,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorProvider.colors.positiveColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => _showUnblockConfirmation(
                      context,
                      blockedUsers[index].id,
                      username,
                      colorProvider,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showUnblockConfirmation(
    BuildContext context,
    String blockedUserId,
    String username,
    ColorProvider colorProvider,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colorProvider.colors.backgroundColor,
          title: Text(
            'Desbloquear Usuario',
            style: TextStyle(
              color: colorProvider.colors.primaryTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de que deseas desbloquear a este usuario?',
                style: TextStyle(color: colorProvider.colors.primaryTextColor),
              ),
              const SizedBox(height: 12),
              Text(
                username,
                style: TextStyle(
                  color: colorProvider.colors.primaryTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(color: colorProvider.colors.appBarColor),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  Navigator.of(context).pop();
                  
                  // Mostrar indicador de carga
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: colorProvider.colors.appBarColor,
                          ),
                        );
                      },
                    );
                  }

                  await _friendsService.unblockUser(userId, blockedUserId);
                  
                  // Cerrar el indicador de carga
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Usuario desbloqueado exitosamente',
                          style: TextStyle(
                            color: colorProvider.colors.secondaryTextColor,
                          ),
                        ),
                        backgroundColor: colorProvider.colors.positiveColor,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  // Cerrar el indicador de carga si está visible
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error al desbloquear usuario: ${e.toString()}',
                          style: TextStyle(
                            color: colorProvider.colors.secondaryTextColor,
                          ),
                        ),
                        backgroundColor: colorProvider.colors.negativeColor,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorProvider.colors.positiveColor,
              ),
              child: Text(
                'Desbloquear',
                style: TextStyle(
                  color: colorProvider.colors.secondaryTextColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}