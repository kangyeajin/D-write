import 'package:flutter/foundation.dart';
import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/repositories/quote_repository.dart';

abstract class IQuoteService {
  Future<Quote?> getQuote(String quoteId);
  Future<void> addQuote({
    required String sentence,
    required String author,
    required int month,
    required List<String> weatherTags,
  });
  Future<void> updateQuote(String quoteId, String sentence, String author);
  Future<Quote?> getRandomQuote();
  Future<List<Quote>> getQuotesByMonth(int month);
}

class QuoteService implements IQuoteService {
  final QuoteRepository _repo;

  QuoteService({QuoteRepository? repo}) : _repo = repo ?? QuoteRepository();

  @override
  Future<Quote?> getQuote(String quoteId) async {
    try {
      return await _repo.getQuote(quoteId);
    } catch (e) {
      debugPrint('QuoteService.getQuote error: $e');
      return null;
    }
  }

  @override
  Future<void> addQuote({
    required String sentence,
    required String author,
    required int month,
    required List<String> weatherTags,
  }) async {
    try {
      await _repo.addQuote(
        sentence: sentence,
        author: author,
        month: month,
        weatherTags: weatherTags,
      );
    } catch (e) {
      debugPrint('QuoteService.addQuote error: $e');
    }
  }

  @override
  Future<void> updateQuote(String quoteId, String sentence, String author) async {
    try {
      await _repo.updateQuote(quoteId, sentence, author);
    } catch (e) {
      debugPrint('QuoteService.updateQuote error: $e');
    }
  }

  @override
  Future<Quote?> getRandomQuote() async {
    try {
      return await _repo.getRandomQuote();
    } catch (e) {
      debugPrint('QuoteService.getRandomQuote error: $e');
      return null;
    }
  }

  @override
  Future<List<Quote>> getQuotesByMonth(int month) async {
    try {
      return await _repo.getQuotesByMonth(month);
    } catch (e) {
      debugPrint('QuoteService.getQuotesByMonth error: $e');
      return [];
    }
  }

  Future<int> bulkAddQuotes(List<Map<String, dynamic>> rows) async {
    try {
      return await _repo.bulkAddQuotes(rows);
    } catch (e) {
      debugPrint('QuoteService.bulkAddQuotes error: $e');
      rethrow;
    }
  }
}
