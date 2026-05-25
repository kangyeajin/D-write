import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:d_write/core/models/memo_model.dart';
import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/core/models/user_model.dart';
import 'package:d_write/core/services/like_service.dart';
import 'package:d_write/core/services/notification_service.dart';
import 'package:d_write/core/services/memo_service.dart';
import 'package:d_write/core/services/local_data_service.dart';
import 'package:d_write/core/services/quote_recommendation_service.dart';
import 'package:d_write/core/services/quote_service.dart';
import 'package:d_write/core/services/user_service.dart';
import 'package:d_write/core/theme/app_palette.dart';
import 'package:d_write/core/utils/snack_bar_utils.dart';
import 'package:d_write/core/theme/app_text_styles.dart';
import 'package:d_write/core/theme/theme_notifier.dart';
import 'package:d_write/presentation/admin/add_sentence_screen.dart';
import 'package:d_write/presentation/admin/admin_quotes_screen.dart';
import 'package:d_write/presentation/admin/auto_create_sentence_screen.dart';
import 'package:d_write/presentation/main/camera_screen.dart';
import 'package:d_write/presentation/main/save_edit_screen.dart';
import 'package:d_write/presentation/menu/app_options_screen.dart';
import 'package:d_write/presentation/menu/calendar_screen.dart';
import 'package:d_write/presentation/menu/liked_sentences_screen.dart';
import 'package:d_write/presentation/menu/my_info_screen.dart';
import 'package:d_write/presentation/menu/my_memos_screen.dart';
import 'package:d_write/repositories/quote_repository.dart';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final QuoteRecommendationService _recommendationService =
      QuoteRecommendationService();
  final QuoteService _quoteService = QuoteService(repo: QuoteRepository());
  final LikeService _likeService = LikeService();
  final MemoService _memoService = MemoService();
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();

  Quote? _quote;
  bool _isLoading = true;
  bool _active = false;
  bool _isLiked = false;
  Memo? _currentMemo;
  UserProfile? _userProfile;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadQuote();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserProfile());
  }

  // 테마·색상을 적용하기 위해 프로필을 먼저 로드하고, 이후 문장과 좋아요 상태를 불러오는 순서로 진행
  Future<void> _loadUserProfile() async {
    final uid = _uid;
    if (uid == null) return;
    final profile = await _userService.getUserProfile(uid);
    if (!mounted || profile == null) return;
    setState(() => _userProfile = profile);
    final notifier = context.read<ThemeNotifier>();
    notifier.setTheme(profile.theme);
    notifier.setPaletteById(profile.palette);
    debugPrint(
      '[AUTH] 프로필 로드 완료 — role=${profile.role.name}, palette=${profile.palette}',
    );

    final local = LocalDataService();
    if (local.localAttendanceDates.isEmpty &&
        profile.attendanceDates.isNotEmpty) {
      await local.restoreAttendance(
        profile.attendanceDates,
        profile.consecutiveDays,
      );
      debugPrint(
        '[ATTEND] Firestore에서 출석 데이터 복원 — ${profile.attendanceDates.length}개, consecutiveDays=${profile.consecutiveDays}',
      );
    }

    // 재설치 후 첫 실행 — 알림 설정이 켜져 있었던 경우 권한 재요청
    if (profile.notifPopup && !local.notifPermissionChecked) {
      await local.setNotifPermissionChecked();
      if (mounted) await _handleNotifPermissionOnReinstall(profile);
    }
  }

  Future<void> _handleNotifPermissionOnReinstall(UserProfile profile) async {
    final alreadyGranted = await _notificationService.areNotificationsEnabled();
    if (alreadyGranted) {
      final time = _parseNotifTime(profile.notifTime);
      if (time != null) {
        await _notificationService.scheduleDailyNotification(
          time: time,
          withSound: profile.notifSound,
          withVibration: profile.notifVibration,
        );
        debugPrint('[ATTEND] 재설치 감지 — 알림 권한 이미 허용, 재스케줄링 완료');
      }
      return;
    }
    if (!mounted) return;

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('알림 권한이 필요합니다'),
        content: const Text(
          '이전에 알림을 설정하셨습니다.\n앱 재설치 후 권한이 초기화되어 다시 허용이 필요합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('허용'),
          ),
        ],
      ),
    );

    if (proceed != true) {
      await _disableNotifPopup();
      return;
    }

    final granted = await _notificationService.requestPermission();
    if (!granted) {
      debugPrint('[ATTEND] 알림 권한 거부 → notifPopup 비활성화');
      await _disableNotifPopup();
      return;
    }

    final time = _parseNotifTime(profile.notifTime);
    if (time != null) {
      await _notificationService.scheduleDailyNotification(
        time: time,
        withSound: profile.notifSound,
        withVibration: profile.notifVibration,
      );
      debugPrint('[ATTEND] 재설치 감지 — 알림 권한 허용, 재스케줄링 완료');
    }
  }

  Future<void> _disableNotifPopup() async {
    final uid = _uid;
    if (uid == null) return;
    await _userService.updateSettings(uid, {'notifPopup': false});
    if (mounted) {
      showAppSnackBar(
        context,
        '알림이 꺼졌습니다. 앱 설정에서 다시 활성화할 수 있습니다.',
        duration: const Duration(seconds: 4),
      );
    }
  }

  TimeOfDay? _parseNotifTime(String? timeStr) {
    if (timeStr == null) return null;
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  Future<void> _loadQuote() async {
    final uid = _uid;
    final quote = uid != null
        ? await _recommendationService.getTodayQuote(uid)
        : await _quoteService.getRandomQuote();
    if (!mounted) return;
    setState(() {
      _quote = quote;
      _isLoading = false;
    });
    if (quote != null) {
      _loadLikeStatus(quote.id);
      _loadCurrentMemo(quote.id);
    }
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

  Future<void> _loadLikeStatus(String quoteId) async {
    final uid = _uid;
    if (uid == null) return;
    final local = LocalDataService();
    final cached = local.todayIsLiked;
    if (cached != null) {
      if (mounted) setState(() => _isLiked = cached);
      return;
    }
    final liked = await _likeService.isLiked(uid, quoteId);
    if (mounted) {
      setState(() => _isLiked = liked);
      local.setTodayLike(liked);
    }
  }

  Future<void> _loadCurrentMemo(String quoteId) async {
    final uid = _uid;
    if (uid == null) return;
    final local = LocalDataService();
    if (local.isTodayMemoCached) {
      if (mounted) setState(() => _currentMemo = local.todayMemo);
      return;
    }
    final memo = await _memoService.getMemoForUserAndQuote(uid, quoteId);
    if (mounted) {
      setState(() => _currentMemo = memo);
      local.setTodayMemo(memo);
    }
  }

  // ── 좋아요 (낙관적 업데이트) ──────────────────────────────────
  Future<void> _toggleLike() async {
    final uid = _uid;
    final quoteId = _quote?.id;
    if (uid == null || quoteId == null) return;

    final previous = _isLiked;
    setState(() => _isLiked = !_isLiked);
    LocalDataService().setTodayLike(_isLiked);

    try {
      if (previous) {
        await _likeService.removeLike(uid, quoteId);
      } else {
        await _likeService.addLike(uid, quoteId);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLiked = previous);
        LocalDataService().setTodayLike(previous);
        _showNetworkError();
      }
    }
  }

  // ── 메모 다이얼로그 ───────────────────────────────────────────
  void _openMemoSheet() {
    final uid = _uid;
    final quoteId = _quote?.id;
    if (uid == null || quoteId == null) return;

    final controller = TextEditingController(text: _currentMemo?.content ?? '');
    final isEditing = _currentMemo != null;
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
                    // X 닫기 버튼 — 여백 없이 모서리에 붙음
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
                    // 입력창 + 버튼: 좌우 여백 유지
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
                                  await _saveMemo(uid, quoteId, text);
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

  Future<void> _saveMemo(String uid, String quoteId, String content) async {
    debugPrint(
      '[MEMO] 저장 시작 — isEditing=${_currentMemo != null}, length=${content.length}',
    );
    if (content.isEmpty) {
      debugPrint('[MEMO] 빈 내용 → ${_currentMemo != null ? '기존 메모 삭제' : '스킵'}');
      if (_currentMemo != null) await _deleteMemo();
      return;
    }
    if (_currentMemo != null && content == _currentMemo!.content) {
      debugPrint('[MEMO] 내용 미변경 → 업데이트 생략');
      return;
    }
    try {
      final Memo updated;
      if (_currentMemo != null) {
        await _memoService.updateMemo(_currentMemo!.id, content);
        debugPrint('[MEMO] 수정 완료 — id=${_currentMemo!.id}');
        updated = Memo(
          id: _currentMemo!.id,
          quoteId: _currentMemo!.quoteId,
          userId: _currentMemo!.userId,
          content: content,
          date: _currentMemo!.date,
          createdAt: _currentMemo!.createdAt,
        );
      } else {
        final docId = await _memoService.saveMemo(uid, quoteId, content);
        debugPrint('[MEMO] 신규 저장 완료 — id=$docId');
        final now = DateTime.now();
        updated = Memo(
          id: docId,
          quoteId: quoteId,
          userId: uid,
          content: content,
          date:
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          createdAt: Timestamp.now(),
        );
      }
      if (mounted) {
        setState(() => _currentMemo = updated);
        LocalDataService().setTodayMemo(updated);
      }
    } catch (_) {
      if (mounted) _showNetworkError();
    }
  }

  Future<void> _deleteMemo() async {
    final memo = _currentMemo;
    if (memo == null) return;
    try {
      await _memoService.deleteMemo(memo.id);
      if (mounted) {
        setState(() => _currentMemo = null);
        LocalDataService().setTodayMemo(null);
      }
    } catch (_) {
      if (mounted) _showNetworkError();
    }
  }

  void _syncFromCache() {
    final local = LocalDataService();
    final cachedLike = local.todayIsLiked;
    if (cachedLike != null) setState(() => _isLiked = cachedLike);
    if (local.isTodayMemoCached) setState(() => _currentMemo = local.todayMemo);
  }

  void _activate() {
    if (!_active) {
      setState(() => _active = true);
      _recordAttendance();
    }
  }

  void _recordAttendance() {
    final uid = _uid;
    if (uid == null || _quote == null) return;
    _recommendationService.markAttendance(uid);
  }

  void _deactivate() {
    if (_active) setState(() => _active = false);
  }

  String get _dateLabel {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
  }

  // ── 빌드 ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);
    final size = MediaQuery.sizeOf(context);
    final hPad = (size.width * 0.08).clamp(24.0, 40.0);

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context, colors),
      backgroundColor: colors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _deactivate,
        onVerticalDragUpdate: (d) {
          if (d.delta.dy < -5) {
            _activate();
          } else if (d.delta.dy > 5) {
            _deactivate();
          }
        },
        child: Stack(
          children: [
            _buildBody(context, colors, hPad, size),
            _buildTopLeft(context, colors),
            _buildTopRight(context, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppColorTokens colors,
    double hPad,
    Size size,
  ) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad),
        child: Column(
          children: [
            SizedBox(height: size.height * 0.25),

            // 날짜
            _Fade(
              visible: true,
              child: Text(
                _dateLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 20,
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 메인 문장
            if (_isLoading)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.textSecondary,
                ),
              )
            else
              Text(
                _quote?.sentence ?? '등록된 문장이 없습니다.',
                textAlign: TextAlign.center,
                style: AppTextStyles.sentenceBody(color: colors.textPrimary),
              ),

            // 저자
            _Fade(
              visible: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  _quote != null ? '— ${_quote!.author}' : '',
                  style: AppTextStyles.sentenceSource.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),

            // 메모 내용
            if (_currentMemo != null && _currentMemo!.content.isNotEmpty)
              _Fade(
                visible: _active,
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _currentMemo!.content,
                      style: AppTextStyles.body.copyWith(
                        color: colors.textSecondary,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

            // 액션 버튼
            _Fade(
              visible: _active,
              child: Padding(
                padding: const EdgeInsets.only(top: 28),
                child: _buildActions(colors),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(AppColorTokens colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 좋아요
        _ActionButton(
          icon: _isLiked ? Icons.favorite : Icons.favorite_border,
          color: _isLiked ? colors.accent : colors.textSecondary,
          tooltip: '좋아요',
          onTap: _active ? _toggleLike : null,
        ),
        const SizedBox(width: 8),
        // 메모
        _ActionButton(
          icon: _currentMemo != null ? Icons.edit : Icons.edit_outlined,
          color: _currentMemo != null ? colors.accent : colors.textSecondary,
          tooltip: '메모',
          onTap: _active ? _openMemoSheet : null,
        ),
        const SizedBox(width: 8),
        // 저장
        _ActionButton(
          icon: Icons.download_outlined,
          color: colors.textSecondary,
          tooltip: '저장',
          onTap: _active && _quote != null
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SaveEditScreen(quote: _quote!),
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildTopLeft(BuildContext context, AppColorTokens colors) {
    return _Fade(
      visible: _active,
      child: Align(
        alignment: Alignment.topLeft,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: IconButton(
              icon: Icon(Icons.menu, size: 24, color: colors.textPrimary),
              onPressed: _active
                  ? () => _scaffoldKey.currentState?.openDrawer()
                  : null,
              tooltip: '메뉴',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopRight(BuildContext context, AppColorTokens colors) {
    return _Fade(
      visible: _active,
      child: Align(
        alignment: Alignment.topRight,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(right: 4, top: 4),
            child: IconButton(
              icon: Icon(
                Icons.camera_alt_outlined,
                size: 24,
                color: colors.textPrimary,
              ),
              onPressed: _active && _quote != null
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CameraScreen(quote: _quote!),
                      ),
                    )
                  : null,
              tooltip: '카메라',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AppColorTokens colors) {
    return Drawer(
      backgroundColor: colors.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.settings_outlined,
                      color: colors.textPrimary,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const AppOptionsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(
                    label: '내 정보',
                    colors: colors,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const MyInfoScreen(),
                      ),
                    ),
                  ),
                  _DrawerItem(
                    label: '달력',
                    colors: colors,
                    onTap: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CalendarScreen(),
                        ),
                      );
                      if (mounted && _quote != null) _syncFromCache();
                    },
                  ),
                  _DrawerItem(
                    label: '좋아요 한 문장',
                    colors: colors,
                    onTap: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LikedSentencesScreen(),
                        ),
                      );
                      if (mounted && _quote != null) _syncFromCache();
                    },
                  ),
                  _DrawerItem(
                    label: '내가 쓴 메모',
                    colors: colors,
                    onTap: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyMemosScreen(),
                        ),
                      );
                      if (mounted && _quote != null) _syncFromCache();
                    },
                  ),
                  if (_userProfile?.role == UserRole.admin) ...[
                    _DrawerItem(
                      label: '문장 등록',
                      colors: colors,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AddSentenceScreen(),
                        ),
                      ),
                    ),
                    _DrawerItem(
                      label: '문장 자동 생성',
                      colors: colors,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AutoCreateSentenceScreen(),
                        ),
                      ),
                    ),
                    _DrawerItem(
                      label: '월별 문장 관리',
                      colors: colors,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminQuotesScreen(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 재사용 위젯 ───────────────────────────────────────────────

/// opacity fade-in/out 래퍼
class _Fade extends StatelessWidget {
  const _Fade({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      child: IgnorePointer(ignoring: !visible, child: child),
    );
  }
}

/// 액션 아이콘 버튼 (44×44 최소 히트 영역, scale on press)
class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Tooltip(
        message: widget.tooltip,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(widget.icon, size: 22, color: widget.color),
          ),
        ),
      ),
    );
  }
}

/// 드로어 메뉴 항목 (선 없는 미니멀 스타일)
class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final AppColorTokens colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(color: colors.textPrimary),
        ),
      ),
    );
  }
}
