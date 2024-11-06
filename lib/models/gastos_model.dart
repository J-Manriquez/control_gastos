import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo para representar un gasto
class Gasto {
  String? id;           // ID del gasto, puede ser null si es un nuevo gasto
  String nombre;        // Nombre del gasto
  double valor;         // Valor del gasto
  DateTime fecha;       // Fecha del gasto
  bool esAFavor;        // Indica si el gasto es a favor o en contra

  Gasto({
    this.id,
    required this.nombre,
    required this.valor,
    required this.fecha,
    required this.esAFavor,
  });

  // Método para convertir un objeto Gasto a un Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'valor': valor,
      'fecha': fecha.toIso8601String(), // Convierte la fecha a String
      'esAFavor': esAFavor,
    };
  }

  // Método para crear una instancia de Gasto a partir de un Map
  factory Gasto.fromMap(Map<String, dynamic> map) {
    return Gasto(
      id: map['id'], // ID puede ser null
      nombre: map['nombre'] ?? '',
      valor: (map['valor'] as num).toDouble(), // Asegura el tipo double
      fecha: DateTime.parse(map['fecha']), // Convierte String a DateTime
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
  final String nombre;        // Nombre del subgrupo
  final List<Gasto> expenses; // Lista de gastos en el subgrupo
  final double subtotal;      // Total de gastos en el subgrupo

  SubgroupModel({
    required this.nombre,
    required this.expenses,
    required this.subtotal,
  });

  // Crear una instancia de SubgroupModel desde un mapa
  factory SubgroupModel.fromMap(Map<String, dynamic> data) {
    List<Gasto> expenseList = (data['expenses'] as List<dynamic>? ?? [])
        .map((item) => Gasto.fromMap(item))
        .toList();

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
  final String id;                        // ID del grupo
  final String nombre;                    // Nombre del grupo
  final double total;                     // Total de gastos en el grupo
  final List<Gasto> expenses;             // Lista de gastos en el grupo
  final List<SubgroupModel> subgroups;    // Lista de subgrupos
  final DateTime creationDate;            // Fecha de creación del grupo

  GroupModel({
    required this.id,
    required this.nombre,
    required this.total,
    required this.expenses,
    required this.subgroups,
    required this.creationDate,
  });

  // Crear una instancia de GroupModel desde un documento de Firestore
  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Convertir gastos principales
    List<Gasto> expenseList = (data['expenses'] as List<dynamic>? ?? [])
        .map((item) => Gasto.fromMap(item))
        .toList();

    // Convertir subgrupos
    List<SubgroupModel> subgroupsList = (data['subgroups'] as List<dynamic>? ?? [])
        .map((item) => SubgroupModel.fromMap(item))
        .toList();

    return GroupModel(
      id: doc.id,  // ID del documento en Firestore
      nombre: data['groupName'] ?? '',  // Nombre del grupo
      total: (data['total'] ?? 0).toDouble(),  // Total de los gastos
      expenses: expenseList,  // Lista de gastos
      subgroups: subgroupsList,  // Lista de subgrupos
      creationDate: data['creationDate'] is Timestamp
          ? (data['creationDate'] as Timestamp).toDate()
          : DateTime.parse(data['creationDate'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Crear una instancia de GroupModel desde un mapa
  factory GroupModel.fromMap(Map<String, dynamic> data) {
    List<Gasto> expenseList = (data['expenses'] as List<dynamic>? ?? [])
        .map((item) => Gasto.fromMap(item))
        .toList();

    List<SubgroupModel> subgroupsList = (data['subgroups'] as List<dynamic>? ?? [])
        .map((item) => SubgroupModel.fromMap(item))
        .toList();

    return GroupModel(
      id: data['id'] ?? '',
      nombre: data['groupName'] ?? '',
      total: (data['total'] ?? 0).toDouble(),
      expenses: expenseList,
      subgroups: subgroupsList,
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
