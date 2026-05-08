import 'package:flutter/foundation.dart';
import 'package:d_write/core/models/like_model.dart';
import 'package:d_write/repositories/like_repository.dart';

abstract class ILikeService {
  Future<bool> isLiked(String userId, String quoteId);
  Future<void> addLike(String userId, String quoteId);
  Future<void> removeLike(String userId, String quoteId);
  Future<List<Like>> getLikesForUser(String userId);
}

class LikeService implements ILikeService {
  final LikeRepository _repo;

  LikeService({LikeRepository? repo}) : _repo = repo ?? LikeRepository();

  @override
  Future<bool> isLiked(String userId, String quoteId) async {
    try {
      return await _repo.isLiked(userId, quoteId);
    } catch (e) {
      debugPrint('LikeService.isLiked error: $e');
      return false;
    }
  }

  @override
  Future<void> addLike(String userId, String quoteId) async {
    try {
      await _repo.addLike(userId, quoteId);
    } catch (e) {
      debugPrint('LikeService.addLike error: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeLike(String userId, String quoteId) async {
    try {
      await _repo.removeLike(userId, quoteId);
    } catch (e) {
      debugPrint('LikeService.removeLike error: $e');
      rethrow;
    }
  }

  @override
  Future<List<Like>> getLikesForUser(String userId) async {
    try {
      return await _repo.getLikesForUser(userId);
    } catch (e) {
      debugPrint('LikeService.getLikesForUser error: $e');
      return [];
    }
  }
}
