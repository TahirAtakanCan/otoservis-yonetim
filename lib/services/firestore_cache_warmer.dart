import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:otoservis_app/utils/constants.dart';

/// Açıkken Firestore L2 (disk) önbelleğine sık kullanılan koleksiyonları doldurur;
/// böylece bağlantı kesildiğinde mümkün olduğunca veri cihazda kalır.
class FirestoreCacheWarmer {
  FirestoreCacheWarmer._();

  static Future<void> warmUp(FirebaseFirestore firestore) async {
    await Future.wait([
      _safeGet(
        () => firestore.collection(FirestoreCollections.vehicles).get(),
        'vehicles',
      ),
      _safeGet(
        () => firestore.collection(FirestoreCollections.inventory).get(),
        'inventory',
      ),
      _safeGet(
        () => firestore
            .collection(FirestoreCollections.inventoryCategories)
            .get(),
        'inventory_categories',
      ),
      _safeGet(
        () => firestore.collection(FirestoreCollections.serviceRecords).get(),
        'service_records',
      ),
    ]);
  }

  static Future<void> _safeGet(
    Future<QuerySnapshot<Map<String, dynamic>>> Function() run,
    String label,
  ) async {
    try {
      await run();
    } catch (e, st) {
      debugPrint('Önbellek ısındırma atlandı ($label): $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
    }
  }
}
