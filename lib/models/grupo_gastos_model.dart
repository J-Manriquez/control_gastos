import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/gastos_model.dart';

// Modelo para representar un subgrupo de gastos
class SubgroupModel {
  final String nombre;
  final List<Gasto> expenses;
  final double subtotal;

  SubgroupModel({
    required this.nombre,
    required this.expenses,
    required this.subtotal,
  });

  // Crear una instancia de SubgroupModel desde un mapa
  factory SubgroupModel.fromMap(Map<String, dynamic> data) {
    List<Gasto> expenseList = (data['expenses'] as List<dynamic>?)
            ?.map((item) => Gasto.fromMap(item))
            .toList() ??
        [];

    return SubgroupModel(
      nombre: data['subgroupName'] ?? '',
      expenses: expenseList,
      subtotal: expenseList.fold(0, (sum, gasto) => sum + gasto.valor),
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

  GroupModel({
    required this.id,
    required this.nombre,
    required this.total,
    required this.expenses,
    required this.subgroups,
    required this.creationDate,
  });

  // Crear una instancia de GroupModel desde un documento de Firestore
  factory GroupModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Convertir gastos principales
    List<Gasto> expenseList = (data['expenses'] as List<dynamic>?)
            ?.map((item) => Gasto.fromMap(item))
            .toList() ??
        [];

    // Convertir subgrupos
    List<SubgroupModel> subgroupsList = (data['subgroups'] as List<dynamic>?)
            ?.map((item) => SubgroupModel.fromMap(item))
            .toList() ??
        [];

    return GroupModel(
      id: doc.id,
      nombre: data['groupName'] ?? '',
      total: (data['total'] ?? 0).toDouble(),
      expenses: expenseList,
      subgroups: subgroupsList,
      // Ajuste para verificar si creationDate es un Timestamp y convertirlo a DateTime
      creationDate: data['creationDate'] is Timestamp
          ? (data['creationDate'] as Timestamp).toDate()
          : DateTime.parse(data['creationDate'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Crear una instancia de GroupModel desde un mapa
  factory GroupModel.fromMap(Map<String, dynamic> data) {
    List<Gasto> expenseList = (data['expenses'] as List<dynamic>?)
            ?.map((item) => Gasto.fromMap(item))
            .toList() ??
        [];

    List<SubgroupModel> subgroupsList = (data['subgroups'] as List<dynamic>?)
            ?.map((item) => SubgroupModel.fromMap(item))
            .toList() ??
        [];

    return GroupModel(
      id: data['id'] ?? '',
      nombre: data['groupName'] ?? '',
      total: (data['total'] ?? 0).toDouble(),
      expenses: expenseList,
      subgroups: subgroupsList,
      // Aquí también verificamos si es Timestamp
      creationDate: data['creationDate'] is Timestamp
          ? (data['creationDate'] as Timestamp).toDate()
          : DateTime.parse(data['creationDate'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Convertir el grupo a un mapa para Firestore
  Map<String, dynamic> toMap() {
    return {
      'groupName': nombre,
      'total': total,
      'expenses': expenses.map((e) => e.toMap()).toList(),
      'subgroups': subgroups.map((s) => s.toMap()).toList(),
      'creationDate': creationDate.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'GroupModel{id: $id, nombre: $nombre, total: $total, '
        'expenses: $expenses, subgroups: $subgroups, '
        'creationDate: $creationDate}';
  }
}
