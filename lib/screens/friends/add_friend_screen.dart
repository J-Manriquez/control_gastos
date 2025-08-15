import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/services/friends_service.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:provider/provider.dart';

class AddFriendScreen extends StatefulWidget {
  final String userId;

  const AddFriendScreen({super.key, required this.userId});

  @override
  _AddFriendScreenState createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _shortIdController = TextEditingController();
  final FriendsService _friendsService = FriendsService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      backgroundColor: colorProvider.colors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Agregar Amigo',
          style: TextStyle(color: colorProvider.colors.secondaryTextColor, fontSize: 20),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme: IconThemeData(color: colorProvider.colors.secondaryTextColor),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              children: [
                TextField(
                  controller: _shortIdController,
                  decoration: InputDecoration( //borde redondo en el input
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: colorProvider.colors.appBarColor,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: colorProvider.colors.appBarColor,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: colorProvider.colors.appBarColor,
                        width: 1.5,
                      ),
                    ),
                    labelText: 'ID de Usuario',
                    labelStyle: TextStyle(color: colorProvider.colors.primaryTextColor),
                    hintText: 'Ingresa el ID del usuario',
                    hintStyle: TextStyle(
                      color: colorProvider.colors.primaryTextColor.withOpacity(0.6)
                    ),
                  ),
                  style: TextStyle(color: colorProvider.colors.primaryTextColor),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendFriendRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorProvider.colors.appBarColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          'Enviar Solicitud',
                          style: TextStyle(color: colorProvider.colors.secondaryTextColor),
                        ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: colorProvider.colors.appBarColor,
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _friendsService.getSentPendingRequests(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar solicitudes',
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.send_outlined,
                          color: colorProvider.colors.primaryTextColor.withOpacity(0.5),
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay solicitudes enviadas pendientes',
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

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  padding: const EdgeInsets.all(0),
                  itemBuilder: (context, index) {
                    final request = snapshot.data!.docs[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('usuarios')
                          .doc(request['toUserId'])
                          .get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const SizedBox.shrink();
                        }

                        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                        final username = userData['username'] as String? ?? 'Usuario';
                        
                        return Card(
                          color: colorProvider.colors.backgroundColor,
                          margin: const EdgeInsets.all(12.0),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: colorProvider.colors.appBarColor,
                              width: 1.5,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: colorProvider.colors.appBarColor,
                                    radius: 25,
                                    child: Text(
                                      username[0].toUpperCase(),
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
                                          username,
                                          style: TextStyle(
                                            color: colorProvider.colors.primaryTextColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: ${userData['userShortId'] ?? ''}',
                                          style: TextStyle(
                                            color: colorProvider.colors.secondaryTextColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Solicitud pendiente',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: colorProvider.colors.negativeColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.cancel,
                                        color: colorProvider.colors.secondaryTextColor,
                                        size: 20,
                                      ),
                                      style: IconButton.styleFrom(
                                        padding: const EdgeInsets.all(8),
                                      ),
                                      onPressed: () => _cancelRequest(request.id),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFriendRequest() async {
    if (_shortIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un ID de usuario')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _friendsService.sendFriendRequest(
        widget.userId,
        _shortIdController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud enviada con éxito')),
        );
        _shortIdController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    try {
      await _friendsService.cancelFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud cancelada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
}
