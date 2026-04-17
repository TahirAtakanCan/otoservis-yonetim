import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:otoservis_app/models/inventory_item.dart';
import 'package:otoservis_app/utils/constants.dart';

class InventoryProvider extends ChangeNotifier {
  InventoryProvider({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _listenInventory();
  }

  final FirebaseFirestore _firestore;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _inventorySub;

  bool _searching = false;
  bool get isSearching => _searching;

  List<InventoryItem> _lastResults = [];
  List<InventoryItem> get lastSearchResults => List.unmodifiable(_lastResults);

  /// Envanter ekranı için tüm parçalar (canlı).
  List<InventoryItem> _allItems = [];
  List<InventoryItem> get allItems => List.unmodifiable(_allItems);

  bool _inventoryLoading = true;
  bool get inventoryLoading => _inventoryLoading;

  String? _inventoryError;
  String? get inventoryError => _inventoryError;

  /// Abonelik hata verirse yeniden denemek için.
  void retryInventoryStream() {
    _listenInventory();
  }

  void _listenInventory() {
    _inventorySub?.cancel();
    _inventoryLoading = true;
    _inventoryError = null;
    notifyListeners();

    _inventorySub = _firestore
        .collection(FirestoreCollections.inventory)
        .orderBy('name')
        .snapshots()
        .listen(
      (snapshot) {
        _allItems = snapshot.docs
            .map(
              (d) => InventoryItem.fromMap({
                ...d.data(),
                'id': d.id,
              }),
            )
            .toList();
        _inventoryLoading = false;
        _inventoryError = null;
        notifyListeners();
      },
      onError: (Object e) {
        _inventoryError = e.toString();
        _inventoryLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _inventorySub?.cancel();
    super.dispose();
  }

  /// İsim alanında önek araması (servis ekranı — `name` ASC).
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

  Future<InventoryItem?> getById(String id) async {
    final d = await _firestore
        .collection(FirestoreCollections.inventory)
        .doc(id)
        .get();
    if (!d.exists || d.data() == null) return null;
    return InventoryItem.fromMap({...d.data()!, 'id': d.id});
  }

  Future<void> createItem({
    required String name,
    required String category,
    required int quantity,
    required double unitPrice,
    required int minStockAlert,
  }) async {
    final ref = _firestore.collection(FirestoreCollections.inventory).doc();
    await ref.set({
      'id': ref.id,
      'name': name.trim(),
      'category': category,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'minStockAlert': minStockAlert,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateItem(InventoryItem item) async {
    await _firestore
        .collection(FirestoreCollections.inventory)
        .doc(item.id)
        .update({
      'name': item.name.trim(),
      'category': item.category,
      'quantity': item.quantity,
      'unitPrice': item.unitPrice,
      'minStockAlert': item.minStockAlert,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteItem(String id) async {
    await _firestore
        .collection(FirestoreCollections.inventory)
        .doc(id)
        .delete();
  }

  /// Mevcut stoka miktar ekler (atomik).
  Future<void> addStockTransaction({
    required String itemId,
    required int addQuantity,
  }) async {
    if (addQuantity < 1) {
      throw ArgumentError('Eklenecek miktar en az 1 olmalı.');
    }

    final ref =
        _firestore.collection(FirestoreCollections.inventory).doc(itemId);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (!snap.exists) {
        throw StateError('Parça bulunamadı.');
      }
      transaction.update(ref, {
        'quantity': FieldValue.increment(addQuantity),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
