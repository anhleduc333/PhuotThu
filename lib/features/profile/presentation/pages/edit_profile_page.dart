import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profile_providers.dart';
import '../../data/profile_repository.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _travelStyleController = TextEditingController();
  final _interestsController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  String _privacyLevel = 'friends';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .getCurrentProfile();

      if (!mounted) {
        return;
      }

      _displayNameController.text = profile.displayName ?? '';

      _bioController.text = profile.bio ?? '';

      _travelStyleController.text = profile.travelStyle ?? '';

      _interestsController.text = profile.interests.join(', ');

      _privacyLevel = profile.privacyLevel;
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Không thể tải hồ sơ.')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final interests = _interestsController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            displayName: _displayNameController.text.trim(),
            bio: _bioController.text.trim().isEmpty
                ? null
                : _bioController.text.trim(),
            travelStyle: _travelStyleController.text.trim().isEmpty
                ? null
                : _travelStyleController.text.trim(),
            interests: interests,
            privacyLevel: _privacyLevel,
          );

      ref.invalidate(currentProfileProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể cập nhật hồ sơ. Vui lòng thử lại.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _travelStyleController.dispose();
    _interestsController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa hồ sơ')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên hiển thị',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 2) {
                            return 'Tên hiển thị phải có ít nhất 2 ký tự';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bioController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Giới thiệu',
                          hintText: 'Một chút về bạn...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _travelStyleController,
                        decoration: const InputDecoration(
                          labelText: 'Phong cách du lịch',
                          hintText:
                              'Ví dụ: khám phá, nhẹ nhàng, phượt đường dài...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _interestsController,
                        decoration: const InputDecoration(
                          labelText: 'Sở thích',
                          hintText: 'Núi, biển, cắm trại, ẩm thực...',
                          helperText: 'Phân cách các sở thích bằng dấu phẩy',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _privacyLevel,
                        decoration: const InputDecoration(
                          labelText: 'Quyền riêng tư',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'private',
                            child: Text('Chỉ mình tôi'),
                          ),
                          DropdownMenuItem(
                            value: 'friends',
                            child: Text('Bạn bè'),
                          ),
                          DropdownMenuItem(
                            value: 'followers',
                            child: Text('Người theo dõi'),
                          ),
                          DropdownMenuItem(
                            value: 'public',
                            child: Text('Công khai'),
                          ),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() {
                                    _privacyLevel = value;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveProfile,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Lưu thay đổi'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
