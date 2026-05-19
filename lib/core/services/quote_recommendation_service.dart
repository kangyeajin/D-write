import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/core/services/local_data_service.dart';
import 'package:d_write/core/services/weather_service.dart';
import 'package:d_write/repositories/quote_repository.dart';
import 'package:d_write/repositories/user_repository.dart';
import 'package:flutter/foundation.dart';

class QuoteRecommendationService {
  final QuoteRepository _quoteRepo;
  final UserRepository _userRepo;
  final LocalDataService _local;
  final WeatherService _weather;

  QuoteRecommendationService({
    QuoteRepository? quoteRepo,
    UserRepository? userRepo,
    LocalDataService? local,
    WeatherService? weather,
  }) : _quoteRepo = quoteRepo ?? QuoteRepository(),
       _userRepo = userRepo ?? UserRepository(),
       _local = local ?? LocalDataService(),
       _weather = weather ?? WeatherService();

  /// 오늘의 문장을 반환.
  /// - 오늘 이미 선정된 경우 캐시에서 즉시 반환
  /// - 날짜 변경 시 3단계 fallback 추천 실행
  Future<Quote?> getTodayQuote(String uid) async {
    final todayStr = _todayStr();
    debugPrint('[QUOTE] getTodayQuote() 시작 — today=$todayStr');

    // 1. 오늘 이미 선정된 문장이 있으면 즉시 반환
    if (_local.lastUpdateDate == todayStr) {
      final cached = _local.getQuoteById(_local.todayQuoteId ?? '');
      if (cached != null) {
        debugPrint('[QUOTE] 캐시 히트 → 즉시 반환 id=${cached.id}');
        return cached;
      }
    }

    debugPrint('[QUOTE] lastUpdateDate=${_local.lastUpdateDate} → 신규 선정 시작');

    // 2. 월별 캐시 최신화
    final currentMonth = DateTime.now().month;
    if (_local.cachedMonth != currentMonth) {
      debugPrint(
        '[QUOTE] 월 캐시 없음(cached=${_local.cachedMonth}) → Firestore 문장 조회 (month=$currentMonth)',
      );
      await _refreshMonthCache(currentMonth);
      debugPrint('[QUOTE] 캐시 저장 완료: ${_local.getCachedQuotes().length}개');
    } else {
      debugPrint(
        '[QUOTE] 월 캐시 유효 (month=$currentMonth, ${_local.getCachedQuotes().length}개)',
      );
    }

    // 3. 날씨 조회 (실패 시 'All')
    final weather = await _weather.getCurrentWeather();
    debugPrint('[QUOTE] 날씨=\'$weather\'');

    // 4. seenQuoteIds 로컬 캐시 로드 (없으면 Firestore에서 초기화)
    List<String> seenIds = _local.seenQuoteIds;
    if (seenIds.isEmpty) {
      debugPrint('[QUOTE] seenIds 로컬 없음 → Firestore 조회');
      final daily = await _userRepo.getDailyData(uid);
      seenIds = daily.seenIds;
      await _local.setSeenQuoteIds(seenIds);
      debugPrint('[QUOTE] seenIds 로드 완료 (${seenIds.length}개)');
      debugPrint(
        '[QUOTE] Firestore dailyData — fsDate=${daily.todayDate}, fsQuoteId=${daily.todayQuoteId}',
      );

      // 다른 기기에서 오늘 이미 문장이 배정된 경우 → 동일 문장 반환 (기기 간 일관성)
      final fsQuoteId = daily.todayQuoteId ?? '';
      if (daily.todayDate == todayStr && fsQuoteId.isNotEmpty) {
        debugPrint('[QUOTE] Firestore 오늘 문장 존재 → 재사용 id=$fsQuoteId');
        final quote = await _quoteRepo.getQuote(fsQuoteId);
        if (quote != null) {
          await _local.setTodayQuote(fsQuoteId, todayStr);
          debugPrint('[QUOTE] 로컬 캐시 저장 완료 → 반환 id=$fsQuoteId');
          return quote;
        }
        debugPrint('[QUOTE] Firestore 문장 조회 실패 → 신규 선정 진행');
      } else {
        debugPrint(
          '[QUOTE] Firestore 오늘 문장 없음 (fsDate=${daily.todayDate} ≠ today=$todayStr) → 신규 선정',
        );
      }
    } else {
      debugPrint('[QUOTE] seenIds 로컬 캐시 사용 (${seenIds.length}개)');
    }

    // 5. 문장 조회
    final selected = _selectQuote(weather, seenIds, currentMonth);
    if (selected == null) {
      debugPrint('[QUOTE] 문장 선택 실패 (캐시 비어있음)');
      return null;
    }

    // 6. 출석 처리 (로컬)
    final yesterday = _yesterdayStr();
    final localDates = _local.localAttendanceDates;
    final newConsecutive = localDates.contains(yesterday)
        ? _local.consecutiveDays + 1
        : 1;

    debugPrint('[ATTEND] consecutiveDays=$newConsecutive, date=$todayStr');

    await _local.setTodayQuote(selected.id, todayStr);
    await _local.setAttendance(todayStr, newConsecutive);
    await _local.addSeenQuoteId(selected.id);

    // 7. Firestore 단일 배치 업데이트 (비동기, 실패해도 UX 차단 안 함)
    final updatedIds = _local.seenQuoteIds;
    final needsSlice = updatedIds.length > 1500;
    final sliced = needsSlice ? updatedIds.sublist(500) : null;

    debugPrint(
      '[ATTEND] Firestore 동기화 시작 (fire-and-forget) — todayDate=$todayStr, quoteId=${selected.id}',
    );
    _userRepo
        .recordDailyActivity(
          uid: uid,
          newQuoteId: selected.id,
          todayStr: todayStr,
          consecutiveDays: newConsecutive,
          slicedSeenIds: sliced,
        )
        .catchError((Object e) {
          debugPrint('[ATTEND] Firestore 동기화 실패: $e');
        });

    return selected;
  }

