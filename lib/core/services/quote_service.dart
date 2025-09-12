import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:d_write/core/models/quote_model.dart';
import 'package:logger/logger.dart';

Logger logger = Logger();

abstract class IQuoteService {
  Future<Quote?> getQuote(String quoteId);
  Future<void> addQuote(String sentence, String author);
  Future<void> updateQuote(String quoteId, String sentence, String author);
  Future<Quote?> getRandomQuote();
}

class QuoteService implements IQuoteService {
  final FirebaseFirestore _firestore;

  QuoteService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Quote?> getQuote(String quoteId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('quotes').doc(quoteId).get();
      if (doc.exists) {
        return Quote.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (e) {
      logger.i(e);
    }
    return null;
  }

  @override
  Future<void> addQuote(String sentence, String author) async {
    try {
      await _firestore.collection('quotes').add({
        'sentence': sentence,
        'author': author,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logger.i(e);
    }
  }

  @override
  Future<void> updateQuote(String quoteId, String sentence, String author) async {
    try {
      await _firestore.collection('quotes').doc(quoteId).update({
        'sentence': sentence,
        'author': author,
      });
    } catch (e) {
      logger.i(e);
    }
  }

  @override
  Future<Quote?> getRandomQuote() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('quotes').get();
      if (snapshot.docs.isNotEmpty) {
        final randomIndex = Random().nextInt(snapshot.docs.length);
        final doc = snapshot.docs[randomIndex];
        return Quote.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (e) {
      logger.i(e);
    }
    return null;
  }
}
