import 'package:d_write/core/models/quote_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive 박스 이름 상수
const _kBoxQuotes = 'quotes_cache';
const _kBoxUser = 'user_data';

/// user_data box 키
const _kLastUpdateDate = 'lastUpdateDate';
const _kTodayQuoteId = 'todayQuoteId';
const _kCachedMonth = 'cachedMonth';
const _kLocalAttendanceDates = 'localAttendanceDates';
const _kConsecutiveDays = 'consecutiveDays';
const _kSeenQuoteIds = 'seenQuoteIds';

class LocalDataService {
  static final LocalDataService _instance = LocalDataService._();
  factory LocalDataService() => _instance;
  LocalDataService._();

  late Box<dynamic> _userBox;
  late Box<dynamic> _quotesBox;

  Future<void> init() async {
    _userBox = await Hive.openBox<dynamic>(_kBoxUser);
    _quotesBox = await Hive.openBox<dynamic>(_kBoxQuotes);
  }

  // ── user_data getters/setters ──────────────────────────────

  String? get lastUpdateDate => _userBox.get(_kLastUpdateDate) as String?;
  String? get todayQuoteId => _userBox.get(_kTodayQuoteId) as String?;
  int? get cachedMonth => _userBox.get(_kCachedMonth) as int?;
  int get consecutiveDays => (_userBox.get(_kConsecutiveDays) as int?) ?? 0;

  List<String> get localAttendanceDates {
    final raw = _userBox.get(_kLocalAttendanceDates);
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }

  List<String> get seenQuoteIds {
    final raw = _userBox.get(_kSeenQuoteIds);
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }

  Future<void> setTodayQuote(String quoteId, String dateStr) async {
    await _userBox.put(_kTodayQuoteId, quoteId);
    await _userBox.put(_kLastUpdateDate, dateStr);
  }

  Future<void> setAttendance(String todayStr, int consecutiveDays) async {
    final dates = localAttendanceDates;
    if (!dates.contains(todayStr)) {
      dates.add(todayStr);
      await _userBox.put(_kLocalAttendanceDates, dates);
    }
    await _userBox.put(_kConsecutiveDays, consecutiveDays);
  }

  Future<void> addSeenQuoteId(String quoteId) async {
    final ids = seenQuoteIds;
    if (!ids.contains(quoteId)) {
      ids.add(quoteId);
      // 1500개 초과 시 앞 500개 제거
      final trimmed = ids.length > 1500 ? ids.sublist(500) : ids;
      await _userBox.put(_kSeenQuoteIds, trimmed);
    }
  }

  Future<void> setSeenQuoteIds(List<String> ids) async {
    await _userBox.put(_kSeenQuoteIds, ids);
  }

  // ── quotes_cache ───────────────────────────────────────────

  Future<void> cacheQuotes(List<Quote> quotes, int month) async {
    await _quotesBox.clear();
    for (final q in quotes) {
      await _quotesBox.put(q.id, {
        'id': q.id,
        'sentence': q.sentence,
        'author': q.author,
        'month': q.month,
        'weatherTags': q.weatherTags,
      });
    }
    await _userBox.put(_kCachedMonth, month);
  }

  List<Quote> getCachedQuotes() {
    return _quotesBox.values.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return Quote(
        id: m['id'] as String,
        sentence: m['sentence'] as String,
        author: m['author'] as String,
        month: m['month'] as int,
        weatherTags: List<String>.from(m['weatherTags'] as List),
      );
    }).toList();
  }

  Quote? getQuoteById(String id) {
    final raw = _quotesBox.get(id);
    if (raw == null) return null;
    final m = Map<String, dynamic>.from(raw as Map);
    return Quote(
      id: m['id'] as String,
      sentence: m['sentence'] as String,
      author: m['author'] as String,
      month: m['month'] as int,
      weatherTags: List<String>.from(m['weatherTags'] as List),
    );
  }

  Future<void> clear() async {
    await _userBox.clear();
    await _quotesBox.clear();
  }
}