  /// 3단계 fallback 추천
  Quote? _selectQuote(String weather, List<String> seenIds, int currentMonth) {
    final all = _local.getCachedQuotes();
    if (all.isEmpty) return null;

    final unseen = all.where((q) => !seenIds.contains(q.id)).toList();
    debugPrint('[QUOTE] 전체=${all.length}개, 미열람=${unseen.length}개');

    // 1순위: 이번 달 + 안 본 + 날씨 매칭
    final stage1 =
        unseen
            .where(
              (q) =>
                  q.month == currentMonth &&
                  (q.weatherTags.contains(weather) ||
                      q.weatherTags.contains('All')),
            )
            .toList()
          ..shuffle();
    if (stage1.isNotEmpty) {
      debugPrint('[QUOTE] 선택=${stage1.first.id} (1순위: 이번달+미열람+날씨)');
      return stage1.first;
    }

    // 2순위: 이번 달 + 안 본 (날씨 무시)
    final stage2 = unseen.where((q) => q.month == currentMonth).toList()
      ..shuffle();
    if (stage2.isNotEmpty) {
      debugPrint('[QUOTE] 선택=${stage2.first.id} (2순위: 이번달+미열람)');
      return stage2.first;
    }

    // 3순위: 전체 + 안 본
    final stage3 = unseen.toList()..shuffle();
    if (stage3.isNotEmpty) {
      debugPrint('[QUOTE] 선택=${stage3.first.id} (3순위: 전체+미열람)');
      return stage3.first;
    }

    // 전부 봤으면 전체에서 랜덤
    all.shuffle();
    debugPrint('[QUOTE] 선택=${all.first.id} (폴백: 전부 열람, 랜덤)');
    return all.first;
  }

  Future<void> _refreshMonthCache(int month) async {
    try {
      final quotes = await _quoteRepo.getQuotesByMonth(month);
      await _local.cacheQuotes(quotes, month);
    } catch (e) {
      debugPrint('[QUOTE] 월 캐시 갱신 실패: $e');
    }
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayStr() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }
}
