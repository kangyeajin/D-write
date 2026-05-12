import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:d_write/core/models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _db;

  UserRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Future<UserProfile?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromMap(doc.data()!, uid);
  }

  Future<void> createUser(UserProfile profile) async {
    await _db.collection('users').doc(profile.uid).set(profile.toMap());
  }

  Future<void> updateUser(UserProfile profile) async {
    await _db.collection('users').doc(profile.uid).update(profile.toMap());
  }

  Future<void> updateProfileFields(
      String uid, Map<String, dynamic> fields) async {
    await _db.collection('users').doc(uid).update(fields);
  }

  Future<void> saveNameAndInfo(String uid, String name, String info) async {
    await _db.collection('users').doc(uid).set(
      {'name': name, 'info': info},
      SetOptions(merge: true),
    );
  }

  Future<bool> isAdmin(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return false;
    return (doc.data()!['role'] as String?) == 'admin';
  }

  Future<bool> isEmailAvailable(String email) async {
    final query = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  Future<bool> isNicknameAvailable(String nickname) async {
    final query = await _db
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  /// 하루 1회 단일 Firestore 업데이트:
  /// 새 문장 기록 + 출석 + 연속 출석 수
  ///
  /// [slicedSeenIds]: 1500개 초과로 슬라이싱된 전체 배열 (null이면 arrayUnion만 사용)
  Future<void> recordDailyActivity({
    required String uid,
    required String newQuoteId,
    required String todayStr,
    required int consecutiveDays,
    List<String>? slicedSeenIds,
  }) async {
    final ref = _db.collection('users').doc(uid);

    if (slicedSeenIds != null) {
      // 슬라이싱 필요 시 트랜잭션으로 전체 배열 교체
      await _db.runTransaction((tx) async {
        tx.update(ref, {
          'seenQuoteIds': slicedSeenIds,
          'seen_quotes_count': FieldValue.increment(1),
          'attendanceDates': FieldValue.arrayUnion([todayStr]),
          'consecutiveDays': consecutiveDays,
          'todayDate': todayStr,
          'todayQuoteId': newQuoteId,
        });
      });
    } else {
      await ref.update({
        'seenQuoteIds': FieldValue.arrayUnion([newQuoteId]),
        'seen_quotes_count': FieldValue.increment(1),
        'attendanceDates': FieldValue.arrayUnion([todayStr]),
        'consecutiveDays': consecutiveDays,
        'todayDate': todayStr,
        'todayQuoteId': newQuoteId,
      });
    }
  }

  /// seenQuoteIds + 오늘 배정된 문장 정보를 단일 읽기로 반환.
  /// 기기 간 동일 문장 보장을 위해 getTodayQuote 초기화 시 사용.
  Future<({List<String> seenIds, String? todayDate, String? todayQuoteId})>
      getDailyData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      return (seenIds: <String>[], todayDate: null, todayQuoteId: null);
    }
    final data = doc.data()!;
    return (
      seenIds: List<String>.from((data['seenQuoteIds'] as List?) ?? []),
      todayDate: data['todayDate'] as String?,
      todayQuoteId: data['todayQuoteId'] as String?,
    );
  }
}
