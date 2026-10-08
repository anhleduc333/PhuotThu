import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/data/auth_repository.dart';
import '../../data/profile_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cá nhân')),
      body: SafeArea(
        child: profileAsync.when(
          loading: () {
            return const Center(child: CircularProgressIndicator());
          },
          error: (error, stackTrace) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Không thể tải hồ sơ.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        ref.invalidate(currentProfileProvider);
                      },
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (profile) {
            final email =
                ref.read(authRepositoryProvider).currentUser?.email ?? '';

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.account_circle, size: 96),

                  const SizedBox(height: 12),

                  Text(
                    profile.displayName ?? 'Người dùng PhuotThu',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                  const SizedBox(height: 32),

                  // =================================================
                  // VEHICLES
                  // =================================================
                  ListTile(
                    leading: const Icon(Icons.directions_car_outlined),
                    title: const Text('Phương tiện của tôi'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push('/profile/vehicles');
                    },
                  ),

                  // =================================================
                  // EDIT PROFILE
                  // =================================================
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Chỉnh sửa hồ sơ'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push('/profile/edit');
                    },
                  ),

                  const Spacer(),

                  // =================================================
                  // LOGOUT
                  // =================================================
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(authRepositoryProvider).signOut();

                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
