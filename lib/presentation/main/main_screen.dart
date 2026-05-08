import 'package:d_write/core/models/memo_model.dart';
import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/core/models/user_model.dart';
import 'package:d_write/core/services/like_service.dart';
import 'package:d_write/core/services/memo_service.dart';
import 'package:d_write/core/services/quote_recommendation_service.dart';
import 'package:d_write/core/services/quote_service.dart';
import 'package:d_write/core/services/user_service.dart';
import 'package:d_write/core/theme/app_colors.dart';
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
    context.read<ThemeNotifier>().setTheme(profile.theme);
    debugPrint('[AUTH] 프로필 로드 완료 — role=${profile.role.name}');
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

  // ── 좋아요 (낙관적 업데이트) ──────────────────────────────────────────
  Future<void> _toggleLike() async {
    final uid = _uid;
    final quoteId = _quote?.id;
    if (uid == null || quoteId == null) return;

    final previous = _isLiked;
    setState(() => _isLiked = !_isLiked); // 즉시 UI 반전

    try {
      if (previous) {
        await _likeService.removeLike(uid, quoteId);
      } else {
        await _likeService.addLike(uid, quoteId);
      }
    } catch (_) {
      if (mounted) setState(() => _isLiked = previous); // 실패 시 롤백
    }
  }

  // ── 메모 바텀시트 ─────────────────────────────────────────────────────
  void _openMemoSheet() {
    final uid = _uid;
    final quoteId = _quote?.id;
    if (uid == null || quoteId == null) return;

    final controller = TextEditingController(text: _currentMemo?.content ?? '');
    final isEditing = _currentMemo != null;

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

  // ── 이미지 저장 ───────────────────────────────────────────────────────
  // ── 활성화 상태 전환 ──────────────────────────────────────────────────
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

  // ── 빌드 ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context),
      body: GestureDetector(
        onTap: _deactivate,
        onVerticalDragUpdate: (details) {
          if (details.delta.dy < -5) {
            _activate();
          } else if (details.delta.dy > 5) {
            _deactivate();
          }
        },
        child: Container(
          color: AppColors.backgroundLight,
          child: Stack(
            children: [
              _buildCenter(),
              _buildTopLeft(),
              _buildTopRight(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              opacity: _active ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_dateLabel, style: AppTextStyles.dateLabel),
              ),
            ),
            ColoredBox(
              color: AppColors.backgroundLight,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedOpacity(
                      opacity: _active ? 1.0 : 0.3,
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _quote?.sentence ?? '등록된 문장이 없습니다.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.sentenceTitle,
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: _active ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _quote != null ? '— ${_quote!.author}' : '',
                          style: AppTextStyles.sentenceSource,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _active ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.only(top: 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 좋아요
                    IconButton(
                      icon: Icon(
                        _isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                        color: _isLiked ? AppColors.like : null,
                      ),
                      onPressed: _active ? _toggleLike : null,
                      tooltip: '좋아요',
                    ),
                    // 메모
                    IconButton(
                      icon: Icon(
                        _currentMemo != null
                            ? Icons.note_alt
                            : Icons.note_alt_outlined,
                      ),
                      onPressed: _active ? _openMemoSheet : null,
                      tooltip: '메모',
                    ),
                    // 저장
                    IconButton(
                      icon: const Icon(Icons.download_outlined),
                      onPressed: _active && _quote != null
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      SaveEditScreen(quote: _quote!),
                                ),
                              )
                          : null,
                      tooltip: '저장',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopLeft() {
    return AnimatedOpacity(
      opacity: _active ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
          ),
          child: IconButton(
            icon: const Icon(Icons.menu, size: 28),
            onPressed: _active ? () => _scaffoldKey.currentState?.openDrawer() : null,
          ),
        ),
      ),
    );
  }

  Widget _buildTopRight() {
    return AnimatedOpacity(
      opacity: _active ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
          ),
          child: IconButton(
            icon: const Icon(Icons.camera_alt_outlined, size: 28),
            onPressed: _active
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => CameraScreen(
                          overlayText: _quote?.sentence ?? '',
                        ),
                      ),
                    )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.backgroundLight,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            decoration: const BoxDecoration(color: AppColors.backgroundLight),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
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
          ListTile(
            title: const Text('내 정보'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const MyInfoScreen(),
              ),
            ),
          ),
          ListTile(
            title: const Text('달력'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const CalendarScreen(),
              ),
            ),
          ),
          ListTile(
            title: const Text('좋아요 한 문장'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const LikedSentencesScreen(),
              ),
            ),
          ),
          ListTile(
            title: const Text('내가 쓴 메모'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const MyMemosScreen(),
              ),
            ),
          ),
          if (_userProfile?.role == UserRole.admin) ...[
            ListTile(
              title: const Text('문장 등록'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const AddSentenceScreen(),
                ),
              ),
            ),
            ListTile(
              title: const Text('문장 자동 생성'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const AutoCreateSentenceScreen(),
                ),
              ),
            ),
            ListTile(
              title: const Text('월별 문장 관리'),
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
    );
  }
}
