import 'package:control_gastos/utils/custom_logger.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/widgets/forms/gastos/subgrupo_gastos_form.dart';
import 'package:control_gastos/widgets/forms/gastos/gasto_form.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/widgets/loading_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // Importa Provider
import 'package:control_gastos/services/provider_colors.dart'; // Importa el proveedor de colores
import 'package:control_gastos/services/storage_service.dart';
import 'package:control_gastos/widgets/profile_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InsertGroupScreen extends StatefulWidget {
  final String userUid;
  final Function(int, String)
      onNombreChanged; // Callback para el cambio de nombre del grupo

  const InsertGroupScreen({
    super.key,
    required this.userUid,
    required this.onNombreChanged,
  });

  @override
  _InsertGroupScreenState createState() => _InsertGroupScreenState();
}

class _InsertGroupScreenState extends State<InsertGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final List<Gasto> _expenses = []; // Lista de gastos individuales
  final List<SubgroupModel> _subgroups = []; // Lista de subgrupos de gastos
  final List<GlobalKey> _subgroupKeys = []; // Claves para acceder a los formularios
  
  @override
  void initState() {
    super.initState();
    _addExpenseForm(); // Agregar un formulario de gasto inicial
  }

  Future<void> _loadElementOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expenseOrder = prefs.getStringList('expense_order_new') ?? [];
      final subgroupOrder = prefs.getStringList('subgroup_order_new') ?? [];
      final imageOrder = prefs.getStringList('image_order_new') ?? [];
      
      setState(() {
        _expenseOrder.clear();
        _expenseOrder.addAll(expenseOrder);
        _subgroupOrder.clear();
        _subgroupOrder.addAll(subgroupOrder);
        _imageOrder.clear();
        _imageOrder.addAll(imageOrder);
      });
    } catch (e) {
      CustomLogger().logError('Error al cargar orden de elementos: $e');
    }
  }

  Future<void> _saveElementOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('expense_order_new', _expenseOrder);
      await prefs.setStringList('subgroup_order_new', _subgroupOrder);
      await prefs.setStringList('image_order_new', _imageOrder);
    } catch (e) {
      CustomLogger().logError('Error al guardar orden de elementos: $e');
    }
  }

  void _initializeElementOrder() {
    // Inicializar orden de gastos
    final currentExpenseIds = _expenses.map((e) => e.id ?? 'expense_${_expenses.indexOf(e)}').toList();
    _expenseOrder.removeWhere((id) => !currentExpenseIds.contains(id));
    for (final id in currentExpenseIds) {
      if (!_expenseOrder.contains(id)) {
        _expenseOrder.add(id);
      }
    }
    
    // Inicializar orden de subgrupos
    final currentSubgroupIds = _subgroups.map((s) => s.subgroupName).toList();
    _subgroupOrder.removeWhere((id) => !currentSubgroupIds.contains(id));
    for (final id in currentSubgroupIds) {
      if (!_subgroupOrder.contains(id)) {
        _subgroupOrder.add(id);
      }
    }
    
    // Inicializar orden de imágenes
    final currentImageIds = _imagenes.keys.toList();
    _imageOrder.removeWhere((id) => !currentImageIds.contains(id));
    for (final id in currentImageIds) {
      if (!_imageOrder.contains(id)) {
        _imageOrder.add(id);
      }
    }
  }
  
  // Variables para manejo de imágenes
  final StorageService _storageService = StorageService();
  Map<String, Map<String, dynamic>> _imagenes = {}; // Mapa de imágenes del grupo
  
  // Variables para el orden de elementos
  final List<String> _expenseOrder = [];
  final List<String> _subgroupOrder = [];
  final List<String> _imageOrder = [];

  final List<String> _months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre'
  ];
  final _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '',
    decimalDigits: 0, // Esto fuerza que no haya decimales
    // customPattern: '# ##0.00 ¤' // El patrón personalizado donde , es el separador de miles
  );

  // Agrega un formulario para un gasto individual
  void _addExpenseForm() {
    setState(() {
      final newExpense = Gasto(
        nombre: '',
        valor: 0,
        fecha: DateTime.now(),
        esAFavor: true,
      );
      _expenses.add(newExpense);
      final expenseId = newExpense.id ?? 'expense_${_expenses.length - 1}';
      _expenseOrder.add(expenseId);
    });
    _saveElementOrder();
  }

  // Agrega un nuevo subgrupo a la lista
  void _addSubgroup() {
    setState(() {
      final newSubgroup = SubgroupModel(
        subgroupName: '',
        expenses: [],
        subtotal: 0,
      );
      _subgroups.add(newSubgroup);
      _subgroupKeys.add(GlobalKey());
      _subgroupOrder.add(newSubgroup.subgroupName);
    });
    _saveElementOrder();
  }

  Future<void> _updateExpenseOrder(int oldIndex, int newIndex) async {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final String movedId = _expenseOrder.removeAt(oldIndex);
      _expenseOrder.insert(newIndex, movedId);
    });
    await _saveElementOrder();
  }

  Future<void> _updateSubgroupOrder(int oldIndex, int newIndex) async {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final String movedId = _subgroupOrder.removeAt(oldIndex);
      _subgroupOrder.insert(newIndex, movedId);
    });
    await _saveElementOrder();
  }

  Future<void> _updateImageOrder(int oldIndex, int newIndex) async {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final String movedId = _imageOrder.removeAt(oldIndex);
      _imageOrder.insert(newIndex, movedId);
    });
    await _saveElementOrder();
  }

  // Método para agregar una nueva imagen
  Future<void> _addImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        // Mostrar pantalla de carga
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const LoadingScreen(
                message: 'Subiendo imagen...',
                subtitle: 'Por favor espera mientras procesamos tu imagen',
                type: LoadingType.general,
              ),
            ),
          );
        }

        try {
          // Generar ID único para la imagen
          final String imageId = DateTime.now().millisecondsSinceEpoch.toString();
          
          // Procesar imagen fragmentada para evitar límite de Firestore
          final Map<String, dynamic> imagenFragmentada = await _storageService.procesarImagenFragmentada(imageFile: image);
          
          setState(() {
            _imagenes[imageId] = imagenFragmentada;
            _imageOrder.add(imageId);
          });
          
          _saveElementOrder();

          // Cerrar pantalla de carga
          if (mounted) {
            Navigator.of(context).pop();
          }
        } catch (e) {
          // Cerrar pantalla de carga en caso de error
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al procesar la imagen: $e')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  // Método para actualizar la descripción de una imagen
  void _updateImageDescription(String imageId, String description) {
    // Actualizar directamente sin setState para evitar re-renderizado innecesario
    if (_imagenes.containsKey(imageId)) {
      _imagenes[imageId]!['descripcion'] = description;
    }
  }

  // Método para eliminar una imagen
  void _removeImage(String imageId) {
    setState(() {
      _imagenes.remove(imageId);
    });
  }

  // Actualiza un gasto individual
  void _updateExpense(int index, Gasto gasto) {
    setState(() {
      _expenses[index] = gasto;
    });
  }

  // Actualiza el nombre y subtotal de un subgrupo específico
  void _updateSubgroup(int index, String nombre) {
    CustomLogger().logInfo('=== ACTUALIZANDO SUBGRUPO (INSERCIÓN) ===');
    CustomLogger().logInfo('Índice: $index');
    CustomLogger().logInfo('Nombre anterior: ${_subgroups[index].subgroupName}');
    CustomLogger().logInfo('Nombre nuevo: $nombre');
    CustomLogger().logInfo('ID del subgrupo: ${_subgroups[index].id}');
    
    setState(() {
      _subgroups[index] = _subgroups[index].copyWith(
        subgroupName: nombre,
        subtotal: _subgroups[index].calculateSubtotal(),
      );
      CustomLogger().logInfo('Subgrupo actualizado - Nombre: ${_subgroups[index].subgroupName}, ID: ${_subgroups[index].id}');
    });
    
    _calculateTotal(); // Actualiza el total general
  }

  // Notifica el cambio de nombre del subgrupo a través del callback
  void _notifyNombreChanged(int index) {
    widget.onNombreChanged(index, _subgroups[index].subgroupName);
  }

  // Actualiza la lista de gastos en un subgrupo específico y recalcula el subtotal
  void _updateSubgroupExpense(int subgroupIndex, List<Gasto> gastos) {
    setState(() {
      double subtotal = gastos.fold(0.0, (sum, gasto) {
        // Asegurarse de que el valor es un número válido
        return sum + gasto.valor;
      });

      _subgroups[subgroupIndex] = _subgroups[subgroupIndex].copyWith(
        expenses: gastos,
        subtotal: subtotal,
      );
    });
    _calculateTotal();
  }

  // Calcula el total general de todos los gastos y subtotales de subgrupos
  double _calculateTotal() {
    try {
      // Calcular total de gastos principales
      double total = _expenses.fold(0.0, (sum, gasto) {
        return sum + gasto.valor;
      });

      // Agregar totales de subgrupos
      for (var subgroup in _subgroups) {
        total += subgroup.expenses.fold(0.0, (sum, gasto) => sum + gasto.valor);
      }

      return total;
    } catch (e) {
      print('Error al calcular total: $e');
      return 0.0;
    }
  }

  // Guarda el grupo de gastos en la base de datos
  Future<void> _saveGroup() async {
    if (_groupNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Debe ingresar un nombre o descropcion para el grupo')),
      );
      return;
    }

    // Mostrar pantalla de carga
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const LoadingScreen(
            message: 'Guardando Gastos...',
            subtitle: 'Por favor espera mientras guardamos tu grupo de gastos',
            type: LoadingType.general,
          ),
        ),
      );
    }

    try {
      CustomLogger().logInfo('=== INICIANDO GUARDADO DE GRUPO (INSERCIÓN) ===');
      CustomLogger().logInfo('Número de subgrupos: ${_subgroups.length}');

      // Obtener nombres actuales de los formularios y actualizar subgrupos
      for (int i = 0; i < _subgroups.length; i++) {
        final formKey = _subgroupKeys[i];
        final state = formKey.currentState;
         if (state != null) {
           // Usar dynamic para acceder al método público getCurrentName
           final dynamic dynamicState = state;
           try {
             final currentName = dynamicState.getCurrentName() as String;
             CustomLogger().logInfo('Subgrupo $i - Nombre del formulario: "$currentName"');
             CustomLogger().logInfo('Subgrupo $i - Nombre anterior: "${_subgroups[i].subgroupName}"');
             
             if (currentName != _subgroups[i].subgroupName) {
               setState(() {
                 _subgroups[i] = _subgroups[i].copyWith(
                   subgroupName: currentName,
                   subtotal: _subgroups[i].calculateSubtotal(),
                 );
               });
               CustomLogger().logInfo('Subgrupo $i actualizado con nuevo nombre: "$currentName"');
             }
           } catch (e) {
             CustomLogger().logError('Error al acceder a getCurrentName: $e');
           }
         }
      }

      // Log final de todos los subgrupos antes de enviar a la base de datos
      CustomLogger().logInfo('=== SUBGRUPOS FINALES ANTES DE GUARDAR (INSERCIÓN) ===');
      for (int i = 0; i < _subgroups.length; i++) {
        CustomLogger().logInfo('Subgrupo $i: Nombre="${_subgroups[i].subgroupName}", ID="${_subgroups[i].id}", Gastos=${_subgroups[i].expenses.length}');
      }

      double total = _calculateTotal();

      await FirestoreService().addExpenseGroup(
        widget.userUid,
        _groupNameController.text,
        _expenses,
        _subgroups,
        total: total,
        imagenes: _imagenes,
      );

      if (mounted) {
        // Cerrar pantalla de carga
        Navigator.of(context).pop();
        
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupo guardado con éxito')),
        );
        
        // Navegar de vuelta a la pantalla anterior
        try {
          Navigator.of(context).pop();
        } catch (navError) {
          print('Error en navegación: $navError');
        }
      }
    } catch (e) {
      if (mounted) {
        // Cerrar pantalla de carga
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el grupo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider =
        Provider.of<ColorProvider>(context); // Accede al proveedor de colores
    double total = _calculateTotal();
    return Scaffold(
      backgroundColor: colorProvider.colors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Añadir Grupo',
          style: TextStyle(
              color: colorProvider.colors.secondaryTextColor, fontSize: 20),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme: IconThemeData(
            color: colorProvider.colors
                .secondaryTextColor), // Añadir esta línea // Color del AppBar
        actions: [
          IconButton(
            icon: Icon(Icons.save,
                color: colorProvider
                    .colors.secondaryTextColor), // Color icono del appbar
            onPressed: _saveGroup,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    margin: const EdgeInsets.only(
                        left: 1.5, right: 1.5, bottom: 4, top: 4),
                    color: colorProvider.colors.backgroundColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      side: BorderSide(
                        color: colorProvider.colors.appBarColor.withOpacity(0.25),
                        width: 2.0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _groupNameController,
                                decoration: InputDecoration(
                                  labelText: 'Descripcion',
                                  labelStyle: TextStyle(
                                      color: colorProvider.colors.primaryTextColor),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: colorProvider.colors.appBarColor),
                                  ),
                                ),
                                style: TextStyle(
                                    color: colorProvider.colors.primaryTextColor),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.arrow_drop_down,
                                  color: colorProvider.colors.primaryTextColor),
                              onSelected: (String value) {
                                setState(() {
                                  _groupNameController.text = value;
                                });
                              },
                              itemBuilder: (BuildContext context) {
                                return _months.map((String month) {
                                  return PopupMenuItem<String>(
                                    value: month,
                                    child: Text(month,
                                        style: TextStyle(
                                            color: colorProvider
                                                .colors.secondaryTextColor)),
                                  );
                                }).toList();
                              },
                              color: colorProvider.colors.appBarColor,
                              offset: const Offset(0, 40),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _expenseOrder.length,
                    onReorder: _updateExpenseOrder,
                    proxyDecorator: (Widget child, int index,
                        Animation<double> animation) {
                      return Material(
                        color: Colors.transparent,
                        elevation: 0,
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final expenseId = _expenseOrder[index];
                      final expenseIndex = _expenses.indexWhere((e) => 
                          (e.id ?? 'expense_${_expenses.indexOf(e)}') == expenseId);
                      
                      if (expenseIndex == -1) return const SizedBox.shrink();
                      
                      return GastoForm(
                        key: ValueKey(expenseId),
                        gasto: _expenses[expenseIndex],
                        index: index,
                        onCancel: () {
                          setState(() {
                            _expenses.removeAt(expenseIndex);
                            _expenseOrder.remove(expenseId);
                          });
                          _saveElementOrder();
                        },
                        onGastoChanged: (gasto) => _updateExpense(expenseIndex, gasto),
                      );
                    },
                  ),
                  // const SizedBox(height: 16),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _subgroupOrder.length,
                    onReorder: _updateSubgroupOrder,
                    proxyDecorator: (Widget child, int index,
                        Animation<double> animation) {
                      return Material(
                        color: Colors.transparent,
                        elevation: 0,
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final subgroupId = _subgroupOrder[index];
                      final subgroupIndex = _subgroups.indexWhere((s) => s.subgroupName == subgroupId);
                      
                      if (subgroupIndex == -1) return const SizedBox.shrink();
                      
                      return Column(
                        key: ValueKey(subgroupId),
                        children: [
                          SubgrupoGastoForm(
                            key: _subgroupKeys[subgroupIndex],
                            subgrupoNombre: _subgroups[subgroupIndex].subgroupName,
                            index: index,
                            onNombreChanged: (nombre) =>
                                _updateSubgroup(subgroupIndex, nombre),
                            gastos: _subgroups[subgroupIndex].expenses,
                            onGastosChanged: (gastos) =>
                                _updateSubgroupExpense(subgroupIndex, gastos),
                            onEliminar: () {
                              setState(() {
                                _subgroups.removeAt(subgroupIndex);
                                _subgroupKeys.removeAt(subgroupIndex);
                                _subgroupOrder.remove(subgroupId);
                              });
                              _saveElementOrder();
                              _calculateTotal();
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                  // Sección de imágenes
                  if (_imagenes.isNotEmpty) ...[
                    Card(
                      margin: const EdgeInsets.only(
                          left: 1.5, right: 1.5, bottom: 4, top: 4),
                      color: colorProvider.colors.backgroundColor,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        side: BorderSide(
                          color: colorProvider.colors.appBarColor.withOpacity(0.25),
                          width: 2.0,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Imágenes',
                              style: TextStyle(
                                color: colorProvider.colors.primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              itemCount: _imageOrder.length,
                              onReorder: _updateImageOrder,
                              proxyDecorator: (Widget child, int index,
                                  Animation<double> animation) {
                                return Material(
                                  color: Colors.transparent,
                                  elevation: 0,
                                  child: child,
                                );
                              },
                              itemBuilder: (context, index) {
                                final imageId = _imageOrder[index];
                                final imageData = _imagenes[imageId];
                                
                                if (imageData == null) return const SizedBox.shrink();
                                
                                return ExpenseImageWidget(
                                  key: ValueKey(imageId),
                                  imageData: imageData,
                                  index: index,
                                  onDelete: () {
                                    _removeImage(imageId);
                                    setState(() {
                                      _imageOrder.remove(imageId);
                                    });
                                    _saveElementOrder();
                                  },
                                  onDescriptionChanged: (description) => _updateImageDescription(imageId, description),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            color: total >= 0
                ? colorProvider.colors.positiveColor
                : colorProvider
                    .colors.negativeColor, // Color de fondo según el total
            padding: const EdgeInsets.all(16.0),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: \$${_currencyFormat.format(total)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorProvider
                        .colors.secondaryTextColor, // Color del texto del total
                  ),
                ),
                PopupMenuButton<int>(
                  icon: Icon(
                    Icons.add,
                    color: colorProvider
                        .colors.secondaryTextColor, // Color del icono de añadir
                    size: 20,
                  ),
                  onSelected: (int value) {
                    switch (value) {
                      case 1:
                        _addExpenseForm();
                        break;
                      case 2:
                        _addSubgroup();
                        break;
                      case 3:
                        _addImage();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return <PopupMenuEntry<int>>[
                      PopupMenuItem<int>(
                        value: 1,
                        child: Text(
                          '• Agregar Monto',
                          style: TextStyle(
                              fontSize: 16,
                              color: colorProvider.colors
                                  .secondaryTextColor), // Color del texto de los elementos
                        ),
                      ),
                      PopupMenuItem<int>(
                        value: 2,
                        child: Text(
                          '• Agregar Grupo',
                          style: TextStyle(
                              fontSize: 16,
                              color: colorProvider.colors
                                  .secondaryTextColor), // Color del texto de los elementos
                        ),
                      ),
                      PopupMenuItem<int>(
                        value: 3,
                        child: Text(
                          '• Agregar Imagen',
                          style: TextStyle(
                              fontSize: 16,
                              color: colorProvider.colors
                                  .secondaryTextColor), // Color del texto de los elementos
                        ),
                      ),
                    ];
                  },
                  // Establecer el fondo del PopupMenu igual al color del AppBar
                  offset: const Offset(0, 40),
                  color: colorProvider
                      .colors.appBarColor, // Color de fondo del PopupMenu
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
