import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:d_write/core/models/memo_model.dart';

abstract class IMemoService {
  Future<void> saveMemo(String quoteId, String userId, String content);
  Future<List<Memo>> getMemosForUser(String userId);
  Future<List<Memo>> getMemosForQuote(String quoteId);
}

class MemoService implements IMemoService {
  final FirebaseFirestore _firestore;

  MemoService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> saveMemo(String quoteId, String userId, String content) async {
    try {
      await _firestore.collection('memos').add({
        'quoteId': quoteId,
        'userId': userId,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  Future<List<Memo>> getMemosForUser(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('memos')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => Memo.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print(e);
      return [];
    }
  }

  @override
  Future<List<Memo>> getMemosForQuote(String quoteId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('memos')
          .where('quoteId', isEqualTo: quoteId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => Memo.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print(e);
      return [];
    }
  }
}
