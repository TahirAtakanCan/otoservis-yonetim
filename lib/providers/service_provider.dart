import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:otoservis_app/models/service_record.dart';
import 'package:otoservis_app/utils/constants.dart';

class ServiceProvider extends ChangeNotifier {
  ServiceProvider({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  bool _saving = false;
  bool get isSaving => _saving;

  /// Servis kaydını yazar; parça satırları için stok düşüşünü aynı transaction içinde yapar.
  /// Dönüş: oluşturulan `service_records` belge ID'si.
  Future<String> completeServiceAndDeductStock({
    required ServiceRecord record,
  }) async {
    if (record.parts.any((p) => p.quantity < 1)) {
      throw ArgumentError('Parça adedi en az 1 olmalı.');
    }

    _saving = true;
    notifyListeners();

    try {
      final serviceId = _firestore
          .collection(FirestoreCollections.serviceRecords)
          .doc()
          .id;

      final full = record.copyWith(id: serviceId);

      await _firestore.runTransaction((transaction) async {
        final invSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};

        for (final p in full.parts) {
          final ref = _firestore
              .collection(FirestoreCollections.inventory)
              .doc(p.partId);
          invSnaps[p.partId] = await transaction.get(ref);
        }

        for (final p in full.parts) {
          final snap = invSnaps[p.partId]!;
          if (!snap.exists) {
            throw StateError('Stokta bulunamadı: ${p.partName}');
          }
          final q = (snap.data()!['quantity'] as num?)?.toInt() ?? 0;
          if (q < p.quantity) {
            throw StateError(
              'Yetersiz stok (${p.partName}): mevcut $q, istenen ${p.quantity}',
            );
          }
        }

        final serviceRef = _firestore
            .collection(FirestoreCollections.serviceRecords)
            .doc(serviceId);

        transaction.set(serviceRef, full.toMap());

        for (final p in full.parts) {
          final ref = _firestore
              .collection(FirestoreCollections.inventory)
              .doc(p.partId);
          transaction.update(ref, {
            'quantity': FieldValue.increment(-p.quantity),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      return serviceId;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
