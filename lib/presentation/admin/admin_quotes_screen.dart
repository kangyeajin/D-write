import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/core/services/quote_service.dart';
import 'package:d_write/core/theme/app_colors.dart';
import 'package:d_write/presentation/admin/bulk_upload_screen.dart';
import 'package:d_write/repositories/quote_repository.dart';
import 'package:flutter/material.dart';

const List<String> _kMonthLabels = [
  '1월', '2월', '3월', '4월', '5월', '6월',
  '7월', '8월', '9월', '10월', '11월', '12월',
];

class AdminQuotesScreen extends StatefulWidget {
  const AdminQuotesScreen({super.key});

  @override
  State<AdminQuotesScreen> createState() => _AdminQuotesScreenState();
}

class _AdminQuotesScreenState extends State<AdminQuotesScreen> {
  final QuoteService _quoteService = QuoteService(repo: QuoteRepository());

  int _selectedMonth = DateTime.now().month;
  List<Quote> _quotes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    setState(() => _isLoading = true);
    final result = await _quoteService.getQuotesByMonth(_selectedMonth);
    if (mounted) {
      setState(() {
        _quotes = result;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteQuote(String quoteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('문장 삭제'),
        content: const Text('이 문장을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await QuoteRepository().deleteQuote(quoteId);
      await _loadQuotes();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제에 실패했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('월별 문장 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'CSV 일괄 업로드',
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const BulkUploadScreen()),
              );
              _loadQuotes();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      color: AppColors.backgroundLight,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Text(
            '월 선택',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceLight,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _selectedMonth,
              isDense: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: List.generate(
                12,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(_kMonthLabels[i]),
                ),
              ),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedMonth = v);
                  _loadQuotes();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_quotes.isEmpty) {
      return Center(
        child: Text(
          '${_kMonthLabels[_selectedMonth - 1]}에 등록된 문장이 없습니다.',
          style: const TextStyle(color: AppColors.subtitleLight),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _quotes.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) => _QuoteTile(
        quote: _quotes[index],
        onDelete: () => _deleteQuote(_quotes[index].id),
      ),
    );
  }
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({required this.quote, required this.onDelete});

  final Quote quote;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.sentence,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onBackgroundLight,
                    height: 1.5,
                  ),
                ),
                if (quote.author.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '— ${quote.author}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.subtitleLight,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: quote.weatherTags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.dividerLight),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceLight,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppColors.subtitleLight,
            onPressed: onDelete,
            tooltip: '삭제',
          ),
        ],
      ),
    );
  }
}
