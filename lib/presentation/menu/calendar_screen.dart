import 'package:d_write/core/models/like_model.dart';
import 'package:d_write/core/models/memo_model.dart';
import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/core/services/like_service.dart';
import 'package:d_write/core/services/local_data_service.dart';
import 'package:d_write/core/services/memo_service.dart';
import 'package:d_write/core/services/quote_service.dart';
import 'package:d_write/core/services/user_service.dart';
import 'package:d_write/core/theme/app_colors.dart';
import 'package:d_write/core/theme/app_text_styles.dart';
import 'package:d_write/presentation/menu/liked_sentence_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _likeService = LikeService();
  final _memoService = MemoService();
  final _quoteService = QuoteService();
  final _userService = UserService();
  final _local = LocalDataService();

  bool _isLoading = true;
  Map<String, Like> _likeByDate = {};
  Map<String, Memo> _memoByDate = {};
  Set<String> _attendanceDates = {};
  final Map<String, Quote?> _quoteByDate = {};

  late int _year;
  late int _month;
  String? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Hive 출석 (네트워크 없음)
    var attendanceDates = _local.localAttendanceDates.toSet();

    // 좋아요 + 메모 병렬 조회 (2 queries)
    final results = await Future.wait([
      _likeService.getLikesForUser(uid),
      _memoService.getMemosForUser(uid),
    ]);

    // Hive가 비어있으면 Firestore 사용자 프로필 1회 조회
    if (attendanceDates.isEmpty) {
      final profile = await _userService.getUserProfile(uid);
      if (profile != null) {
        attendanceDates = profile.attendanceDates.toSet();
      }
    }

    if (!mounted) return;

    final likes = (results[0] as List).cast<Like>();
    final memos = (results[1] as List).cast<Memo>();

    setState(() {
      _attendanceDates = attendanceDates;
      _likeByDate = {for (final l in likes) if (l.date.isNotEmpty) l.date: l};
      _memoByDate = {for (final m in memos) if (m.date.isNotEmpty) m.date: m};
      _isLoading = false;
    });

    await _loadMonthQuotes();
  }

  Future<void> _loadMonthQuotes() async {
    final prefix = '$_year-${_pad(_month)}-';
    final datesToLoad = _likeByDate.keys
        .where((d) => d.startsWith(prefix) && !_quoteByDate.containsKey(d))
        .toList();

    if (datesToLoad.isEmpty) return;

    await Future.wait(datesToLoad.map((dateStr) async {
      final quote = await _quoteService.getQuote(_likeByDate[dateStr]!.quoteId);
      if (mounted) _quoteByDate[dateStr] = quote;
    }));

    if (mounted) setState(() {});
  }

  Future<void> _navigateToDetail(String dateStr) async {
    final like = _likeByDate[dateStr];
    final memo = _memoByDate[dateStr];
    final quoteId = like?.quoteId ?? memo?.quoteId ?? '';
    if (quoteId.isEmpty) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LikedSentenceDetailScreen(
          quoteId: quoteId,
          date: dateStr,
          quote: _quoteByDate[dateStr],
          initialMemo: memo,
          initiallyLiked: like != null,
        ),
      ),
    );

    if (mounted) await _load();
  }

  Future<void> _selectDate(String dateStr) async {
    if (_selectedDate == dateStr) {
      setState(() => _selectedDate = null);
      return;
    }
    setState(() => _selectedDate = dateStr);

    final like = _likeByDate[dateStr];
    if (like != null && !_quoteByDate.containsKey(dateStr)) {
      final quote = await _quoteService.getQuote(like.quoteId);
      if (mounted) setState(() => _quoteByDate[dateStr] = quote);
    }
  }

  void _prevMonth() {
    setState(() {
      _selectedDate = null;
      if (_month == 1) {
        _year--;
        _month = 12;
      } else {
        _month--;
      }
    });
    _loadMonthQuotes();
  }

  void _nextMonth() {
    setState(() {
      _selectedDate = null;
      if (_month == 12) {
        _year++;
        _month = 1;
      } else {
        _month++;
      }
    });
    _loadMonthQuotes();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  void _showYearMonthPicker() {
    int pickerYear = _year;
    int pickerMonth = _month;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => setDialogState(() => pickerYear--),
                        ),
                        SizedBox(
                          width: 88,
                          child: Center(
                            child: Text(
                              '$pickerYear년',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: AppColors.onBackgroundLight,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => setDialogState(() => pickerYear++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.6,
                      children: List.generate(12, (i) {
                        final m = i + 1;
                        final isActive = pickerYear == _year && m == _month;
                        final isPickerSelected = m == pickerMonth;
                        return GestureDetector(
                          onTap: () => setDialogState(() => pickerMonth = m),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primary
                                  : isPickerSelected
                                      ? AppColors.primary.withValues(alpha: 0.12)
                                      : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(8),
                              border: isPickerSelected && !isActive
                                  ? Border.all(color: AppColors.primary, width: 1.5)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$m월',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isActive ? Colors.white : AppColors.onBackgroundLight,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          setState(() {
                            _year = pickerYear;
                            _month = pickerMonth;
                            _selectedDate = null;
                          });
                          Navigator.of(ctx).pop();
                          _loadMonthQuotes();
                        },
                        child: const Text(
                          '확인',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── 빌드 ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        title: const Text('달력'),
        foregroundColor: AppColors.onBackgroundLight,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                _buildDayLabels(),
                const Divider(height: 1, color: AppColors.dividerLight),
                _buildCalendarGrid(),
                const Divider(height: 1, color: AppColors.dividerLight),
                Expanded(
                  child: _selectedDate != null
                      ? _buildDayDetail(_selectedDate!)
                      : _buildMonthList(),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _prevMonth,
            color: AppColors.onBackgroundLight,
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showYearMonthPicker,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_year년 ${_pad(_month)}월',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: AppColors.onBackgroundLight,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 22, color: AppColors.onBackgroundLight),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
            color: AppColors.onBackgroundLight,
          ),
        ],
      ),
    );
  }

  Widget _buildDayLabels() {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
      child: Row(
        children: labels.asMap().entries.map((e) {
          Color color = AppColors.subtitleLight;
          if (e.key == 0) color = AppColors.like;
          if (e.key == 6) color = Colors.blue.shade400;
          return Expanded(
            child: Center(
              child: Text(
                e.value,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_year, _month, 1);
    final startOffset = firstDay.weekday % 7;
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final rows = ((startOffset + daysInMonth) / 7).ceil();

    final today = DateTime.now();
    final todayStr = '${today.year}-${_pad(today.month)}-${_pad(today.day)}';

    return LayoutBuilder(builder: (context, constraints) {
      final cellW = constraints.maxWidth / 7;
      return Column(
        children: List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final day = row * 7 + col - startOffset + 1;
              if (day < 1 || day > daysInMonth) {
                return SizedBox(width: cellW, height: 52);
              }
              final dateStr = '$_year-${_pad(_month)}-${_pad(day)}';
              return _buildDayCell(
                day: day,
                col: col,
                dateStr: dateStr,
                todayStr: todayStr,
                daysInMonth: daysInMonth,
                cellW: cellW,
              );
            }),
          );
        }),
      );
    });
  }

  Widget _buildDayCell({
    required int day,
    required int col,
    required String dateStr,
    required String todayStr,
    required int daysInMonth,
    required double cellW,
  }) {
    final isToday = dateStr == todayStr;
    final isSelected = dateStr == _selectedDate;
    final isAttended = _attendanceDates.contains(dateStr);
    final isLiked = _likeByDate.containsKey(dateStr);
    final hasMemo = _memoByDate.containsKey(dateStr);

    // 출석 바 연결 여부
    final prevDateStr = day > 1 ? '$_year-${_pad(_month)}-${_pad(day - 1)}' : null;
    final nextDateStr = day < daysInMonth ? '$_year-${_pad(_month)}-${_pad(day + 1)}' : null;
    final prevAttended = isAttended && prevDateStr != null && _attendanceDates.contains(prevDateStr);
    final nextAttended = isAttended && nextDateStr != null && _attendanceDates.contains(nextDateStr);

    // 원 스타일
    Color? circleFill;
    Border? circleBorder;
    if (isToday) {
      circleFill = AppColors.primary;
    } else if (isLiked) {
      circleFill = const Color(0xFFFFE0E6);
      if (isSelected) circleBorder = Border.all(color: AppColors.primary, width: 1.5);
    } else if (isSelected) {
      circleFill = AppColors.primary.withValues(alpha: 0.12);
      circleBorder = Border.all(color: AppColors.primary, width: 1.5);
    }

    // 날짜 텍스트 색
    Color textColor;
    if (isToday) {
      textColor = Colors.white;
    } else if (col == 0) {
      textColor = AppColors.like;
    } else if (col == 6) {
      textColor = Colors.blue.shade400;
    } else {
      textColor = AppColors.onBackgroundLight;
    }

    final underlineColor = isToday
        ? Colors.white.withValues(alpha: 0.8)
        : AppColors.onBackgroundLight.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: () => _selectDate(dateStr),
      child: SizedBox(
        width: cellW,
        height: 52,
        child: Stack(
          children: [
            // Stack 크기 정의
            SizedBox(width: cellW, height: 52),
            // 출석 형광펜 바
            if (isAttended)
              Positioned(
                top: 14,
                bottom: 14,
                left: prevAttended ? 0 : cellW / 2 - 16,
                right: nextAttended ? 0 : cellW / 2 - 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8EEC4),
                    borderRadius: BorderRadius.horizontal(
                      left: prevAttended ? Radius.zero : const Radius.circular(12),
                      right: nextAttended ? Radius.zero : const Radius.circular(12),
                    ),
                  ),
                ),
              ),
            // 날짜 원 (좋아요 분홍 / 오늘 primary / 선택 outline)
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: circleFill,
                    border: circleBorder,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
            // 메모 언더라인
            if (hasMemo)
              Positioned(
                bottom: 3,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 14,
                    height: 1.5,
                    decoration: BoxDecoration(
                      color: underlineColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 월 전체 기록 리스트 ────────────────────────────────────────

  Widget _buildMonthList() {
    final prefix = '$_year-${_pad(_month)}-';
    final activeDates = {
      ..._likeByDate.keys.where((d) => d.startsWith(prefix)),
      ..._memoByDate.keys.where((d) => d.startsWith(prefix)),
    }.toList()
      ..sort();

    if (activeDates.isEmpty) {
      return const Center(
        child: Text('이번 달 기록이 없습니다.', style: AppTextStyles.bodySmall),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: activeDates.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.dividerLight),
      itemBuilder: (_, i) => _buildRecordItem(activeDates[i]),
    );
  }

  Widget _buildRecordItem(String dateStr) {
    final like = _likeByDate[dateStr];
    final memo = _memoByDate[dateStr];
    final quote = _quoteByDate[dateStr];
    final parts = dateStr.split('-');
    final displayDate = '${parts[1]}.${parts[2]}';

    return InkWell(
      onTap: () => _navigateToDetail(dateStr),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayDate, style: AppTextStyles.bodySmall),
                  if (like != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      quote?.sentence ?? '불러오는 중...',
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (quote?.author.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '출처: ${quote!.author}',
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  if (memo != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      memo.content,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onSurfaceLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (like != null) ...[
              const SizedBox(width: 12),
              const Padding(
                padding: EdgeInsets.only(top: 22),
                child: Icon(Icons.favorite, color: AppColors.like, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── 선택 날짜 상세 ─────────────────────────────────────────────

  Widget _buildDayDetail(String dateStr) {
    final like = _likeByDate[dateStr];
    final memo = _memoByDate[dateStr];

    if (like == null && memo == null) {
      return const Center(
        child: Text('기록이 없습니다.', style: AppTextStyles.bodySmall),
      );
    }

    final quote = _quoteByDate[dateStr];
    final parts = dateStr.split('-');
    final displayDate = '${parts[1]}.${parts[2]}';

    return InkWell(
      onTap: () => _navigateToDetail(dateStr),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayDate, style: AppTextStyles.bodySmall),
                  if (like != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      quote?.sentence ?? '불러오는 중...',
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (quote?.author.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '출처: ${quote!.author}',
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  if (memo != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      memo.content,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onSurfaceLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (like != null) ...[
              const SizedBox(width: 12),
              const Padding(
                padding: EdgeInsets.only(top: 22),
                child: Icon(Icons.favorite, color: AppColors.like, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
