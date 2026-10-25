import 'package:flutter/material.dart';

import '../../domain/trip_readiness.dart';
import '../../domain/trip_readiness_composer.dart';

typedef TripReadinessChanged = void Function(
  TripReadinessItemType type,
  bool? value,
);

class TripReadinessPanel extends StatelessWidget {
  const TripReadinessPanel({
    required this.composition,
    required this.confirmationValues,
    required this.onChanged,
    required this.vehicleAvailable,
    required this.routeAvailable,
    this.isSaving = false,
    this.errorMessage,
    super.key,
  });

  final TripReadinessComposition composition;
  final Map<TripReadinessItemType, bool?> confirmationValues;
  final TripReadinessChanged onChanged;
  final bool vehicleAvailable;
  final bool routeAvailable;
  final bool isSaving;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final assessment = composition.scoring.assessment;
    final levelColor = _levelColor(assessment.level);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                assessment.isReady
                    ? Icons.verified_outlined
                    : Icons.fact_check_outlined,
                color: levelColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sẵn sàng trước chuyến đi',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '${assessment.scorePercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: levelColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: assessment.score,
            minHeight: 7,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(_levelIcon(assessment.level), size: 18, color: levelColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  assessment.level.label,
                  style: TextStyle(
                    color: levelColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isSaving)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...assessment.categorySummaries.map(
            (summary) => _CategorySummaryRow(summary: summary),
          ),
          if (composition.vehicle.hasProfileIssues) ...[
            const SizedBox(height: 8),
            ...composition.vehicle.profileIssues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        issue.message,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
          const Divider(height: 24),
          Text(
            'Checklist trước khi khởi hành',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Chạm vào ô kiểm để chuyển: Chưa kiểm tra → Sẵn sàng → '
            'Cần xử lý → Chưa kiểm tra.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          ...TripReadinessCategory.values.map(
            (category) => _buildCategory(context, category),
          ),
          const SizedBox(height: 8),
          Text(
            'Dữ liệu offline và phân tích nguy cơ kết nối được lấy tự động. '
            'Các mục còn lại là xác nhận chuẩn bị của người dùng.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(BuildContext context, TripReadinessCategory category) {
    final items = composition.scoring.assessment.itemsForCategory(category);

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category.label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          ...items.map((item) => _buildItem(context, item)),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, TripReadinessItem item) {
    final editable = _isEditable(item.type);
    final enabled = editable && !isSaving && _isContextAvailable(item.type);

    final statusColor = _itemStatusColor(context, item.status);
    final value = confirmationValues[item.type];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (editable)
            Checkbox(
              value: value,
              tristate: true,
              onChanged: enabled
                  ? (_) => onChanged(item.type, _nextValue(value))
                  : null,
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                _itemStatusIcon(item.status),
                size: 20,
                color: statusColor,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayTitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 1),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    if (item.isRequired)
                      Text(
                        'Bắt buộc',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      item.status.label,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (editable && !enabled)
                      Text(
                        _disabledReason(item.type),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isEditable(TripReadinessItemType type) {
    return type != TripReadinessItemType.offlinePackage &&
        type != TripReadinessItemType.connectivityReviewed;
  }

  bool _isContextAvailable(TripReadinessItemType type) {
    switch (type.category) {
      case TripReadinessCategory.vehicle:
        return vehicleAvailable;
      case TripReadinessCategory.route:
        if (type == TripReadinessItemType.routeReviewed) {
          return routeAvailable;
        }
        return true;
      case TripReadinessCategory.offline:
      case TripReadinessCategory.personal:
      case TripReadinessCategory.emergency:
        return true;
    }
  }

  String _disabledReason(TripReadinessItemType type) {
    if (type.category == TripReadinessCategory.vehicle && !vehicleAvailable) {
      return 'Chọn phương tiện trước';
    }

    if (type == TripReadinessItemType.routeReviewed && !routeAvailable) {
      return 'Chưa có tuyến';
    }

    return 'Không thể chỉnh sửa';
  }

  bool? _nextValue(bool? value) {
    if (value == null) {
      return true;
    }

    if (value) {
      return false;
    }

    return null;
  }

  Color _levelColor(TripReadinessLevel level) {
    switch (level) {
      case TripReadinessLevel.unknown:
        return Colors.blueGrey;
      case TripReadinessLevel.notReady:
        return Colors.red.shade700;
      case TripReadinessLevel.needsAttention:
        return Colors.orange.shade800;
      case TripReadinessLevel.ready:
        return Colors.green.shade700;
    }
  }

  IconData _levelIcon(TripReadinessLevel level) {
    switch (level) {
      case TripReadinessLevel.unknown:
        return Icons.help_outline;
      case TripReadinessLevel.notReady:
        return Icons.cancel_outlined;
      case TripReadinessLevel.needsAttention:
        return Icons.warning_amber_outlined;
      case TripReadinessLevel.ready:
        return Icons.check_circle_outline;
    }
  }

  IconData _itemStatusIcon(TripReadinessItemStatus status) {
    switch (status) {
      case TripReadinessItemStatus.unknown:
        return Icons.help_outline;
      case TripReadinessItemStatus.missing:
        return Icons.cancel_outlined;
      case TripReadinessItemStatus.needsAttention:
        return Icons.warning_amber_outlined;
      case TripReadinessItemStatus.ready:
        return Icons.check_circle_outline;
      case TripReadinessItemStatus.notApplicable:
        return Icons.remove_circle_outline;
    }
  }

  Color _itemStatusColor(BuildContext context, TripReadinessItemStatus status) {
    switch (status) {
      case TripReadinessItemStatus.unknown:
        return Theme.of(context).colorScheme.onSurfaceVariant;
      case TripReadinessItemStatus.missing:
        return Theme.of(context).colorScheme.error;
      case TripReadinessItemStatus.needsAttention:
        return Colors.orange.shade800;
      case TripReadinessItemStatus.ready:
        return Colors.green.shade700;
      case TripReadinessItemStatus.notApplicable:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }
}

class _CategorySummaryRow extends StatelessWidget {
  const _CategorySummaryRow({required this.summary});

  final TripReadinessCategorySummary summary;

  @override
  Widget build(BuildContext context) {
    final color = _color(summary.level);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(_icon(summary.level), size: 17, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              summary.category.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            '${summary.scorePercent.toStringAsFixed(0)}%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _color(TripReadinessLevel level) {
    switch (level) {
      case TripReadinessLevel.unknown:
        return Colors.blueGrey;
      case TripReadinessLevel.notReady:
        return Colors.red.shade700;
      case TripReadinessLevel.needsAttention:
        return Colors.orange.shade800;
      case TripReadinessLevel.ready:
        return Colors.green.shade700;
    }
  }

  IconData _icon(TripReadinessLevel level) {
    switch (level) {
      case TripReadinessLevel.unknown:
        return Icons.help_outline;
      case TripReadinessLevel.notReady:
        return Icons.cancel_outlined;
      case TripReadinessLevel.needsAttention:
        return Icons.warning_amber_outlined;
      case TripReadinessLevel.ready:
        return Icons.check_circle_outline;
    }
  }
}
