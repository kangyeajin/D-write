import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:d_write/core/models/user_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 현재 로그인 된 사용자 가져오기
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // 이메일/비밀번호로 로그인
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      print(e);
      return null;
    }
  }

  // 사용자 정보 가져오기
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (e) {
      print(e);
    }
    return null;
  }

  // 사용자 정보 저장/업데이트
  Future<void> saveUserProfile(String uid, String name, String info) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'name': name,
        'info': info,
      });
    } catch (e) {
      print(e);
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // firebase 회원가입 처리
  Future<User?> signUp(String email, String password, String name, String info) async {
    try {
      // 1. FirebaseAuth로 이메일과 비밀번호를 사용하여 사용자 생성
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        // 2. 성공 시 Firestore 'users' 컬렉션에 추가 정보 저장
        //    사용자의 고유 ID(uid)를 문서 ID로 사용
        await _firestore.collection('users').doc(user.uid).set({
          'name': name,
          'info': info,
        });
      }
      return user;
    } on FirebaseAuthException catch (e) {
      // Firebase 인증 관련 에러 처리
      if (e.code == 'weak-password') {
        print('비밀번호가 너무 약합니다.');
      } else if (e.code == 'email-already-in-use') {
        print('이미 사용 중인 이메일입니다.');
      } else {
        print('회원가입 실패: ${e.message}');
      }
      return null;
    } catch (e) {
      print('알 수 없는 오류 발생: $e');
      return null;
    }
  }

  /// 로그인 처리
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('로그인 실패: ${e.message}');
      return null;
    } catch (e) {
      print('알 수 없는 오류 발생: $e');
      return null;
    }
  }
}