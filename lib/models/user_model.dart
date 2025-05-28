class UserModel {
  final String uid;
  final String username;
  final String email;
  final String userShortId;
  final DateTime creationDate;
  final String userType;
  final Map<String, List<String>> friendsList;
  final Map<String, dynamic> sharedExpensesMap; // Cambiado de List<String> a Map

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    required this.userShortId,
    required this.creationDate,
    this.userType = 'free',
    this.friendsList = const {'accepted': [], 'pending': [], 'blocked': []},
    this.sharedExpensesMap = const {}, // Inicialización por defecto como mapa vacío
  });

  // Getter para obtener la lista de IDs de gastos compartidos
  List<String> get sharedExpensesList => sharedExpensesMap.keys.toList();

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'userShortId': userShortId.toLowerCase(), // Guardamos en minúsculas
      'creationDate': creationDate,
      'userType': userType,
      'friendsList': friendsList,
      'sharedExpensesMap': sharedExpensesMap,
    };
  }

  // Crear desde Map de Firestore
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      userShortId: map['userShortId'] ?? '',
      creationDate: map['creationDate']?.toDate() ?? DateTime.now(),
      userType: map['userType'] ?? 'free',
      friendsList: (map['friendsList'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              (value as List<dynamic>?)?.map((e) => e.toString()).toList() ??
                  [],
            ),
          ) ??
          {'accepted': [], 'pending': [], 'blocked': []},
      // Si existe sharedExpensesMap, usarlo; si no, convertir la lista antigua a mapa
      sharedExpensesMap: map['sharedExpensesMap'] ?? 
          Map.fromIterable(
            List<String>.from(map['sharedExpensesList'] ?? []),
            key: (item) => item,
            value: (_) => {'archivado': false}
          ),
    );
  }
}
