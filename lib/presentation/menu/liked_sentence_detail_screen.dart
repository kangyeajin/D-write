import 'dart:io';
import 'dart:ui' as ui;

import 'package:d_write/core/models/memo_model.dart';
import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/core/services/like_service.dart';
import 'package:d_write/core/services/memo_service.dart';
import 'package:d_write/core/theme/app_palette.dart';
import 'package:d_write/core/theme/app_text_styles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';

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
  final GlobalKey _repaintKey = GlobalKey();
  final _likeService = LikeService();
  final _memoService = MemoService();

  late bool _isLiked;
  Memo? _memo;
  bool _isSaving = false;

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

  // ── 좋아요 토글 ────────────────────────────────────────────
  Future<void> _toggleLike() async {
    final uid = _uid;
    if (uid == null) return;

    final prev = _isLiked;
    setState(() => _isLiked = !_isLiked);
    try {
      if (prev) {
        await _likeService.removeLike(uid, widget.quoteId);
      } else {
        await _likeService.addLike(uid, widget.quoteId);
      }
    } catch (_) {
      if (mounted) setState(() => _isLiked = prev);
    }
  }

  // ── 메모 다이얼로그 ────────────────────────────────────────
  void _openMemoSheet() {
    final uid = _uid;
    if (uid == null) return;

    final controller = TextEditingController(text: _memo?.content ?? '');
    final isEditing = _memo != null;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? '메모 수정' : '메모 추가'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: '이 문장에 대한 생각을 기록해보세요.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _deleteMemo();
                },
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();
                Navigator.pop(dialogContext);
                await _saveMemo(uid, text);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveMemo(String uid, String content) async {
    if (content.isEmpty) {
      if (_memo != null) await _deleteMemo();
      return;
    }
    if (_memo != null) {
      await _memoService.updateMemo(_memo!.id, content);
    } else {
      await _memoService.saveMemo(uid, widget.quoteId, content);
    }
    final updated =
        await _memoService.getMemoForUserAndQuote(uid, widget.quoteId);
    if (mounted) setState(() => _memo = updated);
  }

  Future<void> _deleteMemo() async {
    final memo = _memo;
    if (memo == null) return;
    await _memoService.deleteMemo(memo.id);
    if (mounted) setState(() => _memo = null);
  }

  // ── 이미지 저장 ────────────────────────────────────────────
  Future<void> _saveImage() async {
    setState(() => _isSaving = true);
    try {
      final boundary = _repaintKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('RenderRepaintBoundary not found');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('toByteData returned null');

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/quote_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      final result =
          await GallerySaver.saveImage(file.path, albumName: 'D-Write');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              result == true ? '이미지가 갤러리에 저장되었습니다.' : '저장에 실패했습니다.'),
        ),
      );
    } catch (e) {
      debugPrint('[ERROR] _saveImage error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 40,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 날짜
                            Text(
                              _dateLabel,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // 문장 + 출처 (이미지 저장 영역)
                            RepaintBoundary(
                              key: _repaintKey,
                              child: ColoredBox(
                                color: colors.background,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        quote?.sentence ?? '(삭제된 문장)',
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.sentenceBody(
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      if (quote != null &&
                                          quote.author.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          '— ${quote.author}',
                                          style:
                                              AppTextStyles.sentenceSource
                                                  .copyWith(
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
                                  iconColor:
                                      _isLiked ? colors.accent : colors.textSecondary,
                                  onPressed: _toggleLike,
                                  tooltip: '좋아요',
                                ),
                                const SizedBox(width: 32),
                                _ActionButton(
                                  icon: _hasMemo
                                      ? Icons.edit
                                      : Icons.edit_outlined,
                                  iconColor: colors.textSecondary,
                                  onPressed: _openMemoSheet,
                                  tooltip: '메모',
                                ),
                                const SizedBox(width: 32),
                                _ActionButton(
                                  icon: Icons.download_outlined,
                                  iconColor: colors.textSecondary,
                                  onPressed: _isSaving ? null : _saveImage,
                                  tooltip: '저장',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_isSaving)
            const ColoredBox(
              color: Color(0x55000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
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
