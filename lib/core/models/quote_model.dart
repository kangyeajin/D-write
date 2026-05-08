import 'package:cloud_firestore/cloud_firestore.dart';

class Quote {
  final String id;
  final String sentence;
  final String author;
  final int month;
  final List<String> weatherTags;
  final DateTime? createdAt;

  Quote({
    required this.id,
    required this.sentence,
    required this.author,
    required this.month,
    required this.weatherTags,
    this.createdAt,
  });

  factory Quote.fromMap(Map<String, dynamic> data, String documentId) {
    return Quote(
      id: documentId,
      sentence: (data['sentence'] as String?) ?? '',
      author: (data['author'] as String?) ?? '',
      month: (data['month'] as int?) ?? DateTime.now().month,
      weatherTags: List<String>.from((data['weatherTags'] as List?) ?? ['All']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
