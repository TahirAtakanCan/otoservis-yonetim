import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:otoservis_app/models/vehicle.dart';
import 'package:otoservis_app/providers/vehicle_provider.dart';
import 'package:otoservis_app/utils/constants.dart';
import 'package:otoservis_app/utils/formatters.dart';
import 'package:otoservis_app/widgets/common/app_error_banner.dart';
import 'package:otoservis_app/widgets/common/app_sidebar.dart';

class VehicleAddScreen extends StatefulWidget {
  const VehicleAddScreen({super.key, this.initialPlate});

  final String? initialPlate;

  @override
  State<VehicleAddScreen> createState() => _VehicleAddScreenState();
}

class _VehicleAddScreenState extends State<VehicleAddScreen> {
  final _formKey = GlobalKey<FormState>();

  final _ownerNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _plateCtrl.text = (widget.initialPlate ?? '').trim().toUpperCase();
  }

  @override
  void dispose() {
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  void _onPlateChanged(String value) {
    final upper = value.toUpperCase();
    if (value == upper) return;
    _plateCtrl.value = TextEditingValue(
      text: upper,
      selection: TextSelection.collapsed(offset: upper.length),
    );
  }

  Future<void> _save({required bool startServiceAfterSave}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final vp = context.read<VehicleProvider>();
      final normalizedPlate = vp.normalizePlate(_plateCtrl.text);
      if (normalizedPlate.isEmpty) {
        throw ArgumentError('Geçerli plaka girin.');
      }

      final vehicle = Vehicle(
        plate: normalizedPlate,
        ownerName: _ownerNameCtrl.text.trim(),
        ownerPhone: AppFormatters.normalizePhoneDigits(_phoneCtrl.text),
        brand: _brandCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        year: int.parse(_yearCtrl.text.trim()),
        createdAt: DateTime.now(),
      );

      await vp.saveVehicle(vehicle);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${vehicle.plate} plakalı araç kaydedildi.')),
      );

      if (startServiceAfterSave) {
        context.go(
          '/service/new?plate=${Uri.encodeQueryComponent(normalizedPlate)}',
        );
      } else {
        context.go('/vehicles');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Araç kaydedilemedi: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      validator: validator,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
    );
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
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 24, 26, 30),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => context.go('/vehicles'),
                                icon: const Icon(Icons.arrow_back),
                                tooltip: 'Araç listesine dön',
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Yeni Araç Ekle',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF121212), Color(0xFF6B5A00)],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x26000000),
                                  blurRadius: 24,
                                  offset: Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                20,
                                22,
                                20,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.directions_car_filled_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Araç Kaydı Oluştur',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Önce aracı kaydedin, ardından aynı ekrandan servisi hemen başlatın.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            AppErrorBanner(message: _error!),
                          ],
                          const SizedBox(height: 18),
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                22,
                                22,
                                20,
                              ),
                              child: Form(
                                key: _formKey,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isWide = constraints.maxWidth > 760;
                                    final fieldWidth =
                                        isWide
                                            ? (constraints.maxWidth - 16) / 2
                                            : constraints.maxWidth;

                                    return Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      children: [
                                        SizedBox(
                                          width: fieldWidth,
                                          child: _buildTextField(
                                            controller: _ownerNameCtrl,
                                            label: 'Araç sahibi adı',
                                            validator: (v) {
                                              if (v == null ||
                                                  v.trim().isEmpty) {
                                                return 'Zorunlu';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        SizedBox(
                                          width: fieldWidth,
                                          child: _buildTextField(
                                            controller: _phoneCtrl,
                                            label: 'Telefon',
                                            keyboardType: TextInputType.phone,
                                            inputFormatters: [
                                              TurkishMobilePhoneTextInputFormatter(),
                                            ],
                                            validator: AppFormatters.validateVehiclePhone,
                                          ),
                                        ),
                                        SizedBox(
                                          width: fieldWidth,
                                          child: _buildTextField(
                                            controller: _brandCtrl,
                                            label: 'Marka',
                                            validator: (v) {
                                              if (v == null ||
                                                  v.trim().isEmpty) {
                                                return 'Zorunlu';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        SizedBox(
                                          width: fieldWidth,
                                          child: _buildTextField(
                                            controller: _modelCtrl,
                                            label: 'Model',
                                            validator: (v) {
                                              if (v == null ||
                                                  v.trim().isEmpty) {
                                                return 'Zorunlu';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        SizedBox(
                                          width: fieldWidth,
                                          child: _buildTextField(
                                            controller: _yearCtrl,
                                            label: 'Yıl',
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                4,
                                              ),
                                            ],
                                            validator: (v) {
                                              if (v == null ||
                                                  v.trim().isEmpty) {
                                                return 'Zorunlu';
                                              }
                                              final y = int.tryParse(v.trim());
                                              if (y == null ||
                                                  y < 1950 ||
                                                  y > 2100) {
                                                return 'Geçerli yıl girin';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        SizedBox(
                                          width: fieldWidth,
                                          child: _buildTextField(
                                            controller: _plateCtrl,
                                            label: 'Plaka',
                                            onChanged: _onPlateChanged,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                RegExp(r'[0-9A-Za-z\s]'),
                                              ),
                                            ],
                                            validator: (v) {
                                              if (v == null ||
                                                  v.trim().isEmpty) {
                                                return 'Zorunlu';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.end,
                            children: [
                              TextButton(
                                onPressed:
                                    _saving
                                        ? null
                                        : () => context.go('/vehicles'),
                                child: const Text('Vazgeç'),
                              ),
                              OutlinedButton(
                                onPressed:
                                    _saving
                                        ? null
                                        : () =>
                                            _save(startServiceAfterSave: false),
                                child:
                                    _saving
                                        ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Text('Sadece Kaydet'),
                              ),
                              FilledButton.icon(
                                onPressed:
                                    _saving
                                        ? null
                                        : () =>
                                            _save(startServiceAfterSave: true),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Kaydet ve Servisi Başlat'),
                              ),
                            ],
                          ),
                        ],
                      ),
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
