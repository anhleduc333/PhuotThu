import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/trip_budget_providers.dart';
import '../../data/trip_budget_repository.dart';
import '../../data/trip_providers.dart';
import '../../domain/trip.dart';
import '../../domain/trip_budget_calculator.dart';
import '../../domain/trip_budget_item.dart';

class TripBudgetPage extends ConsumerWidget {
  const TripBudgetPage({required this.tripId, super.key});

  final String tripId;

  static const List<_BudgetCategory> _categories = [
    _BudgetCategory(
      keyName: 'fuel',
      label: 'Nhiên liệu',
      description: 'Tự động tính từ tuyến đường và phương tiện',
      icon: Icons.local_gas_station_outlined,
      isSystem: true,
    ),
    _BudgetCategory(
      keyName: 'food',
      label: 'Ăn uống',
      description: 'Ăn uống trong thời gian thực hiện chuyến đi',
      icon: Icons.restaurant_outlined,
    ),
    _BudgetCategory(
      keyName: 'accommodation',
      label: 'Lưu trú',
      description: 'Khách sạn, nhà nghỉ hoặc nơi lưu trú',
      icon: Icons.hotel_outlined,
    ),
    _BudgetCategory(
      keyName: 'toll_ferry',
      label: 'Cầu đường / phà',
      description: 'Phí đường bộ, trạm thu phí, cầu và phà',
      icon: Icons.toll_outlined,
    ),
    _BudgetCategory(
      keyName: 'contingency',
      label: 'Dự phòng',
      description: 'Khoản dự phòng cho tình huống phát sinh',
      icon: Icons.savings_outlined,
    ),
    _BudgetCategory(
      keyName: 'other',
      label: 'Chi phí khác',
      description: 'Các khoản chi khác của chuyến đi',
      icon: Icons.more_horiz,
    ),
  ];

  String _formatVnd(double? value) {
    if (value == null) {
      return 'Chưa có';
    }

    final negative = value < 0;

    final digits = value.abs().round().toString();

    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }

