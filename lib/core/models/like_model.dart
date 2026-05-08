import 'package:cloud_firestore/cloud_firestore.dart';

class Like {
  final String id;
  final String userId;
  final String quoteId;
  final String date; // "YYYY-MM-DD"
  final Timestamp createdAt;

  const Like({
    required this.id,
    required this.userId,
    required this.quoteId,
    required this.date,
    required this.createdAt,
  });

  factory Like.fromMap(Map<String, dynamic> data, String documentId) {
    return Like(
      id: documentId,
      userId: (data['userId'] as String?) ?? '',
      quoteId: (data['quoteId'] as String?) ?? '',
      date: (data['date'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?) ?? Timestamp.now(),
    );
  }
}
