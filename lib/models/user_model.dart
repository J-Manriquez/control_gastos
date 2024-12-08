class UserModel {
  final String uid;
  final String username;
  final String email;
  final String userShortId;
  final DateTime creationDate;
  final String userType;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    required this.userShortId,
    required this.creationDate,
    this.userType = 'free',
  });

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'userShortId': userShortId.toLowerCase(), // Guardamos en minúsculas
      'creationDate': creationDate,
      'userType': userType,
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
    );
  }
}