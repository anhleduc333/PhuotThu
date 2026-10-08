import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/user_profile.dart';
import 'profile_repository.dart';

final currentProfileProvider = FutureProvider<UserProfile>((ref) async {
  return ref.watch(profileRepositoryProvider).getCurrentProfile();
});
