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

  // Añadir este nuevo método
  double calculateTotal() {
    double total = expenses.fold(0.0, (sum, expense) => sum + expense.valor);
    total += subgroups.fold(0.0, (sum, subgroup) {
      return sum + subgroup.expenses.fold(0.0, (subSum, expense) => subSum + expense.valor);
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
    List<SubgroupModel> subgroupsList = (data['subgroups'] as List<dynamic>? ?? [])
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
          : DateTime.parse(data['creationDate'] ?? DateTime.now().toIso8601String()),
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
  factory GroupModel.fromMap(Map<String, dynamic> data) {
    List<Gasto> expenseList = (data['expenses'] as List<dynamic>? ?? [])
        .map((item) => Gasto.fromMap(item))
        .toList();

    List<SubgroupModel> subgroupsList = (data['subgroups'] as List<dynamic>? ?? [])
        .map((item) => SubgroupModel.fromMap(item))
        .toList();

    GroupModel group = GroupModel(
      id: data['id'] ?? '',
      nombre: data['groupName'] ?? '',
      total: (data['total'] ?? 0).toDouble(),
      expenses: expenseList,
      subgroups: subgroupsList,
      creationDate: data['creationDate'] is Timestamp
          ? (data['creationDate'] as Timestamp).toDate()
          : DateTime.parse(data['creationDate'] ?? DateTime.now().toIso8601String()),
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

  // Modificar el método toMap para usar calculateTotal
  Map<String, dynamic> toMap() {
    return {
      'groupName': nombre,
      'total': calculateTotal(), // Usar el nuevo método aquí
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