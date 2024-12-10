import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/services/friends_service.dart';
import 'package:control_gastos/screens/friends/add_friend_screen.dart';
import 'package:control_gastos/screens/friends/pending_requests_screen.dart';
import 'package:control_gastos/screens/friends/blocked_users_screen.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:provider/provider.dart';

class FriendsListScreen extends StatelessWidget {
  final String userId;
  final FriendsService _friendsService = FriendsService();

  FriendsListScreen({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      backgroundColor: colorProvider.colors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Mis Amigos',
          style: TextStyle(color: colorProvider.colors.secondaryTextColor),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        actions: [
          // Botón para ver solicitudes pendientes
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.people_outline,
                  color: colorProvider.colors.secondaryTextColor,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PendingRequestsScreen(userId: userId),
                    ),
                  );
                },
              ),
              // Badge para mostrar solicitudes pendientes
              StreamBuilder<QuerySnapshot>(
                stream: _friendsService.getPendingFriendRequests(userId),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    return Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: colorProvider.colors.positiveColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          snapshot.data!.docs.length.toString(),
                          style: TextStyle(
                            color: colorProvider.colors.secondaryTextColor,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return Container();
                },
              ),
            ],
          ),
          // Botón para ver usuarios bloqueados
          IconButton(
            icon: Icon(
              Icons.block,
              color: colorProvider.colors.secondaryTextColor,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlockedUsersScreen(userId: userId),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<DocumentSnapshot>>(
        stream: _friendsService.getFriendsList(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar amigos',
                style: TextStyle(color: colorProvider.colors.negativeColor),
              ),
            );
          }

          // if (snapshot.connectionState == ConnectionState.waiting) {
          //   return Center(
          //     child: CircularProgressIndicator(
          //       color: colorProvider.colors.appBarColor,
          //     ),
          //   );
          // }

          final friends = snapshot.data ?? [];

          if (friends.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No tienes amigos agregados',
                    style:
                        TextStyle(color: colorProvider.colors.primaryTextColor),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddFriendScreen(userId: userId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorProvider.colors.appBarColor,
                    ),
                    child: Text(
                      'Agregar Amigos',
                      style: TextStyle(
                        color: colorProvider.colors.secondaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friendData = friends[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorProvider.colors.appBarColor,
                  child: Text(
                    friendData['username'][0].toUpperCase(),
                    style: TextStyle(
                      color: colorProvider.colors.secondaryTextColor,
                    ),
                  ),
                ),
                title: Text(
                  friendData['username'],
                  style:
                      TextStyle(color: colorProvider.colors.primaryTextColor),
                ),
                subtitle: Text(
                  'ID: ${friendData['userShortId']}',
                  style: TextStyle(
                    color:
                        colorProvider.colors.primaryTextColor.withOpacity(0.7),
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: colorProvider.colors.primaryTextColor,
                  ),
                  onPressed: () {
                    _showFriendOptions(
                      context,
                      friends[index].id,
                      colorProvider,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddFriendScreen(userId: userId),
            ),
          );
        },
        backgroundColor: colorProvider.colors.appBarColor,
        child: Icon(
          Icons.person_add,
          color: colorProvider.colors.secondaryTextColor,
        ),
      ),
    );
  }

  void _showFriendOptions(
      BuildContext context, String friendId, ColorProvider colorProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colorProvider.colors.backgroundColor,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.person_remove,
                  color: colorProvider.colors.negativeColor,
                ),
                title: Text(
                  'Eliminar Amigo',
                  style:
                      TextStyle(color: colorProvider.colors.primaryTextColor),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _friendsService.removeFriend(userId, friendId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Amigo eliminado correctamente'),
                          backgroundColor: colorProvider.colors.positiveColor,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: colorProvider.colors.negativeColor,
                        ),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.block,
                  color: colorProvider.colors.negativeColor,
                ),
                title: Text(
                  'Bloquear Usuario',
                  style: TextStyle(color: colorProvider.colors.negativeColor),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _friendsService.blockUser(userId, friendId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Usuario bloqueado')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
