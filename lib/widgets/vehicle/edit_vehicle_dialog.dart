import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:otoservis_app/models/vehicle.dart';
import 'package:otoservis_app/providers/vehicle_provider.dart';
import 'package:otoservis_app/utils/formatters.dart';

/// `true` döner: kayıt güncellendi veya araç silindi (liste yenilensin).
Future<bool?> showEditVehicleDialog(
  BuildContext context,
  Vehicle vehicle,
) async {
  final ownerNameCtrl = TextEditingController(text: vehicle.ownerName);
  final phoneCtrl = TextEditingController(
    text: AppFormatters.formatTurkishPhoneForDisplay(
      AppFormatters.normalizePhoneDigits(vehicle.ownerPhone),
    ),
  );
  final brandCtrl = TextEditingController(text: vehicle.brand);
  final modelCtrl = TextEditingController(text: vehicle.model);
  final yearCtrl = TextEditingController(text: '${vehicle.year}');
  final formKey = GlobalKey<FormState>();

  try {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _EditVehicleDialogBody(
          formKey: formKey,
          ownerNameCtrl: ownerNameCtrl,
          phoneCtrl: phoneCtrl,
          brandCtrl: brandCtrl,
          modelCtrl: modelCtrl,
          yearCtrl: yearCtrl,
          vehicle: vehicle,
        );
      },
    );
  } finally {
    ownerNameCtrl.dispose();
    phoneCtrl.dispose();
    brandCtrl.dispose();
    modelCtrl.dispose();
    yearCtrl.dispose();
  }
}

class _EditVehicleDialogBody extends StatefulWidget {
  const _EditVehicleDialogBody({
    required this.formKey,
    required this.ownerNameCtrl,
    required this.phoneCtrl,
    required this.brandCtrl,
    required this.modelCtrl,
    required this.yearCtrl,
    required this.vehicle,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController ownerNameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController brandCtrl;
  final TextEditingController modelCtrl;
  final TextEditingController yearCtrl;
  final Vehicle vehicle;

  @override
  State<_EditVehicleDialogBody> createState() => _EditVehicleDialogBodyState();
}

class _EditVehicleDialogBodyState extends State<_EditVehicleDialogBody> {
  bool _saving = false;
  bool _deleting = false;

  bool get _busy => _saving || _deleting;

  Future<void> _confirmDelete() async {
    final v = widget.vehicle;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Aracı sil'),
        content: Text(
          '${v.plate} plakalı araç ve ilgili tüm servis kayıtları kalıcı olarak silinecek. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade800,
            ),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final vp = context.read<VehicleProvider>();
      await vp.deleteVehicleWithServiceRecords(v.plate);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silinemedi: $e')),
      );
      setState(() => _deleting = false);
    }
  }

  Future<void> _onSave() async {
    if (!(widget.formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final vp = context.read<VehicleProvider>();
      await vp.updateVehicleDetails(
        plate: widget.vehicle.plate,
        ownerName: widget.ownerNameCtrl.text,
        ownerPhone: AppFormatters.normalizePhoneDigits(widget.phoneCtrl.text),
        brand: widget.brandCtrl.text,
        model: widget.modelCtrl.text,
        year: int.parse(widget.yearCtrl.text.trim()),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt sırasında hata: $e')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.read<VehicleProvider>();
    return AlertDialog(
      title: const Text('Araç bilgilerini düzenle'),
      content: SingleChildScrollView(
        child: Form(
          key: widget.formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                initialValue: vp.formatPlateForDisplay(widget.vehicle.plate),
                decoration: const InputDecoration(
                  labelText: 'Plaka',
                  border: OutlineInputBorder(),
                  helperText: 'Plaka değiştirilemez',
                ),
                enabled: false,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: widget.ownerNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Araç sahibi adı',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: widget.phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [TurkishMobilePhoneTextInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  border: OutlineInputBorder(),
                ),
                validator: AppFormatters.validateVehiclePhone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: widget.brandCtrl,
                decoration: const InputDecoration(
                  labelText: 'Marka',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: widget.modelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: widget.yearCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(
                  labelText: 'Yıl',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Zorunlu';
                  final y = int.tryParse(v.trim());
                  if (y == null || y < 1950 || y > 2100) {
                    return 'Geçerli yıl girin';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade800),
          onPressed: _busy ? null : _confirmDelete,
          child: _deleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sil'),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _busy ? null : _onSave,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}
