import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:otoservis_app/models/inventory_item.dart';
import 'package:otoservis_app/utils/constants.dart';

class InventoryProvider extends ChangeNotifier {
  InventoryProvider({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance {
    _authSub = _auth.authStateChanges().listen(
      (user) {
        if (user != null) {
          _listenInventory();
        } else {
          _stopInventoryStream();
        }
      },
      onError: (Object e, StackTrace stack) {
        debugPrint('INVENTORY AUTH STREAM HATASI: $e');
        debugPrint('STACK: $stack');
      },
    );
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  StreamSubscription<User?>? _authSub;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _inventorySub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _categorySub;

  bool _searching = false;
  bool get isSearching => _searching;

  List<String> _categories = [...PartCategories.defaults];
  List<String> get categories => List.unmodifiable(_categories);

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
    if (_auth.currentUser == null) {
      return;
    }
    _listenInventory();
  }

  void _stopInventoryStream() {
    _inventorySub?.cancel();
    _inventorySub = null;
    _categorySub?.cancel();
    _categorySub = null;
    _allItems = [];
    _categories = [...PartCategories.defaults];
    _inventoryLoading = false;
    _inventoryError = null;
    notifyListeners();
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

    _listenCategories();
  }

  void _listenCategories() {
    _categorySub?.cancel();
    _categorySub = _firestore
        .collection(FirestoreCollections.inventoryCategories)
        .orderBy('name')
        .snapshots()
        .listen(
      (snapshot) {
        final fromDb = snapshot.docs
            .map((d) => (d.data()['name'] as String? ?? '').trim())
            .where((e) => e.isNotEmpty)
            .toList();

        final fromItems = _allItems
            .map((e) => e.category.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        final merged = <String>{
          ...PartCategories.defaults,
          ...fromDb,
          ...fromItems,
        }.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        _categories = merged;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('CATEGORY STREAM HATASI: $e');
      },
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _inventorySub?.cancel();
    _categorySub?.cancel();
    super.dispose();
  }

  String normalizeCategoryName(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> ensureCategoryExists(String categoryName) async {
    final normalized = normalizeCategoryName(categoryName);
    if (normalized.isEmpty) {
      throw ArgumentError('Kategori adı boş olamaz.');
    }

    final ref = _firestore
        .collection(FirestoreCollections.inventoryCategories)
        .doc(normalized.toLowerCase());
    await ref.set({
      'id': ref.id,
      'name': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteCategory(String categoryName) async {
    final normalized = normalizeCategoryName(categoryName);
    if (normalized.isEmpty) {
      throw ArgumentError('Geçersiz kategori.');
    }

    final inUse = _allItems.any((e) => e.category == normalized);
    if (inUse) {
      throw StateError('Bu kategori kullanımda olduğu için silinemez.');
    }

    await _firestore
        .collection(FirestoreCollections.inventoryCategories)
        .doc(normalized.toLowerCase())
        .delete();
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
      // Önce canlı envanter listesinde büyük/küçük harf duyarsız filtrele.
      // Bu sayede "Metal" / "metal" farkı yüzünden sonuç kaçmaz.
      if (_allItems.isNotEmpty) {
        final lower = q.toLowerCase();
        _lastResults = _allItems
            .where((item) => item.name.toLowerCase().contains(lower))
            .take(40)
            .toList();
        notifyListeners();
        return _lastResults;
      }

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
    final normalizedCategory = normalizeCategoryName(category);
    if (normalizedCategory.isEmpty) {
      throw ArgumentError('Kategori zorunlu.');
    }
    await ensureCategoryExists(normalizedCategory);

    final ref = _firestore.collection(FirestoreCollections.inventory).doc();
    await ref.set({
      'id': ref.id,
      'name': name.trim(),
      'category': normalizedCategory,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'minStockAlert': minStockAlert,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateItem(InventoryItem item) async {
    final normalizedCategory = normalizeCategoryName(item.category);
    if (normalizedCategory.isEmpty) {
      throw ArgumentError('Kategori zorunlu.');
    }
    await ensureCategoryExists(normalizedCategory);

    await _firestore
        .collection(FirestoreCollections.inventory)
        .doc(item.id)
        .update({
      'name': item.name.trim(),
      'category': normalizedCategory,
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
