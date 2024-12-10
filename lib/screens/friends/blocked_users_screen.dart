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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _friendsService.getBlockedUsers(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar usuarios bloqueados',
                style: TextStyle(color: colorProvider.colors.negativeColor),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: colorProvider.colors.appBarColor,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No hay usuarios bloqueados',
                style: TextStyle(color: colorProvider.colors.primaryTextColor),
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final blockedUser = snapshot.data!.docs[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(blockedUser['userId'])
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorProvider.colors.negativeColor,
                      child: Text(
                        userData['username'][0].toUpperCase(),
                        style: TextStyle(
                          color: colorProvider.colors.secondaryTextColor,
                        ),
                      ),
                    ),
                    title: Text(
                      userData['username'],
                      style: TextStyle(color: colorProvider.colors.primaryTextColor),
                    ),
                    subtitle: Text(
                      'ID: ${userData['userShortId']}',
                      style: TextStyle(
                        color: colorProvider.colors.primaryTextColor.withOpacity(0.7),
                      ),
                    ),
                    trailing: TextButton.icon(
                      icon: Icon(
                        Icons.person_add,
                        color: colorProvider.colors.positiveColor,
                      ),
                      label: Text(
                        'Desbloquear',
                        style: TextStyle(
                          color: colorProvider.colors.positiveColor,
                        ),
                      ),
                      onPressed: () => _showUnblockConfirmation(
                        context,
                        blockedUser['userId'],
                        userData['username'],
                        colorProvider,
                      ),
                    ),
                  );
                },
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
            style: TextStyle(color: colorProvider.colors.primaryTextColor),
          ),
          content: Text(
            '¿Estás seguro de que deseas desbloquear a $username?',
            style: TextStyle(color: colorProvider.colors.primaryTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(color: colorProvider.colors.appBarColor),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _friendsService.unblockUser(userId, blockedUserId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Usuario desbloqueado')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
              child: Text(
                'Desbloquear',
                style: TextStyle(color: colorProvider.colors.positiveColor),
              ),
            ),
          ],
        );
      },
    );
  }
}