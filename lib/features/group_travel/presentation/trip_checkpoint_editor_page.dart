import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../domain/trip_checkpoint.dart';
import '../domain/trip_checkpoint_inputs.dart';
import 'trip_checkpoint_map_picker_page.dart';

/// Values selected explicitly by the traveler. No automatic route modification.
class TripCheckpointFormData {
  const TripCheckpointFormData({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    required this.sortOrder,
    required this.isRequired,
    required this.autoArrivalEnabled,
    this.note,
    this.plannedAt,
  });

  final String name;
  final String? note;
  final double latitude;
  final double longitude;
  final int radiusM;
  final int sortOrder;
  final DateTime? plannedAt;
  final bool isRequired;
  final bool autoArrivalEnabled;

  CreateTripCheckpointInput toCreateInput(String tripId) {
    return CreateTripCheckpointInput(
      tripId: tripId,
      name: name,
      note: note,
      latitude: latitude,
      longitude: longitude,
      radiusM: radiusM,
      sortOrder: sortOrder,
      plannedAt: plannedAt,
      isRequired: isRequired,
      autoArrivalEnabled: autoArrivalEnabled,
    );
  }

  UpdateTripCheckpointInput toUpdateInput() {
    return UpdateTripCheckpointInput(
      name: name,
      note: note,
      clearNote: note == null,
      latitude: latitude,
      longitude: longitude,
      radiusM: radiusM,
      sortOrder: sortOrder,
      plannedAt: plannedAt,
      clearPlannedAt: plannedAt == null,
      isRequired: isRequired,
      autoArrivalEnabled: autoArrivalEnabled,
    );
  }
}

class TripCheckpointEditorPage extends StatefulWidget {
  const TripCheckpointEditorPage({
    super.key,
    this.initial,
    this.suggestedSortOrder = 0,
  });

  final TripCheckpoint? initial;
  final int suggestedSortOrder;

  @override
  State<TripCheckpointEditorPage> createState() =>
      _TripCheckpointEditorPageState();
}

class _TripCheckpointEditorPageState extends State<TripCheckpointEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _radiusController;
  late final TextEditingController _sortController;
  DateTime? _plannedAt;
  late bool _isRequired;
  late bool _autoArrivalEnabled;

  @override
  void initState() {
    super.initState();
    final checkpoint = widget.initial;
    _nameController = TextEditingController(text: checkpoint?.name ?? '');
    _noteController = TextEditingController(text: checkpoint?.note ?? '');
    _latitudeController = TextEditingController(
      text: checkpoint?.latitude.toString() ?? '',
    );
    _longitudeController = TextEditingController(
      text: checkpoint?.longitude.toString() ?? '',
    );
    _radiusController = TextEditingController(
      text: (checkpoint?.radiusM ?? 100).toString(),
    );
    _sortController = TextEditingController(
      text: (checkpoint?.sortOrder ?? widget.suggestedSortOrder).toString(),
    );
    _plannedAt = checkpoint?.plannedAt?.toLocal();
    _isRequired = checkpoint?.isRequired ?? true;
    _autoArrivalEnabled = checkpoint?.autoArrivalEnabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    _sortController.dispose();
    super.dispose();
  }

  double? _parsedCoordinate(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  String? _validateCoordinate(String? value, {required bool latitude}) {
    final parsed = _parsedCoordinate(value ?? '');
    if (parsed == null || !parsed.isFinite) {
      return 'Nhập tọa độ hợp lệ.';
    }
    final limit = latitude ? 90.0 : 180.0;
    if (parsed < -limit || parsed > limit) {
      return 'Tọa độ phải từ -$limit đến $limit.';
    }
    return null;
  }

  String? _validateInteger(String? value, {required bool radius}) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null) {
      return 'Nhập số nguyên hợp lệ.';
    }
    if (radius && (parsed < 10 || parsed > 5000)) {
      return 'Bán kính phải từ 10 đến 5000 m.';
    }
    if (!radius && parsed < 0) {
      return 'Thứ tự không được âm.';
    }
    return null;
  }

  Future<void> _pickOnMap() async {
    final latitude = _parsedCoordinate(_latitudeController.text);
    final longitude = _parsedCoordinate(_longitudeController.text);
    final seed =
        latitude != null &&
            longitude != null &&
            latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180
        ? LatLng(latitude, longitude)
        : null;
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => TripCheckpointMapPickerPage(initialPoint: seed),
      ),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _latitudeController.text = picked.latitude.toStringAsFixed(6);
      _longitudeController.text = picked.longitude.toStringAsFixed(6);
    });
    _formKey.currentState?.validate();
  }

  Future<void> _pickPlannedAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _plannedAt ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || date == null) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_plannedAt ?? now),
    );
    if (!mounted || time == null) {
      return;
    }
    setState(() {
      _plannedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _plannedAtLabel() {
    final value = _plannedAt;
    if (value == null) {
      return 'Chưa đặt thời gian hẹn';
    }
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)} '
        '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final note = _noteController.text.trim();
    final result = TripCheckpointFormData(
      name: _nameController.text.trim(),
      note: note.isEmpty ? null : note,
      latitude: _parsedCoordinate(_latitudeController.text)!,
      longitude: _parsedCoordinate(_longitudeController.text)!,
      radiusM: int.parse(_radiusController.text.trim()),
      sortOrder: int.parse(_sortController.text.trim()),
      plannedAt: _plannedAt,
      isRequired: _isRequired,
      autoArrivalEnabled: _autoArrivalEnabled,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Sửa điểm hẹn' : 'Thêm điểm hẹn')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          // All form fields stay mounted during scroll so validation is
          // complete even when the save button is below the viewport.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Tên điểm hẹn *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Vui lòng nhập tên điểm hẹn.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú (tùy chọn)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: _pickOnMap,
                  icon: const Icon(Icons.place_outlined),
                  label: const Text('Chọn vị trí trên bản đồ'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitudeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Vĩ độ *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            _validateCoordinate(value, latitude: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _longitudeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Kinh độ *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            _validateCoordinate(value, latitude: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _radiusController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Bán kính (m)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            _validateInteger(value, radius: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _sortController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Thứ tự',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            _validateInteger(value, radius: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(_plannedAtLabel()),
                  subtitle: const Text('Thời gian dự kiến (không bắt buộc)'),
                  onTap: _pickPlannedAt,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_plannedAt != null)
                        IconButton(
                          tooltip: 'Bỏ thời gian hẹn',
                          onPressed: () => setState(() => _plannedAt = null),
                          icon: const Icon(Icons.clear),
                        ),
                      const Icon(Icons.edit_calendar_outlined),
                    ],
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Điểm hẹn bắt buộc'),
                  value: _isRequired,
                  onChanged: (value) => setState(() => _isRequired = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cho phép xác nhận tự động bằng GPS'),
                  subtitle: const Text(
                    'Mới là cấu hình. GPS tự động sẽ được triển khai ở DEV-09.7D.',
                  ),
                  value: _autoArrivalEnabled,
                  onChanged: (value) =>
                      setState(() => _autoArrivalEnabled = value),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(editing ? 'Lưu thay đổi' : 'Tạo điểm hẹn'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
