import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:otoservis_app/models/inventory_item.dart';
import 'package:otoservis_app/providers/inventory_provider.dart';
import 'package:otoservis_app/utils/constants.dart';
import 'package:otoservis_app/utils/formatters.dart';
import 'package:otoservis_app/widgets/common/app_error_banner.dart';
import 'package:otoservis_app/widgets/common/app_sidebar.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  String? _categoryFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<InventoryItem> _filtered(List<InventoryItem> all) {
    final q = _searchController.text.trim().toLowerCase();
    return all.where((e) {
      if (_categoryFilter != null && e.category != _categoryFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q);
    }).toList();
  }

  Color? _rowColor(InventoryItem i) {
    if (i.quantity == 0) return Colors.red.shade50;
    if (i.minStockAlert > 0 && i.quantity <= i.minStockAlert) {
      return Colors.orange.shade50;
    }
    return null;
  }

  Future<void> _showPartForm({InventoryItem? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final qtyCtrl = TextEditingController(
      text: existing != null ? '${existing.quantity}' : '',
    );
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.unitPrice.toString() : '',
    );
    final minCtrl = TextEditingController(
      text: existing != null ? '${existing.minStockAlert}' : '',
    );
    var category = existing?.category ?? PartCategories.all.first;
    if (existing != null && !PartCategories.all.contains(existing.category)) {
      category = 'Diğer';
    }
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(existing == null ? 'Yeni parça' : 'Parça düzenle'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Parça adı',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                  ),
                  const SizedBox(height: 12),
                  StatefulBuilder(
                    builder: (context, setLocal) {
                      return DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          border: OutlineInputBorder(),
                        ),
                        items: PartCategories.all
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setLocal(() => category = v);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: existing == null
                          ? 'Başlangıç miktarı'
                          : 'Stok miktarı',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Zorunlu';
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 0) return 'Geçerli miktar';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Birim fiyat (₺)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Zorunlu';
                      final p =
                          double.tryParse(v.trim().replaceAll(',', '.')) ?? -1;
                      if (p < 0) return 'Geçerli fiyat';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: minCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Minimum stok uyarı miktarı',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Zorunlu';
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 0) return 'Geçerli değer';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (ok != true || !mounted) {
      nameCtrl.dispose();
      qtyCtrl.dispose();
      priceCtrl.dispose();
      minCtrl.dispose();
      return;
    }

    final inv = context.read<InventoryProvider>();
    final qty = int.parse(qtyCtrl.text.trim());
    final price =
        double.parse(priceCtrl.text.trim().replaceAll(',', '.'));
    final minS = int.parse(minCtrl.text.trim());

    try {
      if (existing == null) {
        await inv.createItem(
          name: nameCtrl.text,
          category: category.trim(),
          quantity: qty,
          unitPrice: price,
          minStockAlert: minS,
        );
      } else {
        await inv.updateItem(
          existing.copyWith(
            name: nameCtrl.text.trim(),
            category: category,
            quantity: qty,
            unitPrice: price,
            minStockAlert: minS,
            updatedAt: DateTime.now(),
          ),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaydedildi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      nameCtrl.dispose();
      qtyCtrl.dispose();
      priceCtrl.dispose();
      minCtrl.dispose();
    }
  }

  Future<void> _confirmDelete(InventoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Parçayı sil'),
        content: Text('"${item.name}" silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await context.read<InventoryProvider>().deleteItem(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silindi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _showStockEntry() async {
    final inv = context.read<InventoryProvider>();
    final items = inv.allItems;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce parça ekleyin.')),
      );
      return;
    }

    var selected = items.first;
    final qtyCtrl = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Stok girişi'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatefulBuilder(
                  builder: (context, setLocal) {
                    return DropdownButtonFormField<InventoryItem>(
                      value: selected,
                      decoration: const InputDecoration(
                        labelText: 'Parça',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: items
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                '${e.name} (stok: ${e.quantity})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setLocal(() => selected = v);
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Eklenecek miktar',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Zorunlu';
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 1) return 'En az 1';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    final addQty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
    qtyCtrl.dispose();

    if (ok != true || !mounted) return;

    try {
      await inv.addStockTransaction(
        itemId: selected.id,
        addQuantity: addQty,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stok güncellendi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    final rows = _filtered(inv.allItems);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSidebar(),
          Expanded(
            child: ColoredBox(
              color: AppColors.surfaceMuted,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 280,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Parça adına göre ara',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: const Icon(Icons.search),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String?>(
                            value: _categoryFilter,
                            decoration: InputDecoration(
                              labelText: 'Kategori',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Tümü'),
                              ),
                              ...PartCategories.all.map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _categoryFilter = v),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _showPartForm(),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Yeni parça ekle'),
                        ),
                        OutlinedButton.icon(
                          onPressed: inv.inventoryLoading ? null : _showStockEntry,
                          icon: const Icon(Icons.add_box_outlined, size: 20),
                          label: const Text('Stok girişi'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: inv.inventoryLoading
                        ? const Center(child: CircularProgressIndicator())
                        : inv.inventoryError != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: AppErrorBanner(
                                    message:
                                        'Stok listesi yüklenemedi: ${inv.inventoryError}',
                                    onRetry: () =>
                                        inv.retryInventoryStream(),
                                  ),
                                ),
                              )
                            : rows.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Kayıt yok veya filtreye uyan parça yok.',
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                  )
                                : Scrollbar(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SingleChildScrollView(
                                        child: DataTable(
                                          headingRowColor:
                                              WidgetStateProperty.all(
                                            Colors.grey.shade200,
                                          ),
                                          columns: const [
                                            DataColumn(label: Text('Parça adı')),
                                            DataColumn(label: Text('Kategori')),
                                            DataColumn(
                                              label: Text('Stok miktarı'),
                                              numeric: true,
                                            ),
                                            DataColumn(
                                              label: Text('Birim fiyat'),
                                              numeric: true,
                                            ),
                                            DataColumn(
                                              label: Text('Min. stok'),
                                              numeric: true,
                                            ),
                                            DataColumn(label: Text('İşlemler')),
                                          ],
                                          rows: rows.map((item) {
                                            final c = _rowColor(item);
                                            return DataRow(
                                              color: c != null
                                                  ? WidgetStateProperty.all(c)
                                                  : null,
                                              cells: [
                                                DataCell(Text(item.name)),
                                                DataCell(Text(item.category)),
                                                DataCell(
                                                  Text(
                                                    '${item.quantity}',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          item.quantity == 0
                                                              ? FontWeight.bold
                                                              : null,
                                                      color: item.quantity == 0
                                                          ? Colors.red.shade900
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    AppFormatters.formatLira(
                                                      item.unitPrice,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text('${item.minStockAlert}'),
                                                ),
                                                DataCell(
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        tooltip: 'Düzenle',
                                                        icon: const Icon(
                                                          Icons.edit_outlined,
                                                          size: 20,
                                                        ),
                                                        onPressed: () =>
                                                            _showPartForm(
                                                          existing: item,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        tooltip: 'Sil',
                                                        icon: Icon(
                                                          Icons.delete_outline,
                                                          size: 20,
                                                          color: Colors
                                                              .red.shade700,
                                                        ),
                                                        onPressed: () =>
                                                            _confirmDelete(
                                                                item),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
