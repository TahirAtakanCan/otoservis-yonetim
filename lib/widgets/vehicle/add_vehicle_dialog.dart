import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:otoservis_app/models/vehicle.dart';
import 'package:otoservis_app/providers/vehicle_provider.dart';
import 'package:otoservis_app/utils/formatters.dart';

Future<Vehicle?> showAddVehicleDialog(
  BuildContext context, {
  String? initialPlate,
}) async {
  final ownerNameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final brandCtrl = TextEditingController();
  final modelCtrl = TextEditingController();
  final yearCtrl = TextEditingController();
  final kmCtrl = TextEditingController();
  final plateCtrl = TextEditingController(text: initialPlate?.trim() ?? '');
  final issuesCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  void onPlateChanged(String value) {
    final upper = value.toUpperCase();
    if (value != upper) {
      plateCtrl.value = TextEditingValue(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length),
      );
    }
  }

  try {
    return await showDialog<Vehicle>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        var saving = false;
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              title: const Text('Yeni araç kaydı'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: ownerNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Araç sahibi adı',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Zorunlu'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          TurkishMobilePhoneTextInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Telefon',
                          border: OutlineInputBorder(),
                        ),
                        validator: AppFormatters.validateVehiclePhone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: brandCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Marka',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Zorunlu'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: modelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Zorunlu'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: yearCtrl,
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: kmCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'KM',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Zorunlu';
                          final km = int.tryParse(v.trim());
                          if (km == null || km < 0) {
                            return 'Geçerli KM girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: plateCtrl,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9A-Za-z\s]'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Plaka',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: onPlateChanged,
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Zorunlu'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: issuesCtrl,
                        maxLines: 4,
                        style: const TextStyle(
                          height: 1.35,
                        ),
                        decoration: const InputDecoration(
                          labelText:
                              'Araç sorunu / arıza notu (isteğe bağlı)',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                          hintText: 'Her satıra bir not/arıza yazın.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed:
                      saving
                          ? null
                          : () async {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }

                            setLocalState(() => saving = true);
                            try {
                              final vp = context.read<VehicleProvider>();
                              final normalizedPlate = vp.normalizePlate(
                                plateCtrl.text,
                              );
                              if (normalizedPlate.isEmpty) {
                                throw ArgumentError('Geçerli plaka girin.');
                              }

                              final issues = issuesCtrl.text
                                  .split('\n')
                                  .map((s) => s.trim())
                                  .where((s) => s.isNotEmpty)
                                  .map((text) => {
                                    'text': text,
                                    'addedAt': DateTime.now(),
                                  })
                                  .toList();

                              final vehicle = Vehicle(
                                plate: normalizedPlate,
                                ownerName: ownerNameCtrl.text.trim(),
                                ownerPhone:
                                    AppFormatters.normalizePhoneDigits(
                                  phoneCtrl.text,
                                ),
                                brand: brandCtrl.text.trim(),
                                model: modelCtrl.text.trim(),
                                year: int.parse(yearCtrl.text.trim()),
                                currentKm: int.parse(kmCtrl.text.trim()),
                                createdAt: DateTime.now(),
                                issueNotes: issues,
                              );

                              await vp.saveVehicle(vehicle);
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop(vehicle);
                            } catch (e) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Kayıt sırasında hata: $e'),
                                ),
                              );
                              setLocalState(() => saving = false);
                            }
                          },
                  child:
                      saving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    ownerNameCtrl.dispose();
    phoneCtrl.dispose();
    brandCtrl.dispose();
    modelCtrl.dispose();
    yearCtrl.dispose();
    kmCtrl.dispose();
    plateCtrl.dispose();
    issuesCtrl.dispose();
  }
}
