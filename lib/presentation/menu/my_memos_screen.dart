import 'package:d_write/core/models/like_model.dart';
import 'package:d_write/core/models/memo_model.dart';
import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/core/services/like_service.dart';
import 'package:d_write/core/services/memo_service.dart';
import 'package:d_write/core/theme/app_colors.dart';
import 'package:d_write/core/theme/app_text_styles.dart';
import 'package:d_write/presentation/menu/liked_sentence_detail_screen.dart';
import 'package:d_write/repositories/quote_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

typedef _MemoItem = ({Memo memo, Quote? quote, bool isLiked});

class MyMemosScreen extends StatefulWidget {
  const MyMemosScreen({super.key});

  @override
  State<MyMemosScreen> createState() => _MyMemosScreenState();
}

class _MyMemosScreenState extends State<MyMemosScreen> {
  final _memoService = MemoService();
  final _likeService = LikeService();
  final _quoteRepo = QuoteRepository();

  bool _isLoading = true;
  // String → 연도 헤더, _MemoItem → 데이터 행
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
      _memoService.getMemosForUser(uid),
      _likeService.getLikesForUser(uid),
    ]);

    final memos = results[0] as List<Memo>;
    final likes = results[1] as List<Like>;
    final likedQuoteIds = {for (final l in likes) l.quoteId};

    final quotes = await Future.wait(
      memos.map((m) => _quoteRepo.getQuote(m.quoteId)),
    );

    if (!mounted) return;

    final rows = <dynamic>[];
    String? lastYear;
    for (var i = 0; i < memos.length; i++) {
      final date = memos[i].date;
      final year = date.length >= 4 ? date.substring(0, 4) : '';
      if (year != lastYear) {
        rows.add(year);
        lastYear = year;
      }
      rows.add((
        memo: memos[i],
        quote: quotes[i],
        isLiked: likedQuoteIds.contains(memos[i].quoteId),
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
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        title: const Text('내가 쓴 메모'),
        foregroundColor: AppColors.onBackgroundLight,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(
                  child: Text('작성한 메모가 없습니다.', style: AppTextStyles.bodySmall),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _rows.length,
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    if (row is String) return _buildYearHeader(row);
                    return _buildItem(row as _MemoItem);
                  },
                ),
    );
  }

  Widget _buildYearHeader(String year) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 24, bottom: 8),
      child: Text(
        '$year년',
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildItem(_MemoItem item) {
    return Column(
      children: [
        InkWell(
          onTap: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => LikedSentenceDetailScreen(
                  quoteId: item.memo.quoteId,
                  date: item.memo.date,
                  quote: item.quote,
                  initialMemo: item.memo,
                  initiallyLiked: item.isLiked,
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
                      Text(_formatDate(item.memo.date),
                          style: AppTextStyles.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        item.quote?.sentence ?? '(삭제된 문장)',
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.left,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.memo.content,
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (item.isLiked) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.favorite, color: AppColors.like, size: 18),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.dividerLight),
      ],
    );
  }
}