      buffer.write(digits[i]);
    }

    return '${negative ? '-' : ''}'
        '${buffer.toString()} VND';
  }

  TripBudgetItem? _findItem(List<TripBudgetItem> items, String category) {
    for (final item in items) {
      if (item.category == category) {
        return item;
      }
    }

    return null;
  }

  Future<void> _editManualItem({
    required BuildContext context,
    required WidgetRef ref,
    required _BudgetCategory category,
    required TripBudgetItem? currentItem,
  }) async {
    final result = await showDialog<_BudgetEditResult>(
      context: context,
      builder: (dialogContext) {
        return _BudgetEditDialog(category: category, currentItem: currentItem);
      },
    );

    if (result == null) {
      return;
    }

    final repository = ref.read(tripBudgetRepositoryProvider);

    try {
      if (result.deleteItem) {
        await repository.deleteItem(tripId: tripId, category: category.keyName);
      } else {
        await repository.upsertItem(
          tripId: tripId,
          category: category.keyName,
          amountVnd: result.amountVnd!,
          source: 'manual',
          note: 'Nhập từ Budget Simulator',
          isEnabled: true,
        );
      }

      ref.invalidate(tripBudgetItemsProvider(tripId));

      ref.invalidate(tripByIdProvider(tripId));

      ref.invalidate(currentTripsProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.deleteItem
                ? 'Đã xóa khoản '
                      '${category.label.toLowerCase()}.'
                : 'Đã cập nhật '
                      '${category.label.toLowerCase()}.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật ngân sách: $error')),
      );
    }
  }

  Future<void> _toggleItem({
    required BuildContext context,
    required WidgetRef ref,
    required TripBudgetItem item,
    required bool enabled,
  }) async {
    try {
      await ref
          .read(tripBudgetRepositoryProvider)
          .upsertItem(
            tripId: item.tripId,
            category: item.category,
            amountVnd: item.amountVnd,
            source: item.source,
            note: item.note,
            isEnabled: enabled,
          );

      ref.invalidate(tripBudgetItemsProvider(tripId));

      ref.invalidate(tripByIdProvider(tripId));

      ref.invalidate(currentTripsProvider);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể thay đổi khoản chi: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripByIdProvider(tripId));

    final itemsAsync = ref.watch(tripBudgetItemsProvider(tripId));

    return Scaffold(
      appBar: AppBar(title: const Text('Mô phỏng ngân sách')),
      body: SafeArea(
        child: tripAsync.when(
          loading: () {
            return const Center(child: CircularProgressIndicator());
          },
          error: (error, stackTrace) {
            return _ErrorView(
              message:
                  'Không thể tải thông tin chuyến đi.\n'
                  '$error',
              onRetry: () {
                ref.invalidate(tripByIdProvider(tripId));
              },
            );
          },
          data: (trip) {
            return itemsAsync.when(
              loading: () {
                return const Center(child: CircularProgressIndicator());
              },
              error: (error, stackTrace) {
                return _ErrorView(
                  message:
                      'Không thể tải ngân sách chuyến đi.\n'
                      '$error',
                  onRetry: () {
                    ref.invalidate(tripBudgetItemsProvider(tripId));
                  },
                );
              },
              data: (items) {
                return _buildContent(
                  context: context,
                  ref: ref,
                  trip: trip,
                  items: items,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required WidgetRef ref,
    required Trip trip,
    required List<TripBudgetItem> items,
  }) {
    const calculator = TripBudgetCalculator();

    final summary = calculator.calculate(
      items: items,
      budgetTotal: trip.budgetTotal,
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tripByIdProvider(tripId));

        ref.invalidate(tripBudgetItemsProvider(tripId));

        await ref.read(tripBudgetItemsProvider(tripId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(trip.name, style: Theme.of(context).textTheme.titleLarge),

          const SizedBox(height: 4),

          Text(
            'Lập và theo dõi các khoản chi '
            'dự kiến của chuyến đi.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: 16),

          _BudgetSummaryCard(
            estimatedTotal: summary.estimatedTotal,
            budgetTotal: summary.budgetTotal,
            remainingBudget: summary.remainingBudget,
            usagePercent: summary.usagePercent,
            exceedsBudget: summary.exceedsBudget,
            formatVnd: _formatVnd,
          ),

          const SizedBox(height: 20),

          Text('Các khoản chi', style: Theme.of(context).textTheme.titleMedium),

          const SizedBox(height: 8),

          ..._categories.map((category) {
            final item = _findItem(items, category.keyName);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BudgetItemCard(
                category: category,
                item: item,
                formatVnd: _formatVnd,
                onEdit: category.isSystem
                    ? null
                    : () {
                        _editManualItem(
                          context: context,
                          ref: ref,
                          category: category,
                          currentItem: item,
                        );
                      },
                onEnabledChanged: category.isSystem || item == null
                    ? null
                    : (enabled) {
                        _toggleItem(
                          context: context,
                          ref: ref,
                          item: item,
                          enabled: enabled,
                        );
                      },
              ),
            );
          }),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chi phí nhiên liệu được hệ thống '
                      'tự động tính từ tuyến đường, '
                      'phương tiện và giá nhiên liệu. '
                      'Các khoản còn lại do người dùng '
                      'nhập và có thể bật hoặc tắt khi '
                      'mô phỏng ngân sách.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BudgetEditDialog extends StatefulWidget {
  const _BudgetEditDialog({required this.category, required this.currentItem});

  final _BudgetCategory category;
  final TripBudgetItem? currentItem;

  @override
  State<_BudgetEditDialog> createState() => _BudgetEditDialogState();
}

class _BudgetEditDialogState extends State<_BudgetEditDialog> {
  late final TextEditingController _controller;

  String? _validationMessage;

  @override
  void initState() {
    super.initState();

    final currentAmount = widget.currentItem?.amountVnd;

    _controller = TextEditingController(
      text: currentAmount == null || currentAmount <= 0
          ? ''
          : currentAmount.round().toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  void _save() {
    final raw = _controller.text.trim();

    final amount = double.tryParse(raw);

    if (raw.isEmpty || amount == null || amount < 0) {
      setState(() {
        _validationMessage = 'Vui lòng nhập số tiền hợp lệ.';
      });

      return;
    }

    Navigator.of(context).pop(_BudgetEditResult.save(amount));
  }

  void _delete() {
    Navigator.of(context).pop(const _BudgetEditResult.delete());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category.label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.category.description),

          const SizedBox(height: 16),

          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) {
              _save();
            },
            decoration: InputDecoration(
              labelText: 'Số tiền dự kiến',
              suffixText: 'VND',
              border: const OutlineInputBorder(),
              hintText: 'Ví dụ: 500000',
              errorText: _validationMessage,
            ),
          ),
        ],
      ),
      actions: [
        if (widget.currentItem != null)
          TextButton(onPressed: _delete, child: const Text('Xóa khoản này')),

        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Hủy'),
        ),

        FilledButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }
}

class _BudgetCategory {
  const _BudgetCategory({
    required this.keyName,
    required this.label,
    required this.description,
    required this.icon,
    this.isSystem = false,
  });

  final String keyName;
  final String label;
  final String description;
  final IconData icon;
  final bool isSystem;
}

class _BudgetEditResult {
  const _BudgetEditResult.save(this.amountVnd) : deleteItem = false;

  const _BudgetEditResult.delete() : amountVnd = null, deleteItem = true;

  final double? amountVnd;
  final bool deleteItem;
}

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({
    required this.estimatedTotal,
    required this.budgetTotal,
    required this.remainingBudget,
    required this.usagePercent,
    required this.exceedsBudget,
    required this.formatVnd,
  });

  final double estimatedTotal;
  final double? budgetTotal;
  final double? remainingBudget;
  final double? usagePercent;
  final bool exceedsBudget;

  final String Function(double?) formatVnd;

  @override
  Widget build(BuildContext context) {
    final usage = usagePercent;

    final progress = usage == null
        ? null
        : (usage / 100).clamp(0.0, 1.0).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined),
                const SizedBox(width: 8),
                Text(
                  'Tổng quan ngân sách',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),

            const SizedBox(height: 16),

            _SummaryRow(
              label: 'Tổng chi phí dự kiến',
              value: formatVnd(estimatedTotal),
              strong: true,
            ),

            _SummaryRow(
              label: 'Ngân sách',
              value: budgetTotal == null
                  ? 'Chưa đặt ngân sách'
                  : formatVnd(budgetTotal),
            ),

            if (remainingBudget != null)
              _SummaryRow(
                label: exceedsBudget ? 'Vượt ngân sách' : 'Ngân sách còn lại',
                value: formatVnd(remainingBudget),
                warning: exceedsBudget,
              ),

            if (usage != null) ...[
              const SizedBox(height: 12),

              LinearProgressIndicator(value: progress),

              const SizedBox(height: 8),

              Text(
                exceedsBudget
                    ? 'Đã sử dụng '
                          '${usage.toStringAsFixed(1)}% '
                          'ngân sách — chi phí dự kiến '
                          'đang vượt ngân sách.'
                    : 'Đã sử dụng '
                          '${usage.toStringAsFixed(1)}% '
                          'ngân sách.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: exceedsBudget
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetItemCard extends StatelessWidget {
  const _BudgetItemCard({
    required this.category,
    required this.item,
    required this.formatVnd,
    required this.onEdit,
    required this.onEnabledChanged,
  });

  final _BudgetCategory category;
  final TripBudgetItem? item;

  final String Function(double?) formatVnd;

  final VoidCallback? onEdit;

  final ValueChanged<bool>? onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final hasItem = item != null;

    final enabled = item?.isEnabled ?? false;

    final amount = item?.amountVnd ?? 0;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(child: Icon(category.icon)),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            category.label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),

                        if (category.isSystem) ...[
                          const SizedBox(width: 8),
                          const Chip(
                            label: Text('Tự động'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      hasItem ? formatVnd(amount) : 'Chưa thiết lập',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      category.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),

                    if (hasItem && !enabled) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Không tính vào tổng ngân sách',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              if (category.isSystem)
                const Icon(Icons.lock_outline)
              else if (hasItem)
                Switch(value: enabled, onChanged: onEnabledChanged)
              else
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Thêm khoản chi',
                  icon: const Icon(Icons.add_circle_outline),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.warning = false,
  });

  final String label;
  final String value;

  final bool strong;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final warningColor = warning ? Theme.of(context).colorScheme.error : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),

          const SizedBox(width: 16),

          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: strong || warning ? FontWeight.bold : FontWeight.w600,
              color: warningColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
