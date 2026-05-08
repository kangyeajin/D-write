import 'package:flutter/foundation.dart';
import 'package:d_write/core/models/memo_model.dart';
import 'package:d_write/repositories/memo_repository.dart';

abstract class IMemoService {
  Future<void> saveMemo(String userId, String quoteId, String content);
  Future<Memo?> getMemoForUserAndQuote(String userId, String quoteId);
  Future<void> updateMemo(String memoId, String content);
  Future<void> deleteMemo(String memoId);
  Future<List<Memo>> getMemosForUser(String userId);
}

class MemoService implements IMemoService {
  final MemoRepository _repo;

  MemoService({MemoRepository? repo}) : _repo = repo ?? MemoRepository();

  @override
  Future<void> saveMemo(String userId, String quoteId, String content) async {
    try {
      await _repo.addMemo(userId, quoteId, content);
    } catch (e) {
      debugPrint('MemoService.saveMemo error: $e');
    }
  }

  @override
  Future<Memo?> getMemoForUserAndQuote(String userId, String quoteId) async {
    try {
      return await _repo.getMemoForUserAndQuote(userId, quoteId);
    } catch (e) {
      debugPrint('MemoService.getMemoForUserAndQuote error: $e');
      return null;
    }
  }

  @override
  Future<void> updateMemo(String memoId, String content) async {
    try {
      await _repo.updateMemo(memoId, content);
    } catch (e) {
      debugPrint('MemoService.updateMemo error: $e');
    }
  }

  @override
  Future<void> deleteMemo(String memoId) async {
    try {
      await _repo.deleteMemo(memoId);
    } catch (e) {
      debugPrint('MemoService.deleteMemo error: $e');
    }
  }

  @override
  Future<List<Memo>> getMemosForUser(String userId) async {
    try {
      return await _repo.getMemosForUser(userId);
    } catch (e) {
      debugPrint('MemoService.getMemosForUser error: $e');
      return [];
    }
  }
}
