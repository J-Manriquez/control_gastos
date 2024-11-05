class Gasto {
  String? id;           // ID del gasto, puede ser null si es un nuevo gasto
  String nombre;        // Nombre del gasto
  double valor;         // Valor del gasto
  DateTime fecha;       // Fecha del gasto
  bool esAFavor; 

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
