class FriendRequestModel {
  final String requestId;
  final String fromUserId;
  final String toUserId;
  final String status; // 'pending', 'accepted', 'rejected', 'blocked'
  final DateTime timestamp;

  FriendRequestModel({
    required this.requestId,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': status,
      'timestamp': timestamp,
    };
  }

  factory FriendRequestModel.fromMap(Map<String, dynamic> map) {
    return FriendRequestModel(
      requestId: map['requestId'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      status: map['status'] ?? 'pending',
      timestamp: map['timestamp']?.toDate() ?? DateTime.now(),
    );
  }
}