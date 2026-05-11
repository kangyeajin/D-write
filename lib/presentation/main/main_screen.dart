import 'package:d_write/core/models/memo_model.dart';
import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/core/models/user_model.dart';
import 'package:d_write/core/services/like_service.dart';
import 'package:d_write/core/services/memo_service.dart';
import 'package:d_write/core/services/quote_recommendation_service.dart';
import 'package:d_write/core/services/quote_service.dart';
import 'package:d_write/core/services/user_service.dart';
import 'package:d_write/core/theme/app_palette.dart';
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

  final QuoteRecommendationService _recommendationService = QuoteRecommendationService();
  final QuoteService _quoteService = QuoteService(repo: QuoteRepository());
  final LikeService _likeService = LikeService();
  final MemoService _memoService = MemoService();
  final UserService _userService = UserService();

  Quote? _quote;
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

  Future<void> _loadUserProfile() async {
    final uid = _uid;
    if (uid == null) return;
    final profile = await _userService.getUserProfile(uid);
    if (!mounted || profile == null) return;
    setState(() => _userProfile = profile);
    final notifier = context.read<ThemeNotifier>();
    notifier.setTheme(profile.theme);
    notifier.setPaletteById(profile.palette);
    debugPrint('[AUTH] 프로필 로드 완료 — role=${profile.role.name}, palette=${profile.palette}');
  }

  Future<void> _loadQuote() async {
    final uid = _uid;
    final quote = uid != null
        ? await _recommendationService.getTodayQuote(uid)
        : await _quoteService.getRandomQuote();
    if (!mounted) return;
    setState(() => _quote = quote);
    if (quote != null) {
      _loadLikeStatus(quote.id);
      _loadCurrentMemo(quote.id);
    }
  }

  Future<void> _loadLikeStatus(String quoteId) async {
    final uid = _uid;
    if (uid == null) return;
    final liked = await _likeService.isLiked(uid, quoteId);
    if (mounted) setState(() => _isLiked = liked);
  }

  Future<void> _loadCurrentMemo(String quoteId) async {
    final uid = _uid;
    if (uid == null) return;
    final memo = await _memoService.getMemoForUserAndQuote(uid, quoteId);
    if (mounted) setState(() => _currentMemo = memo);
  }

  // ── 좋아요 (낙관적 업데이트) ──────────────────────────────────
  Future<void> _toggleLike() async {
    final uid = _uid;
    final quoteId = _quote?.id;
    if (uid == null || quoteId == null) return;

    final previous = _isLiked;
    setState(() => _isLiked = !_isLiked);

    try {
      if (previous) {
        await _likeService.removeLike(uid, quoteId);
      } else {
        await _likeService.addLike(uid, quoteId);
      }
    } catch (_) {
      if (mounted) setState(() => _isLiked = previous);
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
            style: AppTextStyles.body.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: '이 문장에 대한 생각을 기록해보세요.',
              border: OutlineInputBorder(
                borderSide: BorderSide(color: colors.divider),
              ),
            ),
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _deleteMemo();
                },
                child: Text('삭제', style: TextStyle(color: colors.error)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();
                Navigator.pop(dialogContext);
                await _saveMemo(uid, quoteId, text);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveMemo(String uid, String quoteId, String content) async {
    if (content.isEmpty) {
      if (_currentMemo != null) await _deleteMemo();
      return;
    }
    if (_currentMemo != null) {
      await _memoService.updateMemo(_currentMemo!.id, content);
    } else {
      await _memoService.saveMemo(uid, quoteId, content);
    }
    await _loadCurrentMemo(quoteId);
  }

  Future<void> _deleteMemo() async {
    final memo = _currentMemo;
    if (memo == null) return;
    await _memoService.deleteMemo(memo.id);
    if (mounted) setState(() => _currentMemo = null);
  }

  void _activate() {
    if (!_active) setState(() => _active = true);
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
          if (d.delta.dy < -5) { _activate(); }
          else if (d.delta.dy > 5) { _deactivate(); }
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
            SizedBox(height: size.height * 0.18),

            // 날짜
            _Fade(
              visible: _active,
              child: Text(
                _dateLabel,
                style: AppTextStyles.dateLabel.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 메인 문장
            AnimatedOpacity(
              opacity: _active ? 1.0 : 0.22,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: Text(
                _quote?.sentence ?? '등록된 문장이 없습니다.',
                textAlign: TextAlign.center,
                style: AppTextStyles.sentenceBody(color: colors.textPrimary),
              ),
            ),

            // 저자
            _Fade(
              visible: _active,
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

            // 액션 버튼
            _Fade(
              visible: _active,
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
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
              onPressed: _active ? () => _scaffoldKey.currentState?.openDrawer() : null,
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
              icon: Icon(Icons.camera_alt_outlined, size: 24, color: colors.textPrimary),
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
                    icon: Icon(Icons.settings_outlined, color: colors.textPrimary),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const AppOptionsScreen()),
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
                      MaterialPageRoute<void>(builder: (_) => const MyInfoScreen()),
                    ),
                  ),
                  _DrawerItem(
                    label: '달력',
                    colors: colors,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const CalendarScreen()),
                    ),
                  ),
                  _DrawerItem(
                    label: '좋아요 한 문장',
                    colors: colors,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const LikedSentencesScreen()),
                    ),
                  ),
                  _DrawerItem(
                    label: '내가 쓴 메모',
                    colors: colors,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const MyMemosScreen()),
                    ),
                  ),
                  if (_userProfile?.role == UserRole.admin) ...[
                    _DrawerItem(
                      label: '문장 등록',
                      colors: colors,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const AddSentenceScreen()),
                      ),
                    ),
                    _DrawerItem(
                      label: '문장 자동 생성',
                      colors: colors,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const AutoCreateSentenceScreen()),
                      ),
                    ),
                    _DrawerItem(
                      label: '월별 문장 관리',
                      colors: colors,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const AdminQuotesScreen()),
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
      onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onTap != null ? (_) => setState(() => _pressed = false) : null,
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
