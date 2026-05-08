import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:d_write/core/models/memo_model.dart';

class MemoRepository {
  final FirebaseFirestore _db;

  MemoRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> addMemo(String userId, String quoteId, String content) async {
    try {
      await _db.collection('memos').add({
        'userId': userId,
        'quoteId': quoteId,
        'content': content,
        'date': _today(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      debugPrint('MemoRepository.addMemo error [${e.code}]: ${e.message}');
      rethrow;
    }
  }

  Future<Memo?> getMemoForUserAndQuote(String userId, String quoteId) async {
    try {
      final snapshot = await _db
          .collection('memos')
          .where('userId', isEqualTo: userId)
          .where('quoteId', isEqualTo: quoteId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return Memo.fromMap(doc.data(), doc.id);
    } on FirebaseException catch (e) {
      debugPrint('MemoRepository.getMemoForUserAndQuote error [${e.code}]: ${e.message}');
      return null;
    }
  }

  Future<void> updateMemo(String memoId, String content) async {
    try {
      await _db.collection('memos').doc(memoId).update({
        'content': content,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      debugPrint('MemoRepository.updateMemo error [${e.code}]: ${e.message}');
      rethrow;
    }
  }

  Future<void> deleteMemo(String memoId) async {
    try {
      await _db.collection('memos').doc(memoId).delete();
    } on FirebaseException catch (e) {
      debugPrint('MemoRepository.deleteMemo error [${e.code}]: ${e.message}');
      rethrow;
    }
  }

  Future<List<Memo>> getMemosForUser(String userId) async {
    try {
      final snapshot = await _db
          .collection('memos')
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs
          .map((doc) => Memo.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } on FirebaseException catch (e) {
      debugPrint('MemoRepository.getMemosForUser error [${e.code}]: ${e.message}');
      return [];
    }
  }
}
