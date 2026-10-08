class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.travelStyle,
    required this.interests,
    required this.privacyLevel,
  });

  final String id;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? travelStyle;
  final List<String> interests;
  final String privacyLevel;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      displayName: map['display_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      bio: map['bio'] as String?,
      travelStyle: map['travel_style'] as String?,
      interests: List<String>.from(map['interests'] as List? ?? const []),
      privacyLevel: map['privacy_level'] as String? ?? 'friends',
    );
  }
}
