import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:d_write/core/models/like_model.dart';

class LikeRepository {
  final FirebaseFirestore _db;

  LikeRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  // 문서 ID = "{userId}_{quoteId}" — 쿼리 없이 직접 읽기 가능
  String _docId(String userId, String quoteId) => '${userId}_$quoteId';

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<bool> isLiked(String userId, String quoteId) async {
    try {
      final doc = await _db.collection('likes').doc(_docId(userId, quoteId)).get();
      return doc.exists;
    } on FirebaseException catch (e) {
      debugPrint('LikeRepository.isLiked error [${e.code}]: ${e.message}');
      return false;
    }
  }

  Future<void> addLike(String userId, String quoteId) async {
    try {
      await _db.collection('likes').doc(_docId(userId, quoteId)).set({
        'userId': userId,
        'quoteId': quoteId,
        'date': _today(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      debugPrint('LikeRepository.addLike error [${e.code}]: ${e.message}');
      rethrow;
    }
  }

  Future<List<Like>> getLikesForUser(String userId) async {
    try {
      final snapshot = await _db
          .collection('likes')
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs
          .map((doc) => Like.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } on FirebaseException catch (e) {
      debugPrint('LikeRepository.getLikesForUser error [${e.code}]: ${e.message}');
      return [];
    }
  }

  Future<void> removeLike(String userId, String quoteId) async {
    try {
      await _db.collection('likes').doc(_docId(userId, quoteId)).delete();
    } on FirebaseException catch (e) {
      debugPrint('LikeRepository.removeLike error [${e.code}]: ${e.message}');
      rethrow;
    }
  }
}
