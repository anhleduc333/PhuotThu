import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/vehicle_providers.dart';
import '../../data/vehicle_repository.dart';

class VehicleFormPage extends ConsumerStatefulWidget {
  const VehicleFormPage({this.vehicleId, super.key});

  final String? vehicleId;

  bool get isEditing => vehicleId != null;

  @override
  ConsumerState<VehicleFormPage> createState() => _VehicleFormPageState();
}

class _VehicleFormPageState extends ConsumerState<VehicleFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _plateNumberController = TextEditingController();

  final _fuelTankController = TextEditingController();

  final _consumptionController = TextEditingController();

  final _batteryCapacityController = TextEditingController();

  String _vehicleType = 'motorcycle';
  String? _fuelType = 'gasoline';

  bool _isDefault = false;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    if (widget.isEditing) {
      _loadVehicle();
    }
  }

  double? _parseNumber(String text) {
    final value = text.trim();

    if (value.isEmpty) {
      return null;
    }

    return double.tryParse(value.replaceAll(',', '.'));
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  Future<void> _loadVehicle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final vehicle = await ref
          .read(vehicleRepositoryProvider)
          .getVehicleById(widget.vehicleId!);

      if (!mounted) {
        return;
      }

      _nameController.text = vehicle.name;

      _brandController.text = vehicle.brand ?? '';

      _modelController.text = vehicle.model ?? '';

      _plateNumberController.text = vehicle.plateNumber ?? '';

      _fuelTankController.text = vehicle.fuelTankCapacityL?.toString() ?? '';

      _consumptionController.text =
          vehicle.consumptionLPer100Km?.toString() ?? '';

      _batteryCapacityController.text =
          vehicle.batteryCapacityKwh?.toString() ?? '';

      _vehicleType = vehicle.vehicleType;

      _fuelType = vehicle.fuelType;

      _isDefault = vehicle.isDefault;
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải thông tin phương tiện.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(vehicleRepositoryProvider);

      if (widget.isEditing) {
        await repository.updateVehicle(
          vehicleId: widget.vehicleId!,
          name: _nameController.text.trim(),
          vehicleType: _vehicleType,
          brand: _emptyToNull(_brandController.text),
          model: _emptyToNull(_modelController.text),
          plateNumber: _emptyToNull(_plateNumberController.text),
          fuelType: _fuelType,
          fuelTankCapacityL: _parseNumber(_fuelTankController.text),
          consumptionLPer100Km: _parseNumber(_consumptionController.text),
          batteryCapacityKwh: _parseNumber(_batteryCapacityController.text),
          isDefault: _isDefault,
        );
      } else {
        await repository.createVehicle(
          name: _nameController.text.trim(),
          vehicleType: _vehicleType,
          brand: _emptyToNull(_brandController.text),
          model: _emptyToNull(_modelController.text),
          plateNumber: _emptyToNull(_plateNumberController.text),
          fuelType: _fuelType,
          fuelTankCapacityL: _parseNumber(_fuelTankController.text),
          consumptionLPer100Km: _parseNumber(_consumptionController.text),
          batteryCapacityKwh: _parseNumber(_batteryCapacityController.text),
          isDefault: _isDefault,
        );
      }

      ref.invalidate(currentVehiclesProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Đã cập nhật phương tiện.'
                : 'Đã thêm phương tiện.',
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu phương tiện: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteVehicle() async {
    if (!widget.isEditing) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa phương tiện?'),
          content: Text(
            'Phương tiện "${_nameController.text}" '
            'sẽ bị xóa khỏi tài khoản.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref
          .read(vehicleRepositoryProvider)
          .deleteVehicle(widget.vehicleId!);

      ref.invalidate(currentVehiclesProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã xóa phương tiện.')));

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xóa phương tiện: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _validateNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final number = _parseNumber(value);

    if (number == null) {
      return 'Giá trị không hợp lệ';
    }

    if (number < 0) {
      return 'Giá trị không được âm';
    }

    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _plateNumberController.dispose();
    _fuelTankController.dispose();
    _consumptionController.dispose();
    _batteryCapacityController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Sửa phương tiện' : 'Thêm phương tiện'),
        actions: [
          if (widget.isEditing)
            IconButton(
              onPressed: _isSaving ? null : _deleteVehicle,
              tooltip: 'Xóa phương tiện',
              icon: const Icon(Icons.delete_outline),
            ),
        ],
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
                          labelText: 'Tên phương tiện *',
                          hintText: 'Ví dụ: Xe Winner của tôi',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 2) {
                            return 'Vui lòng nhập tên phương tiện';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: _vehicleType,
                        decoration: const InputDecoration(
                          labelText: 'Loại phương tiện',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'motorcycle',
                            child: Text('Xe máy'),
                          ),
                          DropdownMenuItem(value: 'car', child: Text('Ô tô')),
                          DropdownMenuItem(value: 'other', child: Text('Khác')),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }

                                setState(() {
                                  _vehicleType = value;
                                });
                              },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _brandController,
                        decoration: const InputDecoration(
                          labelText: 'Hãng xe',
                          hintText: 'Ví dụ: Honda',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _modelController,
                        decoration: const InputDecoration(
                          labelText: 'Dòng xe',
                          hintText: 'Ví dụ: Winner X',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _plateNumberController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Biển số',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String?>(
                        initialValue: _fuelType,
                        decoration: const InputDecoration(
                          labelText: 'Loại năng lượng',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Chưa xác định'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'gasoline',
                            child: Text('Xăng'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'diesel',
                            child: Text('Dầu Diesel'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'electric',
                            child: Text('Điện'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'hybrid',
                            child: Text('Hybrid'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'other',
                            child: Text('Khác'),
                          ),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                setState(() {
                                  _fuelType = value;
                                });
                              },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _fuelTankController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Dung tích bình nhiên liệu (lít)',
                          hintText: 'Ví dụ: 4.5',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateNumber,
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _consumptionController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Mức tiêu hao (lít/100 km)',
                          hintText: 'Ví dụ: 2.0',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateNumber,
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _batteryCapacityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Dung lượng pin (kWh)',
                          hintText: 'Dành cho xe điện/Hybrid',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateNumber,
                      ),

                      const SizedBox(height: 8),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Phương tiện mặc định'),
                        subtitle: const Text(
                          'PhuotThu sẽ ưu tiên phương tiện này '
                          'khi lập hành trình.',
                        ),
                        value: _isDefault,
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                setState(() {
                                  _isDefault = value;
                                });
                              },
                      ),

                      const SizedBox(height: 24),

                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveVehicle,
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
                          widget.isEditing
                              ? 'Lưu thay đổi'
                              : 'Thêm phương tiện',
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
