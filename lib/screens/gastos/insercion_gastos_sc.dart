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
    // El orden ahora se maneja directamente en Firebase
    // No es necesario cargar desde SharedPreferences para nuevos grupos
  }

  Future<void> _saveElementOrder() async {
    // El orden ahora se guarda directamente en Firebase junto con el grupo
    // No es necesario usar SharedPreferences
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

  // Método para reordenar gastos dentro de un subgrupo específico
  Future<void> _reorderSubgroupExpenses(int subgroupIndex, int oldIndex, int newIndex) async {
    print('DEBUG: _reorderSubgroupExpenses called - subgroupIndex: $subgroupIndex, oldIndex: $oldIndex, newIndex: $newIndex');
    
    if (subgroupIndex >= _subgroups.length) {
      print('DEBUG: Invalid subgroup index, returning early');
      return;
    }
    
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      
      // Obtener la lista actual de gastos del subgrupo
      final currentExpenses = List<Gasto>.from(_subgroups[subgroupIndex].expenses);
      
      // Reordenar los gastos
      final movedExpense = currentExpenses.removeAt(oldIndex);
      currentExpenses.insert(newIndex, movedExpense);
      
      // Actualizar el subgrupo con la nueva lista ordenada
      _subgroups[subgroupIndex] = _subgroups[subgroupIndex].copyWith(
        expenses: currentExpenses,
      );
      
      // Actualizar el campo expenseOrder si existe
      if (_subgroups[subgroupIndex].expenseOrder != null) {
        final currentOrder = List<String>.from(_subgroups[subgroupIndex].expenseOrder!);
        if (oldIndex < currentOrder.length && newIndex < currentOrder.length) {
          final movedId = currentOrder.removeAt(oldIndex);
          currentOrder.insert(newIndex, movedId);
          _subgroups[subgroupIndex] = _subgroups[subgroupIndex].copyWith(
            expenseOrder: currentOrder,
          );
        }
      }
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
        // Generar ID único para la imagen
        final String imageId = DateTime.now().millisecondsSinceEpoch.toString();
        
        // Mostrar un indicador de carga localmente
        setState(() {
          _imagenes[imageId] = {
            'loading': true,
            'valor': 0.0,
            'esAFavor': true
          };
          _imageOrder.add(imageId);
        });

        try {
          // Procesar imagen fragmentada para evitar límite de Firestore
          final Map<String, dynamic> imagenFragmentada = await _storageService.procesarImagenFragmentada(imageFile: image);
          
          setState(() {
            // Preservar los campos valor y esAFavor al actualizar con la imagen procesada
            final valorActual = _imagenes[imageId]?['valor'] ?? 0.0;
            final esAFavorActual = _imagenes[imageId]?['esAFavor'] ?? true;
            _imagenes[imageId] = imagenFragmentada;
            _imagenes[imageId]!['valor'] = valorActual;
            _imagenes[imageId]!['esAFavor'] = esAFavorActual;
          });
          
          _saveElementOrder();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al procesar la imagen: $e')),
            );
            // Eliminar la imagen si falla la carga
            setState(() {
              _imagenes.remove(imageId);
              _imageOrder.remove(imageId);
            });
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
    setState(() {
      if (_imagenes.containsKey(imageId)) {
        _imagenes[imageId]!['descripcion'] = description;
      }
    });
  }

  void _updateImageValue(String imageId, double? valor, bool? esAFavor) {
    setState(() {
      if (_imagenes.containsKey(imageId)) {
        _imagenes[imageId]!['valor'] = valor;
        _imagenes[imageId]!['esAFavor'] = esAFavor;
        _calculateTotal();
      }
    });
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

      // Crear o actualizar el orden de gastos
      final expenseOrder = gastos.map((gasto) => gasto.id ?? 'expense_${gastos.indexOf(gasto)}').toList();

      _subgroups[subgroupIndex] = _subgroups[subgroupIndex].copyWith(
        expenses: gastos,
        subtotal: subtotal,
        expenseOrder: expenseOrder,
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

      // Agregar totales de imágenes
      _imagenes.forEach((imageId, imageData) {
        if (imageData['valor'] != null && imageData['esAFavor'] != null) {
          double valor = (imageData['valor'] as num).toDouble();
          bool esAFavor = imageData['esAFavor'] as bool;
          total += esAFavor ? valor : -valor;
        }
      });

      return total;
    } catch (e) {
      print('Error al calcular total: $e');
      return 0.0;
    }
  }

  // Método para mover un gasto individual a un subgrupo
  Future<void> _moveExpenseToSubgroup(int expenseIndex, int subgroupIndex) async {
    print('DEBUG: _moveExpenseToSubgroup called - expenseIndex: $expenseIndex, subgroupIndex: $subgroupIndex');
    print('DEBUG: _expenseOrder.length: ${_expenseOrder.length}, _subgroups.length: ${_subgroups.length}');
    
    if (expenseIndex >= _expenseOrder.length || subgroupIndex >= _subgroups.length) {
      print('DEBUG: Invalid indices in _moveExpenseToSubgroup, returning early');
      return;
    }
    
    final expenseId = _expenseOrder[expenseIndex];
    final gastoIndex = _expenses.indexWhere((g) => (g.id ?? 'expense_${_expenses.indexOf(g)}') == expenseId);
    
    if (gastoIndex == -1) {
      print('DEBUG: Gasto not found in _expenses, returning early');
      return;
    }
    
    final gasto = _expenses[gastoIndex];
    print('DEBUG: Moving gasto: ${gasto.nombre} to subgroup: ${_subgroups[subgroupIndex].subgroupName}');
    
    setState(() {
      // Remover el gasto de la lista principal (primero de _expenseOrder, luego de _expenses)
      _expenseOrder.removeAt(expenseIndex);
      _expenses.removeAt(gastoIndex);
      
      // Crear una nueva instancia del gasto con ID único para evitar conflictos de keys
      final newGastoId = '${subgroupIndex}_${DateTime.now().millisecondsSinceEpoch}_${_subgroups[subgroupIndex].expenses.length}';
      final gastoForSubgroup = Gasto(
        id: newGastoId,
        nombre: gasto.nombre,
        valor: gasto.valor,
        fecha: gasto.fecha,
        esAFavor: gasto.esAFavor,
        archivado: gasto.archivado,
      );
      
      // Agregar el gasto al subgrupo
      _subgroups[subgroupIndex] = _subgroups[subgroupIndex].copyWith(
        expenses: [..._subgroups[subgroupIndex].expenses, gastoForSubgroup],
      );
      
      // Recalcular subtotal del subgrupo
      final newSubtotal = _subgroups[subgroupIndex].expenses.fold(0.0, (sum, g) => sum + g.valor);
      _subgroups[subgroupIndex] = _subgroups[subgroupIndex].copyWith(subtotal: newSubtotal);
    });
    
    print('DEBUG: Expense moved to subgroup successfully');
    _calculateTotal();
    await _saveElementOrder();
  }

  // Método para mover un gasto desde un subgrupo a la lista principal
  Future<void> _moveExpenseFromSubgroup(int subgroupIndex, int gastoIndex) async {
    if (subgroupIndex >= _subgroups.length || 
        gastoIndex >= _subgroups[subgroupIndex].expenses.length) {
      return;
    }
    
    final gasto = _subgroups[subgroupIndex].expenses[gastoIndex];
    
    setState(() {
      // Remover el gasto del subgrupo
      final updatedExpenses = List<Gasto>.from(_subgroups[subgroupIndex].expenses);
      updatedExpenses.removeAt(gastoIndex);
      
      _subgroups[subgroupIndex] = _subgroups[subgroupIndex].copyWith(
        expenses: updatedExpenses,
      );
      
      // Recalcular subtotal del subgrupo
      final newSubtotal = updatedExpenses.fold(0.0, (sum, g) => sum + g.valor);
      _subgroups[subgroupIndex] = _subgroups[subgroupIndex].copyWith(subtotal: newSubtotal);
      
      // Crear un nuevo ID único para evitar conflictos de keys
      final newExpenseId = 'expense_${DateTime.now().millisecondsSinceEpoch}_${_expenses.length}';
      
      // Crear una copia del gasto con el nuevo ID para la lista principal
      final gastoForMainList = Gasto(
        id: newExpenseId,
        nombre: gasto.nombre,
        valor: gasto.valor,
        fecha: gasto.fecha,
        esAFavor: gasto.esAFavor,
        archivado: gasto.archivado,
      );
      
      // Agregar el gasto a la lista principal
      _expenses.add(gastoForMainList);
      _expenseOrder.add(newExpenseId);
    });
    
    _calculateTotal();
    await _saveElementOrder();
  }

  // Método para mover un gasto entre subgrupos
  Future<void> _moveExpenseBetweenSubgroups(int sourceSubgroupIndex, int sourceExpenseIndex, int targetSubgroupIndex) async {
    print('DEBUG: _moveExpenseBetweenSubgroups called - sourceSubgroupIndex: $sourceSubgroupIndex, sourceExpenseIndex: $sourceExpenseIndex, targetSubgroupIndex: $targetSubgroupIndex');
    
    if (sourceSubgroupIndex >= _subgroups.length || 
        targetSubgroupIndex >= _subgroups.length ||
        sourceExpenseIndex >= _subgroups[sourceSubgroupIndex].expenses.length) {
      print('DEBUG: Invalid indices in _moveExpenseBetweenSubgroups, returning early');
      return;
    }
    
    final gasto = _subgroups[sourceSubgroupIndex].expenses[sourceExpenseIndex];
    print('DEBUG: Moving gasto: ${gasto.nombre} from subgroup: ${_subgroups[sourceSubgroupIndex].subgroupName} to subgroup: ${_subgroups[targetSubgroupIndex].subgroupName}');
    
    setState(() {
      // Remover el gasto del subgrupo origen
      final sourceUpdatedExpenses = List<Gasto>.from(_subgroups[sourceSubgroupIndex].expenses);
      sourceUpdatedExpenses.removeAt(sourceExpenseIndex);
      
      _subgroups[sourceSubgroupIndex] = _subgroups[sourceSubgroupIndex].copyWith(
        expenses: sourceUpdatedExpenses,
      );
      
      // Recalcular subtotal del subgrupo origen
      final sourceNewSubtotal = sourceUpdatedExpenses.fold(0.0, (sum, g) => sum + g.valor);
      _subgroups[sourceSubgroupIndex] = _subgroups[sourceSubgroupIndex].copyWith(subtotal: sourceNewSubtotal);
      
      // Preparar lista del subgrupo destino
      final targetUpdatedExpenses = List<Gasto>.from(_subgroups[targetSubgroupIndex].expenses);
      
      // Crear una nueva instancia del gasto con ID único para evitar conflictos de keys
      final newGastoId = '${targetSubgroupIndex}_${DateTime.now().millisecondsSinceEpoch}_${targetUpdatedExpenses.length}';
      final gastoForTargetSubgroup = Gasto(
        id: newGastoId,
        nombre: gasto.nombre,
        valor: gasto.valor,
        fecha: gasto.fecha,
        esAFavor: gasto.esAFavor,
        archivado: gasto.archivado,
      );
      
      // Agregar el gasto al subgrupo destino
      targetUpdatedExpenses.add(gastoForTargetSubgroup);
      
      _subgroups[targetSubgroupIndex] = _subgroups[targetSubgroupIndex].copyWith(
        expenses: targetUpdatedExpenses,
      );
      
      // Recalcular subtotal del subgrupo destino
      final targetNewSubtotal = targetUpdatedExpenses.fold(0.0, (sum, g) => sum + g.valor);
      _subgroups[targetSubgroupIndex] = _subgroups[targetSubgroupIndex].copyWith(subtotal: targetNewSubtotal);
    });
    
    print('DEBUG: Expense moved between subgroups successfully');
    _calculateTotal();
    await _saveElementOrder();
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
        expenseOrder: _expenseOrder,
        subgroupOrder: _subgroupOrder,
        imageOrder: _imageOrder,
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
                        color: colorProvider.colors.appBarColor,
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
                  // Lista de gastos individuales con DragTarget
                  DragTarget<Map<String, dynamic>>(
                    onWillAccept: (data) {
                      return data != null && data.containsKey('gasto') && data.containsKey('sourceType') && data['sourceType'] == 'subgroup';
                    },
                    onAccept: (data) {
                      final sourceSubgroupIndex = data['sourceSubgroupIndex'];
                      final sourceIndex = data['sourceIndex'];
                      
                      if (sourceSubgroupIndex != null && sourceIndex != null) {
                        _moveExpenseFromSubgroup(sourceSubgroupIndex, sourceIndex);
                      }
                    },
                    builder: (context, candidateData, rejectedData) {
                      return Container(
                        // Solo aplicar altura mínima cuando hay candidateData
                        constraints: _expenseOrder.isEmpty && candidateData.isNotEmpty
                            ? const BoxConstraints(minHeight: 80) 
                            : null,
                        decoration: candidateData.isNotEmpty
                            ? BoxDecoration(
                                border: Border.all(color: Colors.green, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              )
                            : null,
                        child: _expenseOrder.isEmpty
                            ? candidateData.isNotEmpty
                                ? Container(
                                    height: 80,
                                    child: Center(
                                      child: Text(
                                        'Suelta aquí para agregar a la lista principal',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 14,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )
                                : Container(
                                    height: 2, // Área mínima invisible para detectar arrastre
                                    width: double.infinity,
                                  )
                            : ReorderableListView.builder(
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
                                  
                                  return LongPressDraggable<Map<String, dynamic>>(
                                    key: ValueKey('main_expense_${expenseId}_${index}'),
                                    data: {
                                      'gasto': _expenses[expenseIndex],
                                      'sourceType': 'main',
                                      'sourceIndex': index,
                                    },
                                    feedback: Material(
                                      color: Colors.transparent,
                                      elevation: 0,
                                      child: Container(
                                        width: 300,
                                        child: GastoForm(
                                          gasto: _expenses[expenseIndex],
                                          index: index,
                                          onCancel: () {},
                                          onGastoChanged: (gasto) {},
                                        ),
                                      ),
                                    ),
                                    childWhenDragging: Container(
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: GastoForm(
                                      key: ValueKey('main_gastoform_${expenseId}_${index}'),
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
                                    ),
                                  );
                                },
                              ),
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
                            onMoveExpenseOut: (subgroupIdx, expenseIdx) =>
                                _moveExpenseFromSubgroup(subgroupIndex, expenseIdx),
                            onMoveExpenseIn: (sourceIndex, targetSubgroupIndex) =>
                                _moveExpenseToSubgroup(sourceIndex, subgroupIndex),
                            onMoveExpenseBetweenSubgroups: (sourceSubgroupIndex, sourceExpenseIndex, targetSubgroupIndex) =>
                                _moveExpenseBetweenSubgroups(sourceSubgroupIndex, sourceExpenseIndex, subgroupIndex),
                            onReorderExpenses: (oldIndex, newIndex) =>
                                _reorderSubgroupExpenses(subgroupIndex, oldIndex, newIndex),
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
                            // const SizedBox(height: 16),
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
                          color: colorProvider.colors.appBarColor,
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
                            // const SizedBox(height: 8),
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
                                  onValueChanged: (valor, esAFavor) => _updateImageValue(imageId, valor, esAFavor),
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
