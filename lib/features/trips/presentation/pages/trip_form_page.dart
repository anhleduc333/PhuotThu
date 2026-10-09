import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../map/domain/place_result.dart';
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
  final _budgetController = TextEditingController();

  String? _vehicleId;

  DateTime? _plannedStartAt;
  DateTime? _plannedEndAt;

  String? _startName;
  String? _startAddress;
  String? _startPlaceId;
  double? _startLatitude;
  double? _startLongitude;
  bool _startPlaceChanged = false;

  String? _destinationName;
  String? _destinationAddress;
  String? _destinationPlaceId;
  double? _destinationLatitude;
  double? _destinationLongitude;
  bool _destinationPlaceChanged = false;

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

      _budgetController.text = trip.budgetTotal == null
          ? ''
          : trip.budgetTotal!.toStringAsFixed(0);

      _vehicleId = trip.vehicleId;

      _plannedStartAt = trip.plannedStartAt?.toLocal();

      _plannedEndAt = trip.plannedEndAt?.toLocal();

      _startName = trip.startName;
      _startAddress = trip.startAddress;
      _startPlaceId = trip.startPlaceId;

      _destinationName = trip.destinationName;

      _destinationAddress = trip.destinationAddress;

      _destinationPlaceId = trip.destinationPlaceId;
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
    final text = _budgetController.text.trim().replaceAll(
      RegExp(r'[\s,.]'),
      '',
    );

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

    return '$day/$month/${value.year} '
        '$hour:$minute';
  }

  Future<DateTime?> _pickDateTime({DateTime? initialValue}) async {
    final now = DateTime.now();

    final initial = initialValue ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 10),
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

  Future<void> _selectStartPlace() async {
    final place = await context.push<PlaceResult>('/place-search');

    if (place == null || !mounted) {
      return;
    }

    setState(() {
      _startName = place.name;
      _startAddress = place.displayName;
      _startPlaceId = place.id;
      _startLatitude = place.latitude;
      _startLongitude = place.longitude;
      _startPlaceChanged = true;
    });
  }

  Future<void> _selectDestinationPlace() async {
    final place = await context.push<PlaceResult>('/place-search');

    if (place == null || !mounted) {
      return;
    }

    setState(() {
      _destinationName = place.name;
      _destinationAddress = place.displayName;
      _destinationPlaceId = place.id;
      _destinationLatitude = place.latitude;
      _destinationLongitude = place.longitude;
      _destinationPlaceChanged = true;
    });
  }

  void _clearStartPlace() {
    setState(() {
      _startName = null;
      _startAddress = null;
      _startPlaceId = null;
      _startLatitude = null;
      _startLongitude = null;
      _startPlaceChanged = true;
    });
  }

  void _clearDestinationPlace() {
    setState(() {
      _destinationName = null;
      _destinationAddress = null;
      _destinationPlaceId = null;
      _destinationLatitude = null;
      _destinationLongitude = null;
      _destinationPlaceChanged = true;
    });
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
            'Thời gian kết thúc không được '
            'trước thời gian bắt đầu.',
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
          budgetTotal: _parseBudget(),

          updateStartPlace: _startPlaceChanged,
          startName: _startName,
          startAddress: _startAddress,
          startPlaceId: _startPlaceId,
          startLatitude: _startLatitude,
          startLongitude: _startLongitude,

          updateDestinationPlace: _destinationPlaceChanged,
          destinationName: _destinationName,
          destinationAddress: _destinationAddress,
          destinationPlaceId: _destinationPlaceId,
          destinationLatitude: _destinationLatitude,
          destinationLongitude: _destinationLongitude,
        );

        ref.invalidate(tripByIdProvider(widget.tripId!));
      } else {
        await repository.createTrip(
          name: _nameController.text.trim(),
          description: _emptyToNull(_descriptionController.text),
          vehicleId: _vehicleId,
          plannedStartAt: _plannedStartAt,
          plannedEndAt: _plannedEndAt,

          startName: _startName,
          startAddress: _startAddress,
          startPlaceId: _startPlaceId,
          startLatitude: _startLatitude,
          startLongitude: _startLongitude,

          destinationName: _destinationName,
          destinationAddress: _destinationAddress,
          destinationPlaceId: _destinationPlaceId,
          destinationLatitude: _destinationLatitude,
          destinationLongitude: _destinationLongitude,

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

      context.pop();
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

  Widget _buildPlaceSelector({
    required String label,
    required IconData icon,
    required String? name,
    required String? address,
    required String? placeId,
    required double? latitude,
    required double? longitude,
    required VoidCallback onSelect,
    required VoidCallback onClear,
  }) {
    final hasPlace = name != null && name.trim().isNotEmpty;

    final hasRealLocation = placeId != null && placeId.trim().isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (!hasPlace)
              const Text('Chưa chọn địa điểm')
            else ...[
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),

              if (address != null && address.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(address),
              ],

              const SizedBox(height: 8),

              if (hasRealLocation)
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18),
                    const SizedBox(width: 6),
                    const Expanded(child: Text('Đã xác định trên bản đồ')),
                  ],
                )
              else
                const Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, size: 18),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Địa điểm cũ chưa có tọa độ. '
                        'Hãy chọn lại trên bản đồ.',
                      ),
                    ),
                  ],
                ),

              if (latitude != null && longitude != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${latitude.toStringAsFixed(6)}, '
                  '${longitude.toStringAsFixed(6)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : onSelect,
                    icon: const Icon(Icons.search),
                    label: Text(hasPlace ? 'Chọn lại' : 'Chọn địa điểm'),
                  ),
                ),

                if (hasPlace) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSaving ? null : onClear,
                    tooltip: 'Xóa địa điểm',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
                padding: const EdgeInsets.all(16),
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
                            return 'Vui lòng nhập '
                                'tên chuyến đi';
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
                        error: (error, stackTrace) => const Text(
                          'Không thể tải '
                          'phương tiện.',
                        ),
                        data: (vehicles) {
                          return DropdownButtonFormField<String?>(
                            key: ValueKey(_vehicleId),
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

                      _buildPlaceSelector(
                        label: 'Điểm bắt đầu',
                        icon: Icons.trip_origin,
                        name: _startName,
                        address: _startAddress,
                        placeId: _startPlaceId,
                        latitude: _startLatitude,
                        longitude: _startLongitude,
                        onSelect: _selectStartPlace,
                        onClear: _clearStartPlace,
                      ),

                      const SizedBox(height: 16),

                      _buildPlaceSelector(
                        label: 'Điểm đến',
                        icon: Icons.location_on_outlined,
                        name: _destinationName,
                        address: _destinationAddress,
                        placeId: _destinationPlaceId,
                        latitude: _destinationLatitude,
                        longitude: _destinationLongitude,
                        onSelect: _selectDestinationPlace,
                        onClear: _clearDestinationPlace,
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
                        title: const Text(
                          'Thời gian dự kiến '
                          'kết thúc',
                        ),
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
                        keyboardType: TextInputType.number,
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
                            return 'Ngân sách '
                                'không hợp lệ';
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
