class Quote {
  final String id;
  final String sentence;
  final String author;

  Quote({required this.id, required this.sentence, required this.author});

  factory Quote.fromMap(Map<String, dynamic> data, String documentId) {
    return Quote(
      id: documentId,
      sentence: data['sentence'] ?? '',
      author: data['author'] ?? '',
    );
  }
}
