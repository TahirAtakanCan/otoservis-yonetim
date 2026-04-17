import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:otoservis_app/models/service_record.dart';
import 'package:otoservis_app/models/vehicle.dart';
import 'package:otoservis_app/utils/constants.dart';
import 'package:otoservis_app/widgets/pdf/pdf_template.dart';

class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({
    super.key,
    required this.serviceId,
  });

  final String serviceId;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late final Future<_PdfData> _futureData = _loadData();
  Uint8List? _cachedPdf;
  bool _working = false;

  Future<_PdfData> _loadData() async {
    final firestore = FirebaseFirestore.instance;
    final serviceSnap = await firestore
        .collection(FirestoreCollections.serviceRecords)
        .doc(widget.serviceId)
        .get();
    final serviceData = serviceSnap.data();
    if (serviceData == null) {
      throw StateError('Servis kaydi bulunamadi.');
    }

    final service = ServiceRecord.fromMap({
      ...serviceData,
      'id': serviceSnap.id,
    });

    final plate = service.vehiclePlate;
    final vehicleDoc =
        await firestore.collection(FirestoreCollections.vehicles).doc(plate).get();

    Vehicle? vehicle;
    if (vehicleDoc.data() != null) {
      vehicle = Vehicle.fromMap({
        ...vehicleDoc.data()!,
        'plate': vehicleDoc.data()!['plate'] ?? plate,
      });
    } else {
      final q = await firestore
          .collection(FirestoreCollections.vehicles)
          .where('plate', isEqualTo: plate)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final d = q.docs.first;
        vehicle = Vehicle.fromMap({
          ...d.data(),
          'plate': d.data()['plate'] ?? plate,
        });
      }
    }

    if (vehicle == null) {
      throw StateError('Arac kaydi bulunamadi.');
    }

    return _PdfData(service: service, vehicle: vehicle);
  }

  Future<Uint8List> _buildPdf(_PdfData data) async {
    _cachedPdf ??= await PdfTemplate.buildServiceSlip(
      service: data.service,
      vehicle: data.vehicle,
    );
    return _cachedPdf!;
  }

  Future<void> _savePdf(_PdfData data) async {
    setState(() => _working = true);
    try {
      final pdf = await _buildPdf(data);
      await Printing.sharePdf(
        bytes: pdf,
        filename: 'servis_fisi_${data.service.id}.pdf',
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _printPdf(_PdfData data) async {
    setState(() => _working = true);
    try {
      final pdf = await _buildPdf(data);
      await Printing.layoutPdf(onLayout: (_) async => pdf);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF önizleme'),
      ),
      body: FutureBuilder<_PdfData>(
        future: _futureData,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'PDF hazirlanamadi: ${snap.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snap.data!;
          return Row(
            children: [
              Expanded(
                child: Container(
                  color: const Color(0xFFF5F7FB),
                  padding: const EdgeInsets.all(16),
                  child: PdfPreview(
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    loadingWidget: const Center(
                      child: CircularProgressIndicator(),
                    ),
                    build: (format) => _buildPdf(data),
                  ),
                ),
              ),
              Container(
                width: 260,
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Color(0xFFE4E8F1))),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _working ? null : () => context.go('/'),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Geri dön'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _working ? null : () => _savePdf(data),
                      icon: const Icon(Icons.save_alt),
                      label: const Text('PDF Olarak Kaydet'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _working ? null : () => _printPdf(data),
                      icon: const Icon(Icons.print),
                      label: const Text('Yazdir'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                    if (_working) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Fis No: ${data.service.id}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Plaka: ${data.vehicle.plate}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PdfData {
  const _PdfData({
    required this.service,
    required this.vehicle,
  });

  final ServiceRecord service;
  final Vehicle vehicle;
}
