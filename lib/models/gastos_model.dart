import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/utils/custom_logger.dart';

enum GastoType { normal, shared }

// Modelo para representar un gasto
class Gasto {
  String? id;
  String nombre;
  double valor;
  DateTime fecha;
  bool esAFavor;
  bool archivado;
  bool? isTracked; // Campo opcional para seguimiento

  Gasto({
    String? id,
    required this.nombre,
    required this.valor,
    required this.fecha,
    required this.esAFavor,
    this.archivado = false, // Por defecto, los gastos no están archivados
  }) : this.id = id ?? _generateId();

  // Método privado para generar ID único
  static String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${100000 + Random().nextInt(900000)}';
  }

  // Método para convertir un objeto Gasto a un Map para Firestore
  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'nombre': nombre,
      'valor': valor,
      'fecha': fecha.toIso8601String(),
      'esAFavor': esAFavor,
      'archivado': archivado,
    };
    
    // Solo incluir isTracked si es true
    if (isTracked == true) {
      map['isTracked'] = isTracked!;
    }
    
    return map;
  }

  // Actualizar fromMap para manejar isTracked
  factory Gasto.fromMap(Map<String, dynamic> map) {
    return Gasto(
      id: map['id'] as String?,
      nombre: map['nombre'] ?? '',
      valor: (map['valor'] as num).toDouble(),
      fecha: DateTime.parse(map['fecha']),
      esAFavor: map['esAFavor'] ?? true,
      archivado: map['archivado'] ?? false,
    )..isTracked = map['isTracked']; // Asignar isTracked después de la construcción
  }

 

  // Actualizar el método toString para incluir el campo archivado
  @override
  String toString() {
    return 'Gasto(id: $id, nombre: $nombre, valor: $valor, fecha: ${fecha.toIso8601String()}, esAFavor: $esAFavor, archivado: $archivado)';
  }

  // Actualizar el método copyWith para incluir isTracked
  Gasto copyWith({
    String? id,
    String? nombre,
    double? valor,
    DateTime? fecha,
    bool? esAFavor,
    bool? archivado,
    bool? isTracked,
  }) {
    return Gasto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      valor: valor ?? this.valor,
      fecha: fecha ?? this.fecha,
      esAFavor: esAFavor ?? this.esAFavor,
      archivado: archivado ?? this.archivado,
    )..isTracked = isTracked ?? this.isTracked;
  }
}

// Modelo para representar un subgrupo de gastos
class SubgroupModel {
  final String id; // Add this new field
  final String subgroupName;
  final List<Gasto> expenses;
  final double subtotal;
  final List<String>? expenseOrder; // Orden de gastos dentro del subgrupo
  bool? isTracked; // Campo opcional para seguimiento

  SubgroupModel({
    String? id, // Make it optional with default generation
    required this.subgroupName,
    required this.expenses,
    required this.subtotal,
    this.expenseOrder,
  }) : id = id ?? _generateId(); // Generate ID if not provided

