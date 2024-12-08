import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:control_gastos/models/user_model.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({Key? key, required this.userId}) : super(key: key);

  Future<UserModel?> _getUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error al obtener datos del usuario: $e');
      return null;
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID copiado al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      backgroundColor: colorProvider.colors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Perfil de Usuario',
          style: TextStyle(color: colorProvider.colors.secondaryTextColor),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme: IconThemeData(color: colorProvider.colors.secondaryTextColor),
      ),
      body: FutureBuilder<UserModel?>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: colorProvider.colors.appBarColor,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar datos',
                style: TextStyle(color: colorProvider.colors.negativeColor),
              ),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return Center(
              child: Text(
                'Usuario no encontrado',
                style: TextStyle(color: colorProvider.colors.negativeColor),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: colorProvider.colors.backgroundColor,
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nombre de usuario:',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorProvider.colors.primaryTextColor,
                          ),
                        ),
                        Text(
                          user.username,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorProvider.colors.primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Email:',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorProvider.colors.primaryTextColor,
                          ),
                        ),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorProvider.colors.primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ID de Usuario:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colorProvider.colors.primaryTextColor,
                                  ),
                                ),
                                Text(
                                  user.userShortId,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: colorProvider.colors.appBarColor,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.copy,
                                color: colorProvider.colors.appBarColor,
                              ),
                              onPressed: () => _copyToClipboard(context, user.userShortId),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: colorProvider.colors.backgroundColor,
                  elevation: 4,
                  child: ListTile(
                    title: Text(
                      'Tipo de cuenta:',
                      style: TextStyle(
                        color: colorProvider.colors.primaryTextColor,
                      ),
                    ),
                    subtitle: Text(
                      user.userType == 'free' ? 'Gratuita' : 'Premium',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: user.userType == 'free'
                            ? colorProvider.colors.primaryTextColor
                            : colorProvider.colors.positiveColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}