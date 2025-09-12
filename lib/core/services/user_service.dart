import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:d_write/core/models/user_model.dart';

abstract class IUserService {
  User? getCurrentUser();
  Future<UserCredential?> signInWithEmail(String email, String password);
  Future<UserProfile?> getUserProfile(String uid);
  Future<void> saveUserProfile(String uid, String name, String info);
  Future<void> signOut();
  Future<User?> signUp(String email, String password, String name, String info);
  Future<User?> signIn(String email, String password);
}

class UserService implements IUserService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  UserService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  @override
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      print(e);
      return null;
    }
  }

  @override
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

  @override
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

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<User?> signUp(String email, String password, String name, String info) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': name,
          'info': info,
        });
      }
      return user;
    } on FirebaseAuthException catch (e) {
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

  @override
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
