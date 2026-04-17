import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:otoservis_app/models/inventory_item.dart';
import 'package:otoservis_app/utils/constants.dart';

class InventoryProvider extends ChangeNotifier {
  InventoryProvider({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  bool _searching = false;
  bool get isSearching => _searching;

  List<InventoryItem> _lastResults = [];
  List<InventoryItem> get lastSearchResults => List.unmodifiable(_lastResults);

  /// İsim alanında önek araması (sıralı indeks: `name` ASC).
  Future<List<InventoryItem>> searchParts(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      _lastResults = [];
      notifyListeners();
      return [];
    }

    _searching = true;
    notifyListeners();

    try {
      final snap = await _firestore
          .collection(FirestoreCollections.inventory)
          .orderBy('name')
          .startAt([q])
          .endAt(['$q\uf8ff'])
          .limit(40)
          .get();

      _lastResults = snap.docs
          .map(
            (d) => InventoryItem.fromMap({
              ...d.data(),
              'id': d.id,
            }),
          )
          .toList();
      notifyListeners();
      return _lastResults;
    } catch (e) {
      _lastResults = [];
      notifyListeners();
      rethrow;
    } finally {
      _searching = false;
      notifyListeners();
    }
  }

  /// Transaction dışında tek parça okumak (test / yardımcı).
  Future<InventoryItem?> getById(String id) async {
    final d = await _firestore
        .collection(FirestoreCollections.inventory)
        .doc(id)
        .get();
    if (!d.exists || d.data() == null) return null;
    return InventoryItem.fromMap({...d.data()!, 'id': d.id});
  }
}
