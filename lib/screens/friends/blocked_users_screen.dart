import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/services/friends_service.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:provider/provider.dart';

class BlockedUsersScreen extends StatelessWidget {
  final String userId;
  final FriendsService _friendsService = FriendsService();

  BlockedUsersScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      backgroundColor: colorProvider.colors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Usuarios Bloqueados',
          style: TextStyle(
              color: colorProvider.colors.secondaryTextColor, fontSize: 20),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme:
            IconThemeData(color: colorProvider.colors.secondaryTextColor),
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
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar usuarios bloqueados',
                    style: TextStyle(
                      color: colorProvider.colors.negativeColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
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
                valueColor: AlwaysStoppedAnimation<Color>(
                  colorProvider.colors.appBarColor,
                ),
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
                    color:
                        colorProvider.colors.primaryTextColor.withOpacity(0.5),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay usuarios bloqueados',
                    style: TextStyle(
                      color: colorProvider.colors.primaryTextColor
                          .withOpacity(0.7),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
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
            padding:
                const EdgeInsets.only(left: 0, right: 0, top: 8, bottom: 80),
            itemBuilder: (context, index) {
              final userData =
                  blockedUsers[index].data() as Map<String, dynamic>;
              final username = userData['username'] as String? ?? 'Usuario';
              final userShortId = userData['userShortId'] ?? '';

              return Card(
                margin:
                    const EdgeInsets.only(bottom: 12.0, left: 12, right: 12),
                color: colorProvider.colors.backgroundColor,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: colorProvider.colors.appBarColor,
                    width: 1.5,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: colorProvider.colors.appBarColor,
                    radius: 25,
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: colorProvider.colors.secondaryTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  title: Text(
                    username,
                    style: TextStyle(
                      color: colorProvider.colors.primaryTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    'ID: $userShortId',
                    style: TextStyle(
                      color: colorProvider.colors.primaryTextColor
                          .withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  trailing: Container(
                    decoration: BoxDecoration(
                      color: colorProvider.colors.positiveColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton.icon(
                      icon: Icon(
                        Icons.person_add,
                        color: colorProvider.colors.secondaryTextColor,
                        size: 25,
                      ),
                      label: Text(
                        'Desbloquear',
                        style: TextStyle(
                          color: colorProvider.colors.secondaryTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
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
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: colorProvider.colors.appBarColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  Navigator.of(context).pop();

                  await _friendsService.unblockUser(userId, blockedUserId);

                  if (context.mounted) {
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
                  if (context.mounted) {
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Desbloquear',
                style: TextStyle(
                  color: colorProvider.colors.secondaryTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
