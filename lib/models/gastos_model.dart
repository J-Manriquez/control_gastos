import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

enum GastoType { normal, shared }

// Modelo para representar un gasto
class Gasto {
  String? id; // Ya existe, pero modificaremos su manejo
  String nombre;
  double valor;
  DateTime fecha;
  bool esAFavor;

  Gasto({
    String?
        id, // Modificación: Hacer el id opcional pero generarlo si no se proporciona
    required this.nombre,
    required this.valor,
    required this.fecha,
    required this.esAFavor,
  }) : this.id =
            id ?? _generateId(); // Añadición: Generar ID si no se proporciona

  // Añadición: Método privado para generar ID único
  static String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${100000 + Random().nextInt(900000)}';
  }

  // Método para convertir un objeto Gasto a un Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id, // Asegurar que el ID siempre se incluya
      'nombre': nombre,
      'valor': valor,
      'fecha': fecha.toIso8601String(),
      'esAFavor': esAFavor,
    };
  }

  // Actualizar fromMap para manejar el ID
  factory Gasto.fromMap(Map<String, dynamic> map) {
    return Gasto(
      id: map['id'] as String?, // Manejar el ID explícitamente
      nombre: map['nombre'] ?? '',
      valor: (map['valor'] as num).toDouble(),
      fecha: DateTime.parse(map['fecha']),
      esAFavor: map['esAFavor'] ?? true,
    );
  }

  // Sobrescribe el método toString para proporcionar una representación en cadena del objeto
  @override
  String toString() {
    return 'Gasto(id: $id, nombre: $nombre, valor: $valor, fecha: ${fecha.toIso8601String()}, esAFavor: $esAFavor)';
  }
}

// Modelo para representar un subgrupo de gastos
class SubgroupModel {
  final String nombre; // Nombre del subgrupo
  final List<Gasto> expenses; // Lista de gastos en el subgrupo
  final double subtotal; // Total de gastos en el subgrupo

  SubgroupModel({
    required this.nombre,
    required this.expenses,
    required this.subtotal,
  });

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
      nombre: data['subgroupName'] ?? '',
      expenses: expenseList,
      subtotal: expenseList.fold(0.0, (sum, gasto) => sum + gasto.valor),
    );
  }

  // Convertir el subgrupo a un mapa para Firestore
  Map<String, dynamic> toMap() {
    return {
      'subgroupName': nombre,
      'expenses': expenses.map((e) => e.toMap()).toList(),
    };
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

  GroupModel({
    required this.id,
    required this.nombre,
    required this.total,
    required this.expenses,
    required this.subgroups,
    required this.creationDate,
    this.type = GastoType.normal,
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
    );

    // Recalcular el total usando el nuevo método
    group = GroupModel(
      id: group.id,
      nombre: group.nombre,
      total: group.calculateTotal(), // Usar el nuevo método aquí
      expenses: group.expenses,
      subgroups: group.subgroups,
      creationDate: group.creationDate,
    );

    return group;
  }

  // Modificar el método fromMap para usar calculateTotal
  factory GroupModel.fromMap(Map<String, dynamic> map) {
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
    );
  }

  // Modificar el método toMap para usar calculateTotal
  Map<String, dynamic> toMap() {
    return {
      'groupName': nombre,
      'total': total,
      'expenses': expenses.map((e) => e.toMap()).toList(),
      'subgroups': subgroups.map((s) => s.toMap()).toList(),
      'creationDate': creationDate.toIso8601String(),
      'type': type.toString(),
    };
  }

  @override
  String toString() {
    return 'GroupModel{id: $id, nombre: $nombre, total: $total, '
        'expenses: $expenses, subgroups: $subgroups, '
        'creationDate: $creationDate}';
  }
}
