import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:otoservis_app/models/vehicle.dart';
import 'package:otoservis_app/providers/vehicle_provider.dart';
import 'package:otoservis_app/utils/constants.dart';
import 'package:otoservis_app/widgets/common/app_error_banner.dart';
import 'package:otoservis_app/widgets/common/app_sidebar.dart';

class VehicleSearchScreen extends StatefulWidget {
  const VehicleSearchScreen({
    super.key,
    this.flow,
  });

  final String? flow;

  @override
  State<VehicleSearchScreen> createState() => _VehicleSearchScreenState();
}

class _VehicleSearchScreenState extends State<VehicleSearchScreen> {
  bool get _serviceFlow => widget.flow == 'service';

  final _plateController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  void _onPlateChanged(String value) {
    final upper = value.toUpperCase();
    if (value != upper) {
      _plateController.value = TextEditingValue(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length),
      );
    }
  }

  Future<void> _onSearch() async {
    final vp = context.read<VehicleProvider>();
    final plate = vp.normalizePlate(_plateController.text);

    if (plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen plaka girin.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vehicle = await vp.fetchVehicleByPlate(plate);
      if (!mounted) return;

      if (vehicle != null) {
        vp.setSelectedVehicle(vehicle);
        if (_serviceFlow) {
          context.go('/service/new?plate=$plate');
        } else {
          context.go('/vehicle/$plate/history');
        }
        return;
      }

      final create = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Araç bulunamadı'),
          content: const Text(
            'Bu araç sistemde yok, yeni kayıt oluşturmak ister misiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hayır'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Evet'),
            ),
          ],
        ),
      );

      if (!mounted || create != true) return;

      await _showNewVehicleDialog(plate);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Plaka sorgulanırken bir hata oluştu: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showNewVehicleDialog(String normalizedPlate) async {
    final ownerNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    try {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Yeni araç kaydı'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Plaka: $normalizedPlate',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: ownerNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Araç sahibi adı',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefon',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: brandCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Marka',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: modelCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
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
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(ctx).pop(true);
                  }
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      );

      if (!mounted || ok != true) return;

      final vehicle = Vehicle(
        plate: normalizedPlate,
        ownerName: ownerNameCtrl.text.trim(),
        ownerPhone: phoneCtrl.text.trim(),
        brand: brandCtrl.text.trim(),
        model: modelCtrl.text.trim(),
        year: int.parse(yearCtrl.text.trim()),
        createdAt: DateTime.now(),
      );

      final vp = context.read<VehicleProvider>();
      await vp.saveVehicle(vehicle);
      if (!mounted) return;
      context.go('/service/new?plate=$normalizedPlate');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt sırasında hata: $e')),
      );
    } finally {
      ownerNameCtrl.dispose();
      phoneCtrl.dispose();
      brandCtrl.dispose();
      modelCtrl.dispose();
      yearCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSidebar(),
          Expanded(
            child: ColoredBox(
              color: AppColors.surfaceMuted,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_error != null) ...[
                          AppErrorBanner(
                            message: _error!,
                            onRetry: _onSearch,
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          _serviceFlow
                              ? 'Servis için araç ara'
                              : 'Plaka ile araç ara',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _serviceFlow
                              ? 'Kayıtlı plakayı bulup doğrudan yeni servis ekranına geçin.'
                              : 'Plaka büyük harfe çevrilir, boşluklar birleştirilir.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),
                        Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            child: TextField(
                              controller: _plateController,
                              autofocus: true,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                              textAlign: TextAlign.center,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9A-Za-z\s]'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                hintText: 'Örn: 34 ABC 123',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                              ),
                              onChanged: _onPlateChanged,
                              onSubmitted: (_) {
                                if (!_loading) _onSearch();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: _loading ? null : _onSearch,
                            child: _loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Devam et',
                                    style: TextStyle(fontSize: 18),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
