import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:control_gastos/services/storage_service.dart';
import 'package:control_gastos/widgets/profile_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpenseDetailsWidget extends StatefulWidget {
  final GroupModel group;
  final bool isTrackingEnabled;
  final Function(String expenseId, bool isTracked)? onExpenseTrackingChanged;
  final Function(String subgroupId, String expenseId, bool isTracked)?
      onSubgroupExpenseTrackingChanged; // Nueva función para gastos en subgrupos

  const ExpenseDetailsWidget({
    Key? key,
    required this.group,
    this.isTrackingEnabled = false,
    this.onExpenseTrackingChanged,
    this.onSubgroupExpenseTrackingChanged,
    SharedExpenseGroup? expense,
  }) : super(key: key);

  @override
  _ExpenseDetailsWidgetState createState() => _ExpenseDetailsWidgetState();
}

class _ExpenseDetailsWidgetState extends State<ExpenseDetailsWidget> {
  List<String> _expenseOrder = [];
  List<String> _subgroupOrder = [];
  List<String> _imageOrder = [];
  Map<String, List<String>> _subgroupExpenseOrder = {}; // Orden de gastos por subgrupo
  bool _isOrderLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadElementOrder();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOrderLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return buildGroupDetails(context, widget.group);
  }

  Future<void> _loadElementOrder() async {
    try {
      // Cargar orden desde los datos del grupo de Firebase
      _expenseOrder = widget.group.expenseOrder ?? [];
      _subgroupOrder = widget.group.subgroupOrder ?? [];
      _imageOrder = widget.group.imageOrder ?? [];
      
      // Cargar orden de gastos dentro de subgrupos
      if (widget.group is SharedExpenseGroup) {
        // Para SharedExpenseGroup, cargar desde Firebase
        final sharedGroup = widget.group as SharedExpenseGroup;
        _subgroupExpenseOrder = sharedGroup.subgroupExpenseOrder ?? {};
      } else {
        // Para GroupModel normal, mantener SharedPreferences como fallback
        final prefs = await SharedPreferences.getInstance();
        final groupId = widget.group.id;
        for (final subgroup in widget.group.subgroups) {
          final subgroupExpenseOrder = prefs.getStringList('subgroup_expense_order_${groupId}_${subgroup.subgroupName}');
          if (subgroupExpenseOrder != null) {
            _subgroupExpenseOrder[subgroup.subgroupName] = subgroupExpenseOrder;
          }
        }
      }
      
      setState(() {
        _isOrderLoaded = true;
      });
      
      // Debug: imprimir los órdenes cargados
      print('DEBUG - Expense order loaded from Firebase: $_expenseOrder');
      print('DEBUG - Subgroup order loaded from Firebase: $_subgroupOrder');
      print('DEBUG - Image order loaded from Firebase: $_imageOrder');
      print('DEBUG - Subgroup expense order loaded: $_subgroupExpenseOrder');
    } catch (e) {
      print('Error cargando orden de elementos: $e');
      setState(() {
        _isOrderLoaded = true;
      });
    }
  }

  List<Gasto> _getOrderedExpenses(List<Gasto> expenses) {
    print('DEBUG - _getOrderedExpenses called with ${expenses.length} expenses');
    print('DEBUG - Current expense order: $_expenseOrder');
    
    if (_expenseOrder.isEmpty) {
      print('DEBUG - Expense order is empty, returning original list');
      return expenses;
    }
    
    List<Gasto> orderedExpenses = [];
    
    // Debug: mostrar IDs de gastos actuales
    for (int i = 0; i < expenses.length; i++) {
      final expense = expenses[i];
      final expenseId = expense.id ?? 'expense_$i';
      print('DEBUG - Expense $i: id="${expense.id}", generated_id="$expenseId", name="${expense.nombre}"');
    }
    
    // Agregar gastos según el orden guardado
    for (String expenseId in _expenseOrder) {
      final expenseIndex = expenses.indexWhere((e) => 
          (e.id ?? 'expense_${expenses.indexOf(e)}') == expenseId);
      
      print('DEBUG - Looking for expense with id: $expenseId, found at index: $expenseIndex');
      
      if (expenseIndex != -1) {
        orderedExpenses.add(expenses[expenseIndex]);
        print('DEBUG - Added expense: ${expenses[expenseIndex].nombre}');
      }
    }
    
    // Agregar gastos que no están en el orden (nuevos)
    for (int i = 0; i < expenses.length; i++) {
      final expense = expenses[i];
      final expenseId = expense.id ?? 'expense_$i';
      if (!_expenseOrder.contains(expenseId)) {
        orderedExpenses.add(expense);
      }
    }
    
    print('DEBUG - Final ordered expenses count: ${orderedExpenses.length}');
    for (int i = 0; i < orderedExpenses.length; i++) {
      print('DEBUG - Final order $i: ${orderedExpenses[i].nombre}');
    }
    
    return orderedExpenses;
  }

  List<Gasto> _getOrderedSubgroupExpenses(List<Gasto> expenses, String subgroupName) {
    print('DEBUG - _getOrderedSubgroupExpenses called for subgroup: $subgroupName with ${expenses.length} expenses');
    
    final subgroupOrder = _subgroupExpenseOrder[subgroupName];
    if (subgroupOrder == null || subgroupOrder.isEmpty) {
      print('DEBUG - No order found for subgroup: $subgroupName, returning original list');
      return expenses;
    }
    
    List<Gasto> orderedExpenses = [];
    
    // Debug: mostrar IDs de gastos actuales del subgrupo
    for (int i = 0; i < expenses.length; i++) {
      final expense = expenses[i];
      final expenseId = expense.id ?? 'subgroup_expense_${subgroupName}_$i';
      print('DEBUG - Subgroup expense $i: id="${expense.id}", generated_id="$expenseId", name="${expense.nombre}"');
    }
    
    // Agregar gastos según el orden guardado
    for (String expenseId in subgroupOrder) {
      final expenseIndex = expenses.indexWhere((e) => 
          (e.id ?? 'subgroup_expense_${subgroupName}_${expenses.indexOf(e)}') == expenseId);
      
      print('DEBUG - Looking for subgroup expense with id: $expenseId, found at index: $expenseIndex');
      
      if (expenseIndex != -1) {
        orderedExpenses.add(expenses[expenseIndex]);
        print('DEBUG - Added subgroup expense: ${expenses[expenseIndex].nombre}');
      }
    }
    
    // Agregar gastos que no están en el orden (nuevos)
    for (int i = 0; i < expenses.length; i++) {
      final expense = expenses[i];
      final expenseId = expense.id ?? 'subgroup_expense_${subgroupName}_$i';
      if (!subgroupOrder.contains(expenseId)) {
        orderedExpenses.add(expense);
      }
    }
    
    print('DEBUG - Final ordered subgroup expenses count: ${orderedExpenses.length}');
    for (int i = 0; i < orderedExpenses.length; i++) {
      print('DEBUG - Final subgroup order $i: ${orderedExpenses[i].nombre}');
    }
    
    return orderedExpenses;
  }

  List<SubgroupModel> _getOrderedSubgroups(List<SubgroupModel> subgroups) {
    if (_subgroupOrder.isEmpty) return subgroups;
    
    List<SubgroupModel> orderedSubgroups = [];
    
    // Agregar subgrupos según el orden guardado
    for (String subgroupName in _subgroupOrder) {
      final subgroup = subgroups.firstWhere(
        (s) => s.subgroupName == subgroupName,
        orElse: () => SubgroupModel(id: '', subgroupName: '', expenses: [], subtotal: 0.0),
      );
      if (subgroup.id.isNotEmpty) {
        orderedSubgroups.add(subgroup);
      }
    }
    
    // Agregar subgrupos que no están en el orden (nuevos)
    for (SubgroupModel subgroup in subgroups) {
      if (!_subgroupOrder.contains(subgroup.subgroupName)) {
        orderedSubgroups.add(subgroup);
      }
    }
    
    return orderedSubgroups;
  }

  List<MapEntry<String, dynamic>> _getOrderedImages(Map<String, dynamic>? imagenes) {
    if (imagenes == null || imagenes.isEmpty) return [];
    if (_imageOrder.isEmpty) return imagenes.entries.toList();
    
    List<MapEntry<String, dynamic>> orderedImages = [];
    
    // Agregar imágenes según el orden guardado
    for (String imageId in _imageOrder) {
      if (imagenes.containsKey(imageId)) {
        orderedImages.add(MapEntry(imageId, imagenes[imageId]));
      }
    }
    
    // Agregar imágenes que no están en el orden (nuevas)
    for (MapEntry<String, dynamic> entry in imagenes.entries) {
      if (!_imageOrder.contains(entry.key)) {
        orderedImages.add(entry);
      }
    }
    
    return orderedImages;
  }

  Widget buildGroupDetails(BuildContext context, GroupModel group) {
    final colorProvider = Provider.of<ColorProvider>(context);
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: '',
      decimalDigits: 0,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group is SharedExpenseGroup &&
              group.totalDistribution != null) ...[
            Text(
              'Distribución',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.appBarColor,
              ),
            ),
            Divider(
              color: colorProvider.colors.appBarColor,
              height: 0,
            ),
            ...group.totalDistribution!.shares.map((share) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(share.userId)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  // Verificar si los datos existen y no son nulos
                  final userData = snapshot.data!.data();
                  if (userData == null) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 0.5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monto no distribuido',
                            style: TextStyle(
                              color: colorProvider.colors.primaryTextColor,
                            ),
                          ),
                          
                          Text(
                            '\$${share.amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorProvider.colors.appBarColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Ahora es seguro hacer el cast
                  final userDataMap = userData as Map<String, dynamic>;
                  final username = userDataMap['username'] ?? 'Usuario';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0.5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          username,
                          style: TextStyle(
                            color: colorProvider.colors.primaryTextColor,
                          ),
                        ),
                        Text(
                          '\$${share.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorProvider.colors.primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ],
          // Solo mostrar la sección de Gastos Principales si hay gastos
          if (group.expenses.isNotEmpty) ...[
            Text(
              'Gastos Principales',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.appBarColor,
              ),
            ),
            Divider(
              color: colorProvider.colors.appBarColor,
              height: 0,
            ),
            ..._getOrderedExpenses(group.expenses).map((expense) => buildExpenseItem(
                  context,
                  expense.nombre,
                  expense.valor,
                  expense.esAFavor,
                  currencyFormat,
                  expenseId: expense.id,
                  isTracked: expense.isTracked,
                )),
          ],
          if (group.subgroups.isNotEmpty) ...[
            ..._getOrderedSubgroups(group.subgroups).map((subgroup) => buildSubgroupSection(
                  context,
                  subgroup.expenses,
                  subgroup.subgroupName,
                  currencyFormat,
                  subgroupId: subgroup.id,
                  isTracked: subgroup.isTracked,
                )),
          ],
          // Mostrar miniaturas de imágenes del grupo
          if (group.imagenes != null && group.imagenes!.isNotEmpty) ...[
            // const SizedBox(height: 16),
            Text(
              'Imágenes del grupo',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.appBarColor,
              ),
            ),
            Divider(
              color: colorProvider.colors.appBarColor,
              height: 0,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _getOrderedImages(group.imagenes).map((entry) {
                final imageData = entry.value;
                final description = imageData['descripcion'] as String? ?? '';
                
                print('Procesando imagen: tipo=${imageData['tipo']}, esFragmentada=${StorageService.esImagenFragmentada(imageData)}');
                
                // Verificar si es una imagen fragmentada externamente
                if (imageData['tipo'] == 'fragmentada_externa') {
                  print('Detectada imagen fragmentada externa');
                  // Imagen fragmentada externamente - necesita carga asíncrona
                  return FutureBuilder<String>(
                    future: _loadExternalFragmentedImage(imageData),
                    builder: (context, snapshot) {
                      String? imageUrl;
                      if (snapshot.connectionState == ConnectionState.done) {
                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          imageUrl = snapshot.data;
                          // print('Imagen fragmentada cargada exitosamente: ${imageUrl.substring(0, 50)}...');
                        } else if (snapshot.hasError) {
                          print('Error cargando imagen fragmentada: ${snapshot.error}');
                        } else {
                          print('Imagen fragmentada vacía o nula');
                        }
                      } else if (snapshot.connectionState == ConnectionState.waiting) {
                        print('Cargando imagen fragmentada...');
                      }
                      
                      return _buildImageContainer(imageUrl, description, colorProvider, context, imageData: imageData);
                    },
                  );
                } else {
                  // Imagen normal o fragmentada internamente
                  String? imageUrl;
                  if (imageData['tipo'] == 'fragmentada' && imageData.containsKey('fragments')) {
                    // Imagen fragmentada internamente - reconstruir sincrónicamente
                    print('Detectada imagen fragmentada interna');
                    try {
                      imageUrl = StorageService.obtenerImagenCompleta(imageData);
                    } catch (e) {
                      print('Error reconstruyendo imagen fragmentada: $e');
                      imageUrl = null;
                    }
                  } else {
                    // Imagen normal
                    print('Detectada imagen normal');
                    imageUrl = imageData['imagen'] as String?;
                  }
                  
                  return _buildImageContainer(imageUrl, description, colorProvider, context, imageData: imageData);
                }
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (group is SharedExpenseGroup) ...[
            Text(
              'Participantes',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.appBarColor,
              ),
            ),
            Divider(
              color: colorProvider.colors.appBarColor,
              height: 0,
            ),
            ...group.participants.map((participant) =>
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(participant.userId)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();

                    // Verificar si los datos existen y no son nulos
                    final userData = snapshot.data!.data();
                    if (userData == null) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorProvider.colors.appBarColor
                              .withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorProvider.colors.appBarColor
                                .withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: colorProvider.colors.appBarColor
                                    .withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person,
                                size: 18,
                                color: colorProvider.colors.appBarColor
                                    .withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Usuario no encontrado',
                                style: TextStyle(
                                  color: colorProvider.colors.primaryTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_getStatusText(participant.status)}',
                                style: TextStyle(
                                  color: colorProvider.colors.primaryTextColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Ahora es seguro hacer el cast
                    final userDataMap = userData as Map<String, dynamic>;
                    final username = userDataMap['username'] ?? 'Usuario';

                    // Determinar color del estado
                    Color statusColor;
                    switch (participant.status) {
                      case ParticipantStatus.accepted:
                        statusColor = Colors.green;
                        break;
                      case ParticipantStatus.pending:
                        statusColor = Colors.orange;
                        break;
                      case ParticipantStatus.rejected:
                        statusColor = Colors.red;
                        break;
                      default:
                        statusColor = Colors.grey;
                    }

                    return Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            colorProvider.colors.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              colorProvider.colors.appBarColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: colorProvider.colors.appBarColor
                                  .withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              size: 18,
                              color: colorProvider.colors.appBarColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              username,
                              style: TextStyle(
                                color: colorProvider.colors.primaryTextColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_getStatusText(participant.status)}',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )),
          ],
        ],
      ),
    );
  }

  Widget buildExpenseItem(BuildContext context, String name, double value,
      bool isIncome, NumberFormat currencyFormat,
      {String? expenseId, bool? isTracked, String? subgroupId}) {
    final colorProvider = Provider.of<ColorProvider>(context);
    return Padding(
      padding: widget.isTrackingEnabled
          ? const EdgeInsets.symmetric(vertical: 0)
          : const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Checkbox para seguimiento
          if (widget.isTrackingEnabled && expenseId != null)
            Checkbox(
              value: isTracked ?? false,
              onChanged: (bool? value) {
                if (subgroupId != null &&
                    widget.onSubgroupExpenseTrackingChanged != null) {
                  // Es un gasto dentro de un subgrupo
                  widget.onSubgroupExpenseTrackingChanged!(
                      subgroupId, expenseId, value ?? false);
                } else if (widget.onExpenseTrackingChanged != null) {
                  // Es un gasto principal
                  widget.onExpenseTrackingChanged!(expenseId, value ?? false);
                }
              },
              activeColor: colorProvider.colors.backgroundColor,
              checkColor: colorProvider.colors.positiveColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: colorProvider.colors.primaryTextColor,
                decoration: (widget.isTrackingEnabled && (isTracked ?? false))
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
          Text(
            currencyFormat.format(value),
            style: TextStyle(
                color: isIncome
                   ? colorProvider.colors.positiveColor
                   : colorProvider.colors.negativeColor,
                fontWeight: FontWeight.bold,
              decoration: (widget.isTrackingEnabled && (isTracked ?? false))
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSubgroupSection(BuildContext context, List<Gasto> gastos,
      String subgroupName, NumberFormat currencyFormat,
      {String? subgroupId, bool? isTracked}) {
    final colorProvider = Provider.of<ColorProvider>(context);
    double subtotal =
        gastos.fold(0, (subtotalValue, gasto) => subtotalValue + gasto.valor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  subgroupName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colorProvider.colors.appBarColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          color: colorProvider.colors.appBarColor,
          height: 0,
        ),
        // Mostrar cada gasto del subgrupo con su propio checkbox (ordenados)
        ..._getOrderedSubgroupExpenses(gastos, subgroupName).map((gasto) => buildExpenseItem(
              context,
              gasto.nombre,
              gasto.valor,
              gasto.esAFavor,
              currencyFormat,
              expenseId: gasto.id,
              isTracked: gasto.isTracked,
              subgroupId: subgroupId, // Pasar el ID del subgrupo
            )),
        const SizedBox(height: 0),
        Container(
            alignment: Alignment.centerRight,
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: colorProvider.colors.backgroundColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: colorProvider.colors.appBarColor.withOpacity(1),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Total Grupo: ${currencyFormat.format(subtotal)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorProvider.colors.appBarColor,
                  ),
                ))),
      ],
    );
  }

  // Añadir este método a la clase ExpenseDetailsWidget
  String _getStatusText(ParticipantStatus status) {
    switch (status) {
      case ParticipantStatus.accepted:
        return 'Invitación aceptada';
      case ParticipantStatus.pending:
        return 'Invitación pendiente';
      case ParticipantStatus.rejected:
        return 'Invitación rechazada';
      default:
        return 'Desconocido';
    }
  }

  Future<String> _loadExternalFragmentedImage(Map<String, dynamic> imageData) async {
    try {
      print('Iniciando carga de imagen fragmentada externa: ${imageData.keys}');
      
      final userUid = FirebaseAuth.instance.currentUser?.uid;
      if (userUid == null) {
        print('Usuario no autenticado');
        return '';
      }
      
      final groupId = widget.group.id;
      // Para imágenes fragmentadas externas existentes sin imageId, usar la clave del mapa
      String? imageId = imageData['imageId'] as String?;
      
      if (imageId == null) {
        // Buscar el imageId en el mapa de imágenes del grupo
        final imagenes = widget.group.imagenes;
        for (String key in imagenes!.keys) {
          if (imagenes[key] == imageData) {
            imageId = key;
            print('imageId encontrado usando clave del mapa: $imageId');
            break;
          }
        }
        
        if (imageId == null) {
          print('No se pudo determinar imageId para imagen fragmentada externa');
          return '';
        }
      }
      
      print('Recuperando fragmentos para imageId: $imageId, groupId: $groupId');
      
      // Recuperar fragmentos desde Firestore
      final reconstructedImage = await FirestoreService().recuperarFragmentosDesdeDocumentosSeparados(
        userUid: userUid,
        groupId: groupId,
        imageId: imageId,
        header: imageData['header'] as String? ?? '',
        totalFragments: imageData['totalFragments'] as int? ?? 0,
      );
      
      print('Fragmentos recuperados, reconstruyendo imagen...');
      
      // Reconstruir la imagen
      final result = StorageService.reconstruirImagenBase64(reconstructedImage);
      
      if (result != null && result.isNotEmpty) {
        print('Imagen reconstruida exitosamente: ${result.substring(0, 50)}...');
      } else {
        print('Error: imagen reconstruida está vacía o es null');
      }
      
      return result ?? '';
    } catch (e) {
      print('Error cargando imagen fragmentada externamente: $e');
      return '';
    }
  }
  
  Widget _buildImageContainer(String? imageUrl, String description, ColorProvider colorProvider, BuildContext context, {Map<String, dynamic>? imageData}) {
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: '',
      decimalDigits: 0,
    );
    
    // Extraer valor y esAFavor de los datos de la imagen
    final double? valor = imageData?['valor'] as double?;
    final bool? esAFavor = imageData?['esAFavor'] as bool?;
    
    return GestureDetector(
      onTap: () => _showFullScreenImage(context, imageUrl, description, colorProvider, imageData: imageData),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: colorProvider.colors.appBarColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: imageUrl != null
                  ? ProfileImage(
                      imageData: imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        color: colorProvider.colors.appBarColor
                            .withOpacity(0.1),
                        child: Icon(
                          Icons.image_not_supported,
                          size: 16,
                          color: colorProvider.colors.appBarColor
                              .withOpacity(0.5),
                        ),
                      ),
                    )
                  : Container(
                      color: colorProvider.colors.appBarColor
                          .withOpacity(0.1),
                      child: Icon(
                        Icons.image,
                        size: 16,
                        color: colorProvider.colors.appBarColor
                            .withOpacity(0.5),
                      ),
                    ),
            ),
          ),
          // Mostrar valor si existe
          if (valor != null && valor != 0.0) ...[
            const SizedBox(height: 4),
            Text(
              (esAFavor ?? true) 
                  ? currencyFormat.format(valor)
                  : '-${currencyFormat.format(valor)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: (esAFavor ?? true) 
                    ? colorProvider.colors.positiveColor
                    : colorProvider.colors.negativeColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String? imageUrl, String description, ColorProvider colorProvider, {Map<String, dynamic>? imageData}) {
     if (imageUrl == null) return;
     
     // Extraer valor y esAFavor de los datos de la imagen
     final double? valor = imageData?['valor'] as double?;
     final bool? esAFavor = imageData?['esAFavor'] as bool?;
     
     // Crear texto combinado de descripción y valor
     String combinedText = description;
     if (valor != null && valor != 0.0) {
       final currencyFormat = NumberFormat.currency(
         locale: 'fr_FR',
         symbol: '',
         decimalDigits: 0,
       );
       final valorText = (esAFavor ?? true) 
           ? currencyFormat.format(valor)
           : '-${currencyFormat.format(valor)}';
       
       if (description.isNotEmpty) {
         combinedText = '$description\nValor: \$$valorText';
       } else {
         combinedText = 'Valor: \$$valorText';
       }
     }
     
     showDialog(
       context: context,
       barrierDismissible: false,
       builder: (BuildContext context) {
         bool showDescription = false;
         
         return StatefulBuilder(
           builder: (context, setState) {
             return Dialog(
               backgroundColor: Colors.transparent,
               child: GestureDetector(
                 onTap: () {
                   if (combinedText.isNotEmpty) {
                     setState(() {
                       showDescription = !showDescription;
                     });
                   }
                 },
                 child: Stack(
                   children: [
                     // Imagen en pantalla completa con zoom
                     Center(
                       child: Container(
                         constraints: BoxConstraints(
                           maxHeight: MediaQuery.of(context).size.height * 0.8,
                           maxWidth: MediaQuery.of(context).size.width * 0.9,
                         ),
                         child: ClipRRect(
                           borderRadius: BorderRadius.circular(8),
                           child: InteractiveViewer(
                             panEnabled: true,
                             boundaryMargin: const EdgeInsets.all(20),
                             minScale: 0.5,
                             maxScale: 4.0,
                             child: ProfileImage(
                               imageData: imageUrl,
                               width: double.infinity,
                               height: double.infinity,
                               fit: BoxFit.contain,
                               errorBuilder: (context, error, stackTrace) {
                                 return Container(
                                   color: colorProvider.colors.backgroundColor,
                                   child: Icon(
                                     Icons.image_not_supported,
                                     size: 64,
                                     color: colorProvider.colors.appBarColor.withOpacity(0.5),
                                   ),
                                 );
                               },
                             ),
                           ),
                         ),
                       ),
                      ),
                      // Botón de cerrar
                     Positioned(
                       top: 40,
                       right: 20,
                       child: Container(
                         decoration: BoxDecoration(
                           color: Colors.black.withOpacity(0.5),
                           shape: BoxShape.circle,
                         ),
                         child: IconButton(
                           icon: Icon(Icons.close, color: colorProvider.colors.secondaryTextColor),
                           onPressed: () => Navigator.of(context).pop(),
                         ),
                       ),
                     ),
                     // Indicador de descripción disponible
                     if (combinedText.isNotEmpty && !showDescription)
                       Positioned(
                         bottom: 40,
                         left: 0,
                         right: 0,
                         child: Center(
                           child: Container(
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             decoration: BoxDecoration(
                               color: Colors.black.withOpacity(0.75),
                               borderRadius: BorderRadius.circular(20),
                             ),
                             child: Text(
                               'Toca aquí para ver descripción',
                               style: TextStyle(
                                 color: colorProvider.colors.secondaryTextColor,
                                 fontSize: 14,
                               ),
                             ),
                           ),
                         ),
                       ),
                     // Descripción en la parte inferior
                     if (combinedText.isNotEmpty && showDescription)
                       Positioned(
                         bottom: 40,
                         left: 20,
                         right: 20,
                         child: Container(
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(
                             color: Colors.black.withOpacity(0.8),
                             borderRadius: BorderRadius.circular(8),
                           ),
                           child: Column(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Text(
                                 combinedText,
                                 style: TextStyle(
                                   color: colorProvider.colors.secondaryTextColor,
                                   fontSize: 16,
                                 ),
                                 textAlign: TextAlign.center,
                               ),
                              //  const SizedBox(height: 8),
                              //  Text(
                              //    'Toca para ocultar',
                              //    style: TextStyle(
                              //      color: colorProvider.colors.secondaryTextColor.withOpacity(0.7),
                              //      fontSize: 12,
                              //    ),
                              //    textAlign: TextAlign.center,
                              //  ),
                             ],
                           ),
                         ),
                       ),
                   ],
                 ),
               ),
             );
           },
         );
       },
     );
   }
}
