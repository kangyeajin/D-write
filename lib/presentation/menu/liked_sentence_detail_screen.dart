import 'dart:ui';

import 'package:d_write/core/models/memo_model.dart';
import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/core/services/like_service.dart';
import 'package:d_write/core/services/local_data_service.dart';
import 'package:d_write/core/services/memo_service.dart';
import 'package:d_write/core/theme/app_palette.dart';
import 'package:d_write/core/theme/app_text_styles.dart';
import 'package:d_write/presentation/main/save_edit_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


class LikedSentenceDetailScreen extends StatefulWidget {
  const LikedSentenceDetailScreen({
    super.key,
    required this.quoteId,
    required this.date,
    required this.quote,
    required this.initialMemo,
    this.initiallyLiked = true,
  });

  final String quoteId;
  final String date;
  final Quote? quote;
  final Memo? initialMemo;
  final bool initiallyLiked;

  @override
  State<LikedSentenceDetailScreen> createState() =>
      _LikedSentenceDetailScreenState();
}

class _LikedSentenceDetailScreenState
    extends State<LikedSentenceDetailScreen> {
  final _likeService = LikeService();
  final _memoService = MemoService();

  late bool _isLiked;
  Memo? _memo;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  bool get _hasMemo => _memo != null && _memo!.content.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.initiallyLiked;
    _memo = widget.initialMemo;
  }

  String get _dateLabel {
    final date = widget.date;
    if (date.length < 10) return date;
    return date.substring(5).replaceAll('-', '.');
  }

  void _showNetworkError() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('저장 실패'),
        content: const Text('네트워크 연결을 확인해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // ── 좋아요 토글 ────────────────────────────────────────────
  Future<void> _toggleLike() async {
    final uid = _uid;
    if (uid == null) return;

    final prev = _isLiked;
    setState(() => _isLiked = !_isLiked);
    final local = LocalDataService();
    final isToday = widget.quoteId == local.todayQuoteId;
    if (isToday) local.setTodayLike(_isLiked);

    try {
      if (prev) {
        await _likeService.removeLike(uid, widget.quoteId);
      } else {
        await _likeService.addLike(uid, widget.quoteId);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLiked = prev);
        if (isToday) local.setTodayLike(prev);
        _showNetworkError();
      }
    }
  }

  // ── 메모 다이얼로그 ────────────────────────────────────────
  void _openMemoSheet() {
    final uid = _uid;
    if (uid == null) return;

    final controller = TextEditingController(text: _memo?.content ?? '');
    final isEditing = _memo != null;
    final colors = AppColorTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: isDark ? 0.82 : 0.90),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.55),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                        tooltip: '닫기',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: controller,
                            autofocus: true,
                            maxLines: 5,
                            minLines: 3,
                            style: AppTextStyles.body.copyWith(
                              color: colors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: '이 문장에 대한 생각을 기록해보세요.',
                              hintStyle: AppTextStyles.body.copyWith(
                                color: colors.textTertiary,
                              ),
                              filled: true,
                              fillColor: colors.background.withValues(
                                alpha: 0.35,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 20,
                              ),
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: colors.divider,
                                  width: 1,
                                ),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: colors.divider,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: colors.accent,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              if (isEditing)
                                TextButton(
                                  onPressed: () async {
                                    Navigator.pop(dialogContext);
                                    await _deleteMemo();
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: colors.error,
                                    minimumSize: const Size(44, 44),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Text(
                                    '삭제',
                                    style: AppTextStyles.button.copyWith(
                                      color: colors.error,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              OutlinedButton(
                                onPressed: () async {
                                  final text = controller.text.trim();
                                  Navigator.pop(dialogContext);
                                  await _saveMemo(uid, text);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.textPrimary,
                                  side: BorderSide(
                                    color: colors.textPrimary.withValues(
                                      alpha: 0.35,
                                    ),
                                    width: 1,
                                  ),
                                  minimumSize: const Size(72, 40),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  '저장',
                                  style: AppTextStyles.button.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveMemo(String uid, String content) async {
    debugPrint(
      '[MEMO] 저장 시작 — isEditing=${_memo != null}, length=${content.length}',
    );
    if (content.isEmpty) {
      debugPrint('[MEMO] 빈 내용 → ${_memo != null ? '기존 메모 삭제' : '스킵'}');
      if (_memo != null) await _deleteMemo();
      return;
    }
    if (_memo != null && content == _memo!.content) {
      debugPrint('[MEMO] 내용 미변경 → 업데이트 생략');
      return;
    }
    try {
      if (_memo != null) {
        await _memoService.updateMemo(_memo!.id, content);
        debugPrint('[MEMO] 수정 완료 — id=${_memo!.id}');
      } else {
        await _memoService.saveMemo(uid, widget.quoteId, content);
        debugPrint('[MEMO] 신규 저장 완료 — quoteId=${widget.quoteId}');
      }
      final updated =
          await _memoService.getMemoForUserAndQuote(uid, widget.quoteId);
      if (mounted) {
        setState(() => _memo = updated);
        final local = LocalDataService();
        if (widget.quoteId == local.todayQuoteId) {
          local.setTodayMemo(updated);
        }
      }
    } catch (_) {
      if (mounted) _showNetworkError();
    }
  }

  Future<void> _deleteMemo() async {
    final memo = _memo;
    if (memo == null) return;
    try {
      await _memoService.deleteMemo(memo.id);
      if (mounted) {
        setState(() => _memo = null);
        final local = LocalDataService();
        if (widget.quoteId == local.todayQuoteId) {
          local.setTodayMemo(null);
        }
      }
    } catch (_) {
      if (mounted) _showNetworkError();
    }
  }

  // ── 빌드 ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);
    final quote = widget.quote;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        foregroundColor: colors.textPrimary,
      ),
      body: SingleChildScrollView(
        child: Builder(
          builder: (context) {
            final screenHeight = MediaQuery.sizeOf(context).height;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: screenHeight * 0.25 - kToolbarHeight),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 날짜
                        Text(
                          _dateLabel,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 20,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // 문장
                        Text(
                          quote?.sentence ?? '(삭제된 문장)',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.sentenceBody(
                            color: colors.textPrimary,
                          ),
                        ),
                        if (quote != null && quote.author.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            '— ${quote.author}',
                            style: AppTextStyles.sentenceSource.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                        // 메모 박스
                        if (_hasMemo) ...[
                          const SizedBox(height: 28),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _memo!.content,
                              style: AppTextStyles.body.copyWith(
                                color: colors.textSecondary,
                              ),
                              maxLines: 10,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        // 액션 버튼
                        const SizedBox(height: 36),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ActionButton(
                              icon: _isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              iconColor: _isLiked
                                  ? colors.accent
                                  : colors.textSecondary,
                              onPressed: _toggleLike,
                              tooltip: '좋아요',
                            ),
                            const SizedBox(width: 32),
                            _ActionButton(
                              icon: _hasMemo
                                  ? Icons.edit
                                  : Icons.edit_outlined,
                              iconColor: _hasMemo
                                  ? colors.accent
                                  : colors.textSecondary,
                              onPressed: _openMemoSheet,
                              tooltip: '메모',
                            ),
                            const SizedBox(width: 32),
                            _ActionButton(
                              icon: Icons.download_outlined,
                              iconColor: colors.textSecondary,
                              onPressed: quote != null
                                  ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            SaveEditScreen(quote: quote),
                                      ),
                                    )
                                  : null,
                              tooltip: '저장',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.iconColor,
    this.onPressed,
  });

  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: isDisabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: isDisabled ? null : () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              widget.icon,
              size: 22,
              color: isDisabled
                  ? widget.iconColor?.withValues(alpha: 0.4)
                  : widget.iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
