import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../vehicle/data/vehicle_providers.dart';
import '../../data/trip_providers.dart';
import '../../data/trip_repository.dart';

class TripFormPage extends ConsumerStatefulWidget {
  const TripFormPage({this.tripId, super.key});

  final String? tripId;

  bool get isEditing => tripId != null;

  @override
  ConsumerState<TripFormPage> createState() => _TripFormPageState();
}

class _TripFormPageState extends ConsumerState<TripFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startController = TextEditingController();
  final _destinationController = TextEditingController();
  final _budgetController = TextEditingController();

  String? _vehicleId;

  DateTime? _plannedStartAt;
  DateTime? _plannedEndAt;

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    if (widget.isEditing) {
      _isLoading = true;
      _loadTrip();
    }
  }

  Future<void> _loadTrip() async {
    try {
      final trip = await ref
          .read(tripRepositoryProvider)
          .getTripById(widget.tripId!);

      if (!mounted) {
        return;
      }

      _nameController.text = trip.name;
      _descriptionController.text = trip.description ?? '';
      _startController.text = trip.startName ?? '';
      _destinationController.text = trip.destinationName ?? '';

      _budgetController.text = trip.budgetTotal == null
          ? ''
          : trip.budgetTotal!.toStringAsFixed(0);

      _vehicleId = trip.vehicleId;
      _plannedStartAt = trip.plannedStartAt?.toLocal();
      _plannedEndAt = trip.plannedEndAt?.toLocal();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải thông tin chuyến đi.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  double? _parseBudget() {
    final text = _budgetController.text.trim().replaceAll(',', '');

    if (text.isEmpty) {
      return null;
    }

    return double.tryParse(text);
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Chưa chọn';
    }

    final day = value.day.toString().padLeft(2, '0');

    final month = value.month.toString().padLeft(2, '0');

    final hour = value.hour.toString().padLeft(2, '0');

    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/${value.year} $hour:$minute';
  }

  Future<DateTime?> _pickDateTime({DateTime? initialValue}) async {
    final now = DateTime.now();
    final initial = initialValue ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
    );

    if (date == null || !mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_plannedStartAt != null &&
        _plannedEndAt != null &&
        _plannedEndAt!.isBefore(_plannedStartAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Thời gian kết thúc không được trước thời gian bắt đầu.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(tripRepositoryProvider);

      if (widget.isEditing) {
        await repository.updateTrip(
          tripId: widget.tripId!,
          name: _nameController.text.trim(),
          description: _emptyToNull(_descriptionController.text),
          vehicleId: _vehicleId,
          plannedStartAt: _plannedStartAt,
          plannedEndAt: _plannedEndAt,
          startName: _emptyToNull(_startController.text),
          destinationName: _emptyToNull(_destinationController.text),
          budgetTotal: _parseBudget(),
        );

        ref.invalidate(tripByIdProvider(widget.tripId!));
      } else {
        await repository.createTrip(
          name: _nameController.text.trim(),
          description: _emptyToNull(_descriptionController.text),
          vehicleId: _vehicleId,
          plannedStartAt: _plannedStartAt,
          plannedEndAt: _plannedEndAt,
          startName: _emptyToNull(_startController.text),
          destinationName: _emptyToNull(_destinationController.text),
          budgetTotal: _parseBudget(),
        );
      }

      ref.invalidate(currentTripsProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing ? 'Đã cập nhật chuyến đi.' : 'Đã tạo chuyến đi.',
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu chuyến đi: $error')),
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
    _nameController.dispose();
    _descriptionController.dispose();
    _startController.dispose();
    _destinationController.dispose();
    _budgetController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(currentVehiclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Sửa chuyến đi' : 'Tạo chuyến đi'),
      ),
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
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên chuyến đi *',
                          hintText: 'Ví dụ: Hà Nội - Hà Giang',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 2) {
                            return 'Vui lòng nhập tên chuyến đi';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      vehiclesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) =>
                            const Text('Không thể tải phương tiện.'),
                        data: (vehicles) {
                          return DropdownButtonFormField<String?>(
                            initialValue: _vehicleId,
                            decoration: const InputDecoration(
                              labelText: 'Phương tiện',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Chưa chọn'),
                              ),
                              ...vehicles.map(
                                (vehicle) => DropdownMenuItem<String?>(
                                  value: vehicle.id,
                                  child: Text(vehicle.name),
                                ),
                              ),
                            ],
                            onChanged: _isSaving
                                ? null
                                : (value) {
                                    setState(() {
                                      _vehicleId = value;
                                    });
                                  },
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _startController,
                        decoration: const InputDecoration(
                          labelText: 'Điểm bắt đầu',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.trip_origin),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _destinationController,
                        decoration: const InputDecoration(
                          labelText: 'Điểm đến',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),

                      const SizedBox(height: 16),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Thời gian bắt đầu'),
                        subtitle: Text(_formatDateTime(_plannedStartAt)),
                        trailing: const Icon(Icons.calendar_month_outlined),
                        onTap: () async {
                          final value = await _pickDateTime(
                            initialValue: _plannedStartAt,
                          );

                          if (value != null) {
                            setState(() {
                              _plannedStartAt = value;
                            });
                          }
                        },
                      ),

                      const Divider(),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Thời gian dự kiến kết thúc'),
                        subtitle: Text(_formatDateTime(_plannedEndAt)),
                        trailing: const Icon(Icons.event_available_outlined),
                        onTap: () async {
                          final value = await _pickDateTime(
                            initialValue: _plannedEndAt ?? _plannedStartAt,
                          );

                          if (value != null) {
                            setState(() {
                              _plannedEndAt = value;
                            });
                          }
                        },
                      ),

                      const Divider(),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _budgetController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Ngân sách dự kiến',
                          suffixText: 'VND',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }

                          if (_parseBudget() == null) {
                            return 'Ngân sách không hợp lệ';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveTrip,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          widget.isEditing ? 'Lưu thay đổi' : 'Tạo chuyến đi',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
