import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:d_write/core/models/user_model.dart';
import 'package:d_write/repositories/user_repository.dart';

abstract class IUserService {
  User? getCurrentUser();
  Future<UserCredential?> signInWithEmail(String email, String password);
  Future<UserProfile?> getUserProfile(String uid);
  Future<void> signOut();
  Future<User?> signUp({
    required String email,
    required String password,
    required String nickname,
    required String gender,
    int? birthYear,
    int? birthMonth,
    int? birthDay,
    required bool locationConsent,
    required bool privacyConsent,
  });
  Future<User?> signIn(String email, String password);
  Future<bool> isEmailAvailable(String email);
  Future<bool> isNicknameAvailable(String nickname);
  Future<void> updateSettings(String uid, Map<String, dynamic> fields);
}

class UserService implements IUserService {
  final FirebaseAuth _auth;
  final UserRepository _userRepository;

  UserService({FirebaseAuth? auth, UserRepository? userRepository})
      : _auth = auth ?? FirebaseAuth.instance,
        _userRepository = userRepository ?? UserRepository();

  @override
  User? getCurrentUser() => _auth.currentUser;

  @override
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('UserService.signInWithEmail error: $e');
      return null;
    }
  }

  @override
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      return await _userRepository.getUser(uid);
    } catch (e) {
      debugPrint('UserService.getUserProfile error: $e');
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<User?> signUp({
    required String email,
    required String password,
    required String nickname,
    required String gender,
    int? birthYear,
    int? birthMonth,
    int? birthDay,
    required bool locationConsent,
    required bool privacyConsent,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        final profile = UserProfile(
          uid: user.uid,
          email: email,
          nickname: nickname,
          gender: gender,
          birthYear: birthYear,
          birthMonth: birthMonth,
          birthDay: birthDay,
          locationConsent: locationConsent,
          privacyConsent: privacyConsent,
          role: UserRole.user,
        );
        await _userRepository.createUser(profile);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('UserService.signUp error [${e.code}]: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('UserService.signUp error: $e');
      return null;
    }
  }

  @override
  Future<User?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('UserService.signIn error [${e.code}]: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('UserService.signIn error: $e');
      return null;
    }
  }

  @override
  Future<bool> isEmailAvailable(String email) async {
    try {
      return await _userRepository.isEmailAvailable(email);
    } catch (e) {
      debugPrint('UserService.isEmailAvailable error: $e');
      return false;
    }
  }

  @override
  Future<bool> isNicknameAvailable(String nickname) async {
    try {
      return await _userRepository.isNicknameAvailable(nickname);
    } catch (e) {
      debugPrint('UserService.isNicknameAvailable error: $e');
      return false;
    }
  }

  @override
  Future<void> updateSettings(String uid, Map<String, dynamic> fields) async {
    try {
      await _userRepository.updateProfileFields(uid, fields);
    } catch (e) {
      debugPrint('UserService.updateSettings error: $e');
    }
  }
}
