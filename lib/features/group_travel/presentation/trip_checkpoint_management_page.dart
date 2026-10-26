import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/group_trip_providers.dart';
import '../data/trip_checkpoint_providers.dart';
import '../domain/group_trip_state.dart';
import '../domain/trip_checkpoint.dart';
import 'trip_checkpoint_editor_page.dart';

class TripCheckpointManagementPage extends ConsumerStatefulWidget {
  const TripCheckpointManagementPage({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<TripCheckpointManagementPage> createState() =>
      _TripCheckpointManagementPageState();
}

class _TripCheckpointManagementPageState
    extends ConsumerState<TripCheckpointManagementPage> {
  bool _busy = false;

  void _refresh() {
    ref.invalidate(tripCheckpointsProvider(widget.tripId));
    ref.invalidate(tripCheckpointArrivalsProvider(widget.tripId));
    ref.invalidate(tripCheckpointProgressProvider(widget.tripId));
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addCheckpoint(List<TripCheckpoint> checkpoints) async {
    final nextOrder = checkpoints.isEmpty
        ? 0
        : checkpoints
                  .map((checkpoint) => checkpoint.sortOrder)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final result = await Navigator.of(context).push<TripCheckpointFormData>(
      MaterialPageRoute(
        builder: (_) => TripCheckpointEditorPage(suggestedSortOrder: nextOrder),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(tripCheckpointRepositoryProvider)
          .createCheckpoint(result.toCreateInput(widget.tripId));
      _refresh();
      _showMessage('Đã tạo điểm hẹn.');
    } catch (error) {
      _showMessage('Không thể tạo điểm hẹn: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _editCheckpoint(TripCheckpoint checkpoint) async {
    final result = await Navigator.of(context).push<TripCheckpointFormData>(
      MaterialPageRoute(
        builder: (_) => TripCheckpointEditorPage(initial: checkpoint),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(tripCheckpointRepositoryProvider)
          .updateCheckpoint(
            checkpointId: checkpoint.id,
            input: result.toUpdateInput(),
          );
      _refresh();
      _showMessage('Đã cập nhật điểm hẹn.');
    } catch (error) {
      _showMessage('Không thể cập nhật điểm hẹn: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteCheckpoint(TripCheckpoint checkpoint) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa điểm hẹn?'),
        content: Text(
          'Xóa "${checkpoint.name}" và toàn bộ kết quả điểm danh '
          'đã ghi nhận tại điểm này? Thao tác không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa điểm hẹn'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      final repository = ref.read(tripCheckpointRepositoryProvider);
      await repository.deleteCheckpoint(checkpoint.id);
      // Supabase RLS may silently affect zero rows on DELETE. Verify the result.
      final remaining = await repository.getCheckpoints(widget.tripId);
      if (remaining.any((item) => item.id == checkpoint.id)) {
        throw StateError('Điểm hẹn vẫn tồn tại. Kiểm tra quyền xóa.');
      }
      _refresh();
      _showMessage('Đã xóa điểm hẹn.');
    } catch (error) {
      _refresh();
      _showMessage('Không thể xóa điểm hẹn: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _displayTime(DateTime? value) {
    if (value == null) {
      return 'Chưa đặt giờ hẹn';
    }
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)} '
        '${two(local.day)}/${two(local.month)}/${local.year}';
  }

  Widget _buildCheckpoints({required bool canManage}) {
    final checkpointsAsync = ref.watch(tripCheckpointsProvider(widget.tripId));
    return checkpointsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Không thể tải danh sách điểm hẹn.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
              const SizedBox(height: 12),
              Text('$error', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
      data: (checkpoints) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tripCheckpointsProvider(widget.tripId));
          await ref.read(tripCheckpointsProvider(widget.tripId).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            if (checkpoints.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.flag_outlined, size: 48),
                    SizedBox(height: 12),
                    Text('Chuyến đi chưa có điểm hẹn.'),
                    SizedBox(height: 6),
                    Text('Trưởng nhóm có thể thêm các điểm dừng do nhóm chọn.'),
                  ],
                ),
              ),
            for (final checkpoint in checkpoints)
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        child: Text('${checkpoint.sortOrder + 1}'),
                      ),
                      title: Text(checkpoint.name),
                      isThreeLine: true,
                      subtitle: Text(
                        '${_displayTime(checkpoint.plannedAt)}\n'
                        '${checkpoint.latitude.toStringAsFixed(5)}, '
                        '${checkpoint.longitude.toStringAsFixed(5)}'
                        ' • Bán kính ${checkpoint.radiusM} m',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: canManage
                          ? PopupMenuButton<String>(
                              enabled: !_busy,
                              tooltip: 'Quản lý điểm hẹn',
                              onSelected: (action) {
                                if (action == 'edit') {
                                  _editCheckpoint(checkpoint);
                                } else if (action == 'delete') {
                                  _deleteCheckpoint(checkpoint);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Sửa điểm hẹn'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Xóa điểm hẹn'),
                                ),
                              ],
                            )
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        [
                          if (checkpoint.note != null &&
                              checkpoint.note!.trim().isNotEmpty)
                            checkpoint.note!,
                          checkpoint.isRequired
                              ? 'Điểm hẹn bắt buộc'
                              : 'Điểm hẹn tùy chọn',
                        ].join(' • '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupTripStateProvider(widget.tripId));
    final canAdd = groupAsync.when(
      data: (group) =>
          group.isGroupEnabled &&
          group.viewerIsActiveMember &&
          group.viewerCanManageMembers,
      loading: () => false,
      error: (error, stackTrace) => false,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Điểm hẹn / Checkpoint'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: SafeArea(
        child: groupAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text('Không thể tải quyền truy cập nhóm: $error')),
          data: (GroupTripState group) {
            if (!group.isGroupEnabled || !group.viewerIsActiveMember) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Chỉ thành viên đang tham gia chuyến đi nhóm mới có thể xem điểm hẹn.',
                  ),
                ),
              );
            }
            final canManage = group.viewerCanManageMembers;
            return Stack(
              children: [
                _buildCheckpoints(canManage: canManage),
                if (_busy)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x33000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: canAdd
          ? Consumer(
              builder: (context, ref, child) {
                final value = ref.watch(tripCheckpointsProvider(widget.tripId));
                return FloatingActionButton.extended(
                  onPressed: _busy || !value.hasValue
                      ? null
                      : () => _addCheckpoint(value.requireValue),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Thêm điểm hẹn'),
                );
              },
            )
          : null,
    );
  }
}
