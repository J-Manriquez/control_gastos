import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/widgets/expense_drawer.dart';
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

  FriendsListScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      backgroundColor: colorProvider.colors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Mis Amigos',
          style: TextStyle(
              color: colorProvider.colors.secondaryTextColor, fontSize: 20),
        ),
        iconTheme: IconThemeData(
          size: 30,
          color: colorProvider
              .colors.secondaryTextColor, // Cambia aquí el color de la flecha
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _friendsService.getPendingFriendRequests(userId),
            builder: (context, snapshot) {
              final pendingCount =
                  snapshot.hasData ? snapshot.data!.docs.length : 0;

              return Stack(
                alignment: Alignment.center,
                children: [
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: colorProvider.colors.secondaryTextColor,
                    ),
                    onSelected: (String value) {
                      switch (value) {
                        case 'pending':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PendingRequestsScreen(userId: userId),
                            ),
                          );
                          break;
                        case 'blocked':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  BlockedUsersScreen(userId: userId),
                            ),
                          );
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return [
                        PopupMenuItem<String>(
                          value: 'pending',
                          child: Container(
                            decoration: BoxDecoration(
                              color: pendingCount > 0
                                  ? colorProvider.colors.positiveColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      color: pendingCount > 0
                                          ? Colors.white
                                          : colorProvider.colors.primaryTextColor,
                                          size: 30,
                                    ),
                                    // if (pendingCount > 0)
                                    //   Positioned(
                                    //     right: -2,
                                    //     top: -2,
                                    //     child: Container(
                                    //       padding: const EdgeInsets.all(2),
                                    //       decoration: BoxDecoration(
                                    //         color: Colors.transparent,
                                    //         borderRadius:
                                    //             BorderRadius.circular(8),
                                    //       ),
                                    //       constraints: const BoxConstraints(
                                    //         minWidth: 12,
                                    //         minHeight: 12,
                                    //       ),
                                    //       child: Text(
                                    //         pendingCount.toString(),
                                    //         style: TextStyle(
                                    //           color: colorProvider
                                    //               .colors.secondaryTextColor,
                                    //           fontSize: 15,
                                    //           fontWeight: FontWeight.bold,
                                    //         ),
                                    //         textAlign: TextAlign.center,
                                    //       ),
                                    //     ),
                                    //   ),
                                  
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Solicitudes Pendientes (${ pendingCount.toString()})',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: pendingCount > 0
                                        ? Colors.white
                                        : colorProvider.colors.primaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'blocked',
                          child: Container(
                            decoration: BoxDecoration(
                              color: pendingCount > 0
                                  ? colorProvider.colors.negativeColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child:Row(
                            children: [
                              Icon(
                                Icons.block,
                                color: colorProvider.colors.secondaryTextColor,
                                size: 30,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Usuarios Bloqueados',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colorProvider.colors.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                          ),
                        ),
                      ];
                    },
                    color: colorProvider.colors.backgroundColor,
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(8),
                       side: BorderSide(
                         color: colorProvider.colors.appBarColor,
                         width: 1.5,
                       ),
                     ),
                     offset: const Offset(0, 40),
                  ),
                  if (pendingCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colorProvider.colors.positiveColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          pendingCount.toString(),
                          style: TextStyle(
                            color: colorProvider.colors.secondaryTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          )
        ],
      ),
      drawer: ExpenseDrawer(userUid: userId),
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

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: colorProvider.colors.appBarColor,
              ),
            );
          }

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
            padding:
                const EdgeInsets.only(left: 0, right: 0, top: 8, bottom: 80),
            itemBuilder: (context, index) {
              final friendData = friends[index].data() as Map<String, dynamic>;
              return Card(
                color: Colors.white,
                margin:
                    const EdgeInsets.only(bottom: 12.0, left: 12, right: 12),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: colorProvider.colors.appBarColor,
                    width: 1.5,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    _showFriendOptions(
                      context,
                      friends[index].id,
                      colorProvider,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colorProvider.colors.appBarColor,
                          radius: 25,
                          child: Text(
                            friendData['username'][0].toUpperCase(),
                            style: TextStyle(
                              color: colorProvider.colors.secondaryTextColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friendData['username'],
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${friendData['userShortId']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.more_vert,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
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