  // Helper method to generate unique IDs
  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           (1000 + (DateTime.now().microsecond % 9000)).toString();
  }

  double calculateSubtotal() {
    return expenses.fold(0.0, (sum, gasto) {
      // Asegurar que el valor es numérico
      return sum + (gasto.valor is double ? gasto.valor : 0.0);
    });
  }

  // Crear una instancia de SubgroupModel desde un mapa
  factory SubgroupModel.fromMap(Map<String, dynamic> data) {
    List<Gasto> expenseList = (data['expenses'] as List<dynamic>? ?? [])
        .map((item) => Gasto.fromMap(item))
        .toList();

    return SubgroupModel(
      id: data['id'] ?? _generateId(), // Generate if not present
      subgroupName: data['subgroupName'] ?? '',
      expenses: expenseList,
      subtotal: expenseList.fold(0.0, (sum, gasto) => sum + gasto.valor),
      expenseOrder: (data['expenseOrder'] as List<dynamic>?)?.cast<String>(),
    );
  }

  // Update toMap to include id
  Map<String, dynamic> toMap() {
    CustomLogger().logInfo('Serializando SubgroupModel con nombre: $subgroupName');
    final map = {
      'id': id, // Include the id
      'subgroupName': subgroupName,
      'expenses': expenses.map((e) => e.toMap()).toList(),
    };
    
    // Incluir expenseOrder si está disponible
    if (expenseOrder != null) {
      map['expenseOrder'] = expenseOrder!;
    }
    
    return map;
  }

  // Add copyWith method for easier updates
  SubgroupModel copyWith({
    String? id,
    String? subgroupName,
    List<Gasto>? expenses,
    double? subtotal,
    List<String>? expenseOrder,
  }) {
    return SubgroupModel(
      id: id ?? this.id,
      subgroupName: subgroupName ?? this.subgroupName,
      expenses: expenses ?? this.expenses,
      subtotal: subtotal ?? this.subtotal,
      expenseOrder: expenseOrder ?? this.expenseOrder,
    );
  }
  // Add this method to SubgroupModel class
  static SubgroupModel migrateFromLegacy(SubgroupModel legacy, {List<String>? legacyExpenseOrder}) {
    // Si hay un orden heredado, usarlo; si no, generar uno basado en los gastos actuales
    final expenseOrder = legacyExpenseOrder ?? 
        legacy.expenses.map((gasto) => gasto.id ?? 'expense_${legacy.expenses.indexOf(gasto)}').toList();
    
    return SubgroupModel(
      id: _generateId(), // Generate new ID for legacy subgroups
      subgroupName: legacy.subgroupName,
      expenses: legacy.expenses,
      subtotal: legacy.subtotal,
      expenseOrder: expenseOrder,
    );
  }
}

// Modelo principal para grupos de gastos
class GroupModel {
  final String id;
  final String nombre;
  final double total;
  final List<Gasto> expenses;
  final List<SubgroupModel> subgroups;
  final DateTime creationDate;
  final GastoType type;
  final bool archivado; // Nuevo campo para controlar el estado archivado
  final Map<String, Map<String, dynamic>>? imagenes; // Mapa de mapas para imagenes e inf adicional
  // Campos para el orden de elementos
  final List<String>? expenseOrder;
  final List<String>? subgroupOrder;
  final List<String>? imageOrder;

  GroupModel({
    required this.id,
    required this.nombre,
    required this.total,
    required this.expenses,
    required this.subgroups,
    required this.creationDate,
    this.type = GastoType.normal,
    this.archivado = false, // Por defecto, los grupos no están archivados
    this.imagenes,
    this.expenseOrder,
    this.subgroupOrder,
    this.imageOrder,
  });

  // Añadir este nuevo método
  double calculateTotal() {
    // Calcular total de gastos principales asegurando valores numéricos
    double total = expenses.fold(0.0, (sum, expense) {
      // Asegurar que el valor es numérico
      return sum + (expense.valor is double ? expense.valor : 0.0);
    });

    // Calcular total de subgrupos
    total += subgroups.fold(0.0, (sum, subgroup) {
      return sum +
          subgroup.expenses.fold(0.0, (subSum, expense) {
            // Asegurar que el valor es numérico
            return subSum + (expense.valor is double ? expense.valor : 0.0);
          });
    });

    return total;
  }

  // Modificar el método fromFirestore para usar calculateTotal
  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Convertir gastos principales
    List<Gasto> expenseList = (data['expenses'] as List<dynamic>? ?? [])
        .map((item) => Gasto.fromMap(item))
        .toList();

    // Convertir subgrupos
    List<SubgroupModel> subgroupsList =
        (data['subgroups'] as List<dynamic>? ?? [])
            .map((item) => SubgroupModel.fromMap(item))
            .toList();

    // Convertir imágenes
    Map<String, Map<String, dynamic>>? imagenesMap;
    if (data['imagenes'] != null) {
      imagenesMap = Map<String, Map<String, dynamic>>.from(
        data['imagenes'] as Map<String, dynamic>
      );
    }

