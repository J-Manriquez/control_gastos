import 'package:cloud_firestore/cloud_firestore.dart';

enum VoteStatus {
  pending,
  accepted,
  rejected
}

class VersionVoteModel {
  final String userId;
  final VoteStatus status;
  final DateTime timestamp;

  VersionVoteModel({
    required this.userId,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'status': status.toString(),
      'timestamp': timestamp,
    };
  }

  factory VersionVoteModel.fromMap(Map<String, dynamic> map) {
    return VersionVoteModel(
      userId: map['userId'],
      status: VoteStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => VoteStatus.pending,
      ),
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}