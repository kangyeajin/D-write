enum UserRole { user, admin }

class UserProfile {
  final String uid;
  final String email;
  final String nickname;
  final String gender; // 'male' | 'female' | 'private'
  final int? birthYear;
  final int? birthMonth;
  final int? birthDay;
  final bool locationConsent;
  final bool privacyConsent;
  final UserRole role;
  final bool notifPopup;
  final bool notifSound;
  final bool notifVibration;
  final String theme; // 'light' | 'dark'
  final String? notifTime; // "HH:mm", null = 미설정

  // ── 출석 / 문장 추천 ──────────────────────────────────────
  final List<String> seenQuoteIds;
  final int seenQuotesCount;
  final List<String> attendanceDates;
  final int consecutiveDays;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.nickname,
    this.gender = 'private',
    this.birthYear,
    this.birthMonth,
    this.birthDay,
    this.locationConsent = false,
    this.privacyConsent = false,
    this.role = UserRole.user,
    this.notifPopup = false,
    this.notifSound = false,
    this.notifVibration = false,
    this.theme = 'light',
    this.notifTime,
    this.seenQuoteIds = const [],
    this.seenQuotesCount = 0,
    this.attendanceDates = const [],
    this.consecutiveDays = 0,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data, String uid) {
    return UserProfile(
      uid: uid,
      email: (data['email'] as String?) ?? '',
      nickname: (data['nickname'] as String?) ?? '',
      gender: (data['gender'] as String?) ?? 'private',
      birthYear: data['birthYear'] as int?,
      birthMonth: data['birthMonth'] as int?,
      birthDay: data['birthDay'] as int?,
      locationConsent: (data['locationConsent'] as bool?) ?? false,
      privacyConsent: (data['privacyConsent'] as bool?) ?? false,
      role: (data['role'] as String?) == 'admin' ? UserRole.admin : UserRole.user,
      notifPopup: (data['notifPopup'] as bool?) ?? false,
      notifSound: (data['notifSound'] as bool?) ?? false,
      notifVibration: (data['notifVibration'] as bool?) ?? false,
      theme: (data['theme'] as String?) ?? 'light',
      notifTime: data['notifTime'] as String?,
      seenQuoteIds: List<String>.from((data['seenQuoteIds'] as List?) ?? []),
      seenQuotesCount: (data['seen_quotes_count'] as int?) ?? 0,
      attendanceDates: List<String>.from((data['attendanceDates'] as List?) ?? []),
      consecutiveDays: (data['consecutiveDays'] as int?) ?? 0,
    );
  }

  UserProfile copyWith({
    String? nickname,
    String? gender,
    int? birthYear,
    int? birthMonth,
    int? birthDay,
    bool? notifPopup,
    bool? notifSound,
    bool? notifVibration,
    String? theme,
    Object? notifTime = _sentinel,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      nickname: nickname ?? this.nickname,
      gender: gender ?? this.gender,
      birthYear: birthYear ?? this.birthYear,
      birthMonth: birthMonth ?? this.birthMonth,
      birthDay: birthDay ?? this.birthDay,
      locationConsent: locationConsent,
      privacyConsent: privacyConsent,
      role: role,
      notifPopup: notifPopup ?? this.notifPopup,
      notifSound: notifSound ?? this.notifSound,
      notifVibration: notifVibration ?? this.notifVibration,
      theme: theme ?? this.theme,
      notifTime: notifTime == _sentinel ? this.notifTime : notifTime as String?,
    );
  }

  static const Object _sentinel = Object();

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nickname': nickname,
      'gender': gender,
      if (birthYear != null) 'birthYear': birthYear,
      if (birthMonth != null) 'birthMonth': birthMonth,
      if (birthDay != null) 'birthDay': birthDay,
      'locationConsent': locationConsent,
      'privacyConsent': privacyConsent,
      'role': role == UserRole.admin ? 'admin' : 'user',
      'notifPopup': notifPopup,
      'notifSound': notifSound,
      'notifVibration': notifVibration,
      'theme': theme,
      if (notifTime != null) 'notifTime': notifTime,
    };
  }
}
