import 'package:d_write/core/models/like_model.dart';
import 'package:d_write/core/models/memo_model.dart';
import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/core/services/like_service.dart';
import 'package:d_write/core/services/memo_service.dart';
import 'package:d_write/core/theme/app_palette.dart';
import 'package:d_write/core/theme/app_text_styles.dart';
import 'package:d_write/presentation/menu/liked_sentence_detail_screen.dart';
import 'package:d_write/repositories/quote_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

typedef _LikedItem = ({Like like, Quote? quote, Memo? memo});

class LikedSentencesScreen extends StatefulWidget {
  const LikedSentencesScreen({super.key});

  @override
  State<LikedSentencesScreen> createState() => _LikedSentencesScreenState();
}

class _LikedSentencesScreenState extends State<LikedSentencesScreen> {
  final _likeService = LikeService();
  final _memoService = MemoService();
  final _quoteRepo = QuoteRepository();

  bool _isLoading = true;
  // String → 연도 헤더, _LikedItem → 데이터 행
  List<dynamic> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (_rows.isEmpty) setState(() => _isLoading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final results = await Future.wait([
      _likeService.getLikesForUser(uid),
      _memoService.getMemosForUser(uid),
    ]);

    final likes = results[0] as List<Like>;
    final memos = results[1] as List<Memo>;
    final memoByQuoteId = {for (final m in memos) m.quoteId: m};

    final quotes = await Future.wait(
      likes.map((l) => _quoteRepo.getQuote(l.quoteId)),
    );

    if (!mounted) return;

    final rows = <dynamic>[];
    String? lastYear;
    for (var i = 0; i < likes.length; i++) {
      final date = likes[i].date;
      final year = date.length >= 4 ? date.substring(0, 4) : '';
      if (year != lastYear) {
        rows.add(year);
        lastYear = year;
      }
      rows.add((
        like: likes[i],
        quote: quotes[i],
        memo: memoByQuoteId[likes[i].quoteId],
      ));
    }

    setState(() {
      _rows = rows;
      _isLoading = false;
    });
  }

  String _formatDate(String date) {
    if (date.length < 10) return date;
    return date.substring(5).replaceAll('-', '.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text('좋아요 한 문장', style: AppTextStyles.sectionTitle.copyWith(color: colors.textPrimary)),
        foregroundColor: colors.textPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(
                  child: Text('좋아요 한 문장이 없습니다.', style: AppTextStyles.bodySmall),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _rows.length,
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    if (row is String) return _buildYearHeader(row);
                    return _buildItem(row as _LikedItem);
                  },
                ),
    );
  }

  Widget _buildYearHeader(String year) {
    final colors = AppColorTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 24, bottom: 8),
      child: Text(
        '$year년',
        style: AppTextStyles.body.copyWith(
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildItem(_LikedItem item) {
    final colors = AppColorTokens.of(context);
    return Column(
      children: [
        InkWell(
          onTap: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => LikedSentenceDetailScreen(
                  quoteId: item.like.quoteId,
                  date: item.like.date,
                  quote: item.quote,
                  initialMemo: item.memo,
                ),
              ),
            );
            _load();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(item.like.date),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.quote?.sentence ?? '(삭제된 문장)',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                        textAlign: TextAlign.left,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.memo != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.memo!.content,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: colors.divider),
      ],
    );
  }
}