    GroupModel group = GroupModel(
      id: doc.id,
      nombre: data['groupName'] ?? '',
      total: (data['total'] ?? 0).toDouble(),
      expenses: expenseList,
      subgroups: subgroupsList,
      creationDate: data['creationDate'] is Timestamp
          ? (data['creationDate'] as Timestamp).toDate()
          : DateTime.parse(
              data['creationDate'] ?? DateTime.now().toIso8601String()),
      imagenes: imagenesMap,
      expenseOrder: data['expenseOrder'] != null ? List<String>.from(data['expenseOrder']) : null,
      subgroupOrder: data['subgroupOrder'] != null ? List<String>.from(data['subgroupOrder']) : null,
      imageOrder: data['imageOrder'] != null ? List<String>.from(data['imageOrder']) : null,
    );

    // Recalcular el total usando el nuevo método
    group = GroupModel(
      id: group.id,
      nombre: group.nombre,
      total: group.calculateTotal(), // Usar el nuevo método aquí
      expenses: group.expenses,
      subgroups: group.subgroups,
      creationDate: group.creationDate,
      imagenes: group.imagenes,
      expenseOrder: group.expenseOrder,
      subgroupOrder: group.subgroupOrder,
      imageOrder: group.imageOrder,
    );

    return group;
  }

  // Modificar el método fromMap para usar calculateTotal
  factory GroupModel.fromMap(Map<String, dynamic> map) {
    // Convertir imágenes - procesar imágenes fragmentadas
    Map<String, Map<String, dynamic>>? imagenesMap;
    if (map['imagenes'] != null) {
      final imagenesRaw = map['imagenes'] as Map<String, dynamic>;
      imagenesMap = <String, Map<String, dynamic>>{};
      
      for (final entry in imagenesRaw.entries) {
        final imageId = entry.key;
        final imageData = entry.value as Map<String, dynamic>;
        
        // Si es una imagen fragmentada, reconstruirla
        if (imageData.containsKey('fragmentos')) {
          imagenesMap[imageId] = imageData; // Mantener fragmentada para uso posterior
        } else {
          // Imagen normal (base64 directo)
          imagenesMap[imageId] = imageData;
        }
      }
    }

    return GroupModel(
      id: map['id'] ?? '',
      nombre: map['groupName'] ?? '',
      total: (map['total'] as num).toDouble(),
      expenses: (map['expenses'] as List<dynamic>)
          .map((e) => Gasto.fromMap(e))
          .toList(),
      subgroups: (map['subgroups'] as List<dynamic>)
          .map((s) => SubgroupModel.fromMap(s))
          .toList(),
      creationDate: DateTime.parse(map['creationDate']),
      type: map['type'] != null
          ? GastoType.values.firstWhere(
              (e) => e.toString() == map['type'],
              orElse: () => GastoType.normal,
            )
          : GastoType.normal,
      archivado: map['archivado'] ?? false, // Leer el campo archivado del mapa
      imagenes: imagenesMap,
      expenseOrder: map['expenseOrder'] != null ? List<String>.from(map['expenseOrder']) : null,
      subgroupOrder: map['subgroupOrder'] != null ? List<String>.from(map['subgroupOrder']) : null,
      imageOrder: map['imageOrder'] != null ? List<String>.from(map['imageOrder']) : null,
    );
  }

  // Modificar el método toMap para usar calculateTotal
  Map<String, dynamic> toMap() {
    final map = {
      'groupName': nombre,
      'total': total,
      'expenses': expenses.map((e) => e.toMap()).toList(),
      'subgroups': subgroups.map((s) => s.toMap()).toList(),
      'creationDate': creationDate.toIso8601String(),
      'type': type.toString(),
      'archivado': archivado,
    };
    
    // Siempre incluir el campo imagenes para permitir eliminación correcta
    map['imagenes'] = imagenes ?? {};
    
    // Incluir campos de orden si están disponibles
    if (expenseOrder != null) map['expenseOrder'] = expenseOrder!;
    if (subgroupOrder != null) map['subgroupOrder'] = subgroupOrder!;
    if (imageOrder != null) map['imageOrder'] = imageOrder!;
    
    return map;
  }

  @override
  String toString() {
    return 'GroupModel{id: $id, nombre: $nombre, total: $total, '
        'expenses: $expenses, subgroups: $subgroups, archivado: $archivado, '
        'creationDate: $creationDate, imagenes: $imagenes}';
  }
}
