import 'dart:math' show min;

import 'package:d_write/core/models/like_model.dart';
import 'package:d_write/core/models/memo_model.dart';
import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/core/services/like_service.dart';
import 'package:d_write/core/services/local_data_service.dart';
import 'package:d_write/core/services/memo_service.dart';
import 'package:d_write/core/services/quote_service.dart';
import 'package:d_write/core/services/user_service.dart';
import 'package:d_write/core/theme/app_palette.dart';
import 'package:d_write/core/theme/app_text_styles.dart';
import 'package:d_write/presentation/menu/liked_sentence_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
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

  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  void _triggerStagger() {
    _staggerController.reset();
    _staggerController.forward();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    var attendanceDates = _local.localAttendanceDates.toSet();

    final results = await Future.wait([
      _likeService.getLikesForUser(uid),
      _memoService.getMemosForUser(uid),
    ]);

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
      _likeByDate = {
        for (final l in likes)
          if (l.date.isNotEmpty) l.date: l,
      };
      _memoByDate = {
        for (final m in memos)
          if (m.date.isNotEmpty) m.date: m,
      };
      _isLoading = false;
    });
    _triggerStagger();

    await _loadMonthQuotes();
  }

  Future<void> _loadMonthQuotes() async {
    final prefix = '$_year-${_pad(_month)}-';

    final datesToLoad = {
      ..._likeByDate.keys.where((d) => d.startsWith(prefix)),
      ..._memoByDate.keys.where(
        (d) => d.startsWith(prefix) && _memoByDate[d]!.quoteId.isNotEmpty,
      ),
    }.where((d) => !_quoteByDate.containsKey(d)).toList();

    if (datesToLoad.isEmpty) return;

    await Future.wait(
      datesToLoad.map((dateStr) async {
        final quoteId =
            _likeByDate[dateStr]?.quoteId ??
            _memoByDate[dateStr]?.quoteId ??
            '';
        if (quoteId.isEmpty) return;
        final quote = await _quoteService.getQuote(quoteId);
        if (mounted) _quoteByDate[dateStr] = quote;
      }),
    );

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
      _triggerStagger();
      return;
    }
    setState(() => _selectedDate = dateStr);

    final like = _likeByDate[dateStr];
    final memo = _memoByDate[dateStr];
    if (!_quoteByDate.containsKey(dateStr)) {
      final quoteId = like?.quoteId ?? memo?.quoteId ?? '';
      if (quoteId.isNotEmpty) {
        final quote = await _quoteService.getQuote(quoteId);
        if (mounted) setState(() => _quoteByDate[dateStr] = quote);
      }
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
    _triggerStagger();
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
    _triggerStagger();
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
            final colors = AppColorTokens.of(ctx);
            return Dialog(
              backgroundColor: colors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.chevron_left,
                            color: colors.textPrimary,
                          ),
                          onPressed: () => setDialogState(() => pickerYear--),
                        ),
                        SizedBox(
                          width: 88,
                          child: Center(
                            child: Text(
                              '$pickerYear년',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right,
                            color: colors.textPrimary,
                          ),
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
                                  ? colors.accent
                                  : isPickerSelected
                                  ? colors.accent.withValues(alpha: 0.12)
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: isPickerSelected && !isActive
                                  ? Border.all(color: colors.accent, width: 1.5)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$m월',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isActive
                                    ? Colors.white
                                    : colors.textPrimary,
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
                          backgroundColor: colors.accent,
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
                          _triggerStagger();
                          _loadMonthQuotes();
                        },
                        child: const Text(
                          '확인',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
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

  // ── 빌드 ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '달력',
          style: AppTextStyles.sectionTitle.copyWith(color: colors.textPrimary),
        ),
        foregroundColor: colors.textPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(colors),
                _buildDayLabels(colors),
                _buildCalendarGrid(colors),
                const SizedBox(height: 20),
                Divider(height: 1, color: colors.divider),
                Expanded(
                  child: ColoredBox(
                    color: colors.surface,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      ),
                      child: _selectedDate != null
                          ? KeyedSubtree(
                              key: ValueKey(_selectedDate),
                              child: _buildDayDetail(_selectedDate!, colors),
                            )
                          : KeyedSubtree(
                              key: const ValueKey('list'),
                              child: _buildMonthList(colors),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── 헤더·그리드 (기존 유지) ────────────────────────────────────

  bool get _isAtOrPastCurrentMonth {
    final now = DateTime.now();
    return _year > now.year || (_year == now.year && _month >= now.month);
  }

  Widget _buildHeader(AppColorTokens colors) {
    final nextDisabled = _isAtOrPastCurrentMonth;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: colors.textPrimary),
            onPressed: _prevMonth,
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _showYearMonthPicker,
            child: Text(
              '$_year년 ${_pad(_month)}월',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: nextDisabled ? colors.divider : colors.textPrimary,
            ),
            onPressed: nextDisabled ? null : _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildDayLabels(AppColorTokens colors) {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
      child: Row(
        children: labels.asMap().entries.map((e) {
          Color color = colors.textSecondary;
          if (e.key == 0) color = colors.accent;
          if (e.key == 6) color = Colors.blue.shade400;
          return Expanded(
            child: Center(
              child: Text(
                e.value,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                  color: color,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(AppColorTokens colors) {
    final firstDay = DateTime(_year, _month, 1);
    final startOffset = firstDay.weekday % 7;
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final rows = ((startOffset + daysInMonth) / 7).ceil();

    final today = DateTime.now();
    final todayStr = '${today.year}-${_pad(today.month)}-${_pad(today.day)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / 7;
        return Column(
          children: List.generate(rows, (row) {
            return Row(
              children: List.generate(7, (col) {
                final day = row * 7 + col - startOffset + 1;
                if (day < 1 || day > daysInMonth) {
                  return SizedBox(width: cellW, height: 48);
                }
                final dateStr = '$_year-${_pad(_month)}-${_pad(day)}';
                return _buildDayCell(
                  colors: colors,
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
      },
    );
  }

  Widget _buildDayCell({
    required AppColorTokens colors,
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

    final prevDateStr = day > 1
        ? '$_year-${_pad(_month)}-${_pad(day - 1)}'
        : null;
    final nextDateStr = day < daysInMonth
        ? '$_year-${_pad(_month)}-${_pad(day + 1)}'
        : null;
    final prevAttended =
        isAttended &&
        prevDateStr != null &&
        _attendanceDates.contains(prevDateStr);
    final nextAttended =
        isAttended &&
        nextDateStr != null &&
        _attendanceDates.contains(nextDateStr);

    Color? circleFill;
    Border? circleBorder;
    if (isToday) {
      circleFill = colors.accent;
    } else if (isLiked) {
      circleFill = colors.accentMuted;
      if (isSelected) {
        circleBorder = Border.all(color: colors.accent, width: 1.5);
      }
    } else if (isSelected) {
      circleFill = colors.accent.withValues(alpha: 0.12);
      circleBorder = Border.all(color: colors.accent, width: 1.5);
    }

    Color textColor;
    if (isToday) {
      textColor = Colors.white;
    } else if (col == 0) {
      textColor = colors.accent;
    } else if (col == 6) {
      textColor = Colors.blue.shade400;
    } else {
      textColor = colors.textPrimary;
    }

    final barColor = isToday
        ? Colors.white.withValues(alpha: 0.8)
        : colors.textPrimary.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: () => _selectDate(dateStr),
      child: SizedBox(
        width: cellW,
        height: 48,
        child: Stack(
          children: [
            SizedBox(width: cellW, height: 48),
            if (isAttended)
              Positioned(
                top: 12,
                bottom: 12,
                left: prevAttended ? 0 : cellW / 2 - 15,
                right: nextAttended ? 0 : cellW / 2 - 15,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.accentMuted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.horizontal(
                      left: prevAttended
                          ? Radius.zero
                          : const Radius.circular(12),
                      right: nextAttended
                          ? Radius.zero
                          : const Radius.circular(12),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: circleFill,
                    border: circleBorder,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.2,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
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
                      color: barColor,
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

  // ── 선택 날짜 상세 — 통합형 인용 카드 ─────────────────────────

  Widget _buildDayDetail(String dateStr, AppColorTokens colors) {
    final like = _likeByDate[dateStr];
    final memo = _memoByDate[dateStr];
    final parts = dateStr.split('-');
    final displayDate = '${parts[1]}.${parts[2]}';

    if (like == null && memo == null) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Text(
            '이 날의 기록이 없습니다.',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: colors.textSecondary,
            ),
          ),
        ),
      );
    }

    final quote = _quoteByDate[dateStr];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 + 전체보기 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayDate,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: colors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              _TapScaleButton(
                onTap: () {
                  setState(() => _selectedDate = null);
                  _triggerStagger();
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                  child: Text(
                    '전체보기',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 통합 카드 — 탭 시 상세 화면으로 이동
          _TapScaleButton(
            onTap: () => _navigateToDetail(dateStr),
            child: Container(
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 인용구 — accent 세로 바 블록
                  if (like != null ||
                      (memo != null && _quoteByDate.containsKey(dateStr)))
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 3,
                              decoration: BoxDecoration(
                                color: colors.accent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          quote?.sentence ?? '불러오는 중...',
                                          style: TextStyle(
                                            fontFamily: 'Pretendard',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                            height: 1.65,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (like != null) ...[
                                        const SizedBox(width: 8),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Icon(
                                            Icons.favorite,
                                            size: 14,
                                            color: colors.accent,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (quote?.author.isNotEmpty == true) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '— ${quote!.author}',
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w300,
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
                  // 구분선 + 메모 영역
                  if (memo != null) ...[
                    if (like != null || _quoteByDate.containsKey(dateStr))
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: colors.divider,
                        indent: 16,
                        endIndent: 16,
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.edit_note_outlined,
                              size: 13,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              memo.content,
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                                color: colors.textPrimary,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ), // _TapScaleButton
        ],
      ),
    );
  }

  // ── 월 전체 기록 목록 — 타임라인 ──────────────────────────────

  Widget _buildMonthList(AppColorTokens colors) {
    final prefix = '$_year-${_pad(_month)}-';
    final activeDates = {
      ..._likeByDate.keys.where((d) => d.startsWith(prefix)),
      ..._memoByDate.keys.where((d) => d.startsWith(prefix)),
    }.toList()..sort((a, b) => b.compareTo(a));

    if (activeDates.isEmpty) {
      return Center(
        child: Text(
          '이번 달 기록이 없습니다.',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: colors.textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(5, 25, 20, 20),
      itemCount: activeDates.length,
      itemBuilder: (context, i) {
        final dateStr = activeDates[i];
        final isLast = i == activeDates.length - 1;

        final start = (i * 0.06).clamp(0.0, 0.9);
        final end = min(start + 0.25, 1.0);
        final animation = CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end, curve: Curves.easeOut),
        );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(animation),
            child: _buildTimelineItem(dateStr, isLast, colors),
          ),
        );
      },
    );
  }

  Widget _buildTimelineItem(
    String dateStr,
    bool isLast,
    AppColorTokens colors,
  ) {
    final like = _likeByDate[dateStr];
    final memo = _memoByDate[dateStr];
    final quote = _quoteByDate[dateStr];
    final parts = dateStr.split('-');
    final displayDate = parts[2];

    return GestureDetector(
      onTap: () => _navigateToDetail(dateStr),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ① 날짜 컬럼 (44dp 고정, tabular-nums)
            SizedBox(
              width: 44,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    displayDate,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: colors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // ② 타임라인 레일 (인디케이터 점 + 수직선)
            Column(
              children: [
                const SizedBox(height: 3),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent,
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1, color: colors.divider)),
              ],
            ),
            const SizedBox(width: 12),
            // ③ 콘텐츠
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (like != null || _quoteByDate.containsKey(dateStr)) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              quote?.sentence ?? '불러오는 중...',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.65,
                                color: colors.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (like != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 5,
                                right: 10,
                                left: 8,
                              ),
                              child: Icon(
                                Icons.favorite,
                                size: 13,
                                color: colors.accent,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (quote?.author.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '— ${quote!.author}',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              color: colors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    if (memo != null) ...[
                      const SizedBox(height: 8),
                      Divider(height: 1, thickness: 1, color: colors.divider),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.edit_note_outlined,
                            size: 12,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              memo.content,
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: colors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 탭 시 scale(0.96) 피드백 버튼 ─────────────────────────────────

class _TapScaleButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _TapScaleButton({required this.onTap, required this.child});

  @override
  State<_TapScaleButton> createState() => _TapScaleButtonState();
}

class _TapScaleButtonState extends State<_TapScaleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
