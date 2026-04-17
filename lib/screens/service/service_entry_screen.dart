import 'package:flutter/material.dart';

/// Servis girişi (içerik sonra doldurulacak).
class ServiceEntryScreen extends StatelessWidget {
  const ServiceEntryScreen({
    super.key,
    this.initialPlate,
  });

  final String? initialPlate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni servis')),
      body: Center(
        child: Text(
          initialPlate != null && initialPlate!.isNotEmpty
              ? 'Servis girişi — plaka: $initialPlate'
              : 'Servis girişi',
        ),
      ),
    );
  }
}
