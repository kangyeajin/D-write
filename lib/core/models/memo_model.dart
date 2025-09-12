import 'package:cloud_firestore/cloud_firestore.dart';

class Memo {
  final String id;
  final String quoteId;
  final String userId;
  final String content;
  final Timestamp createdAt;

  Memo({
    required this.id,
    required this.quoteId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  factory Memo.fromMap(Map<String, dynamic> data, String documentId) {
    return Memo(
      id: documentId,
      quoteId: data['quoteId'] ?? '',
      userId: data['userId'] ?? '',
      content: data['content'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}
