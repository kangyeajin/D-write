class UserProfile {
  final String uid;
  String? name;
  String? info;

  UserProfile({required this.uid, this.name, this.info});

  // Firestore에서 데이터를 가져올 때 사용
  factory UserProfile.fromMap(Map<String, dynamic> data, String documentId) {
    return UserProfile(
      uid: documentId,
      name: data['name'],
      info: data['info'],
    );
  }

  // Firestore에 데이터를 저장할 때 사용
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'info': info,
    };
  }
}