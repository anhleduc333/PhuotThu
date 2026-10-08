import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<UserProfile> getCurrentProfile() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('User is not authenticated');
    }

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    return UserProfile.fromMap(data);
  }

  Future<void> updateProfile({
    required String displayName,
    String? bio,
    String? travelStyle,
    required List<String> interests,
    required String privacyLevel,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('User is not authenticated');
    }

    await _client
        .from('profiles')
        .update({
          'display_name': displayName,
          'bio': bio,
          'travel_style': travelStyle,
          'interests': interests,
          'privacy_level': privacyLevel,
        })
        .eq('id', user.id);
  }
}
