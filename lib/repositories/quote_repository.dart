import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:d_write/core/models/quote_model.dart';

class QuoteRepository {
  final FirebaseFirestore _db;

  QuoteRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Future<Quote?> getRandomQuote() async {
    try {
      final snapshot = await _db.collection('quotes').get();
      if (snapshot.docs.isEmpty) return null;
      final docs = snapshot.docs..shuffle();
      return Quote.fromMap(docs.first.data(), docs.first.id);
    } on FirebaseException catch (e) {
      debugPrint('QuoteRepository.getRandomQuote error [${e.code}]: ${e.message}');
      return null;
    }
  }

  Future<Quote?> getQuote(String quoteId) async {
    try {
      final doc = await _db.collection('quotes').doc(quoteId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Quote.fromMap(doc.data()!, doc.id);
    } on FirebaseException catch (e) {
      debugPrint('QuoteRepository.getQuote error [${e.code}]: ${e.message}');
      return null;
    }
  }

  Future<List<Quote>> getQuotesByMonth(int month) async {
    try {
      final snapshot = await _db
          .collection('quotes')
          .where('month', isEqualTo: month)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => Quote.fromMap(doc.data(), doc.id))
          .toList();
    } on FirebaseException catch (e) {
      debugPrint('QuoteRepository.getQuotesByMonth error [${e.code}]: ${e.message}');
      return [];
    }
  }

  Future<void> addQuote({
    required String sentence,
    required String author,
    required int month,
    required List<String> weatherTags,
  }) async {
    try {
      await _db.collection('quotes').add({
        'sentence': sentence,
        'author': author,
        'month': month,
        'weatherTags': weatherTags,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      debugPrint('QuoteRepository.addQuote error [${e.code}]: ${e.message}');
      rethrow;
    }
  }

  Future<void> updateQuote(String quoteId, String sentence, String author) async {
    try {
      await _db.collection('quotes').doc(quoteId).update({
        'sentence': sentence,
        'author': author,
      });
    } on FirebaseException catch (e) {
      debugPrint('QuoteRepository.updateQuote error [${e.code}]: ${e.message}');
      rethrow;
    }
  }

  Future<void> deleteQuote(String quoteId) async {
    try {
      await _db.collection('quotes').doc(quoteId).delete();
    } on FirebaseException catch (e) {
      debugPrint('QuoteRepository.deleteQuote error [${e.code}]: ${e.message}');
      rethrow;
    }
  }

  /// 최대 500개씩 WriteBatch로 나눠 일괄 저장
  Future<int> bulkAddQuotes(List<Map<String, dynamic>> rows) async {
    const batchSize = 400;
    int saved = 0;
    for (int i = 0; i < rows.length; i += batchSize) {
      final chunk = rows.sublist(i, (i + batchSize).clamp(0, rows.length));
      final batch = _db.batch();
      for (final row in chunk) {
        final ref = _db.collection('quotes').doc();
        batch.set(ref, {
          ...row,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      saved += chunk.length;
    }
    return saved;
  }
}
