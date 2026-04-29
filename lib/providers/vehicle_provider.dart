import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:otoservis_app/models/service_record.dart';
import 'package:otoservis_app/models/vehicle.dart';
import 'package:otoservis_app/utils/constants.dart';
import 'package:otoservis_app/utils/formatters.dart';

class VehicleProvider extends ChangeNotifier {
  VehicleProvider({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Vehicle? _selectedVehicle;
  Vehicle? get selectedVehicle => _selectedVehicle;

  /// Türk plakası: [AppFormatters.normalizePlate].
  String normalizePlate(String input) => AppFormatters.normalizePlate(input);

  /// Görüntü: [AppFormatters.formatPlateDisplay].
  String formatPlateForDisplay(String normalizedPlate) =>
      AppFormatters.formatPlateDisplay(normalizedPlate);

  void setSelectedVehicle(Vehicle? vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  Future<Vehicle?> fetchVehicleByPlate(String plate) async {
    final key = normalizePlate(plate);
    if (key.isEmpty) return null;

    final docRef =
        _firestore.collection(FirestoreCollections.vehicles).doc(key);
    final snap = await docRef.get();
    if (snap.exists && snap.data() != null) {
      return Vehicle.fromMap({
        ...snap.data()!,
        'plate': snap.data()!['plate'] ?? key,
      });
    }

    final query = await _firestore
        .collection(FirestoreCollections.vehicles)
        .where('plate', isEqualTo: key)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final d = query.docs.first;
    return Vehicle.fromMap({...d.data(), 'plate': d.data()['plate'] ?? key});
  }

  /// [vehiclePlate] alanı normalize plaka ile eşleşen servis kayıtları (tarih azalan).
  Future<List<ServiceRecord>> fetchServiceHistoryForPlate(String plate) async {
    final key = normalizePlate(plate);
    if (key.isEmpty) return [];

    final snap = await _firestore
        .collection(FirestoreCollections.serviceRecords)
        .where('vehiclePlate', isEqualTo: key)
        .get();

    final list = snap.docs.map((doc) {
      final data = doc.data();
      return ServiceRecord.fromMap({
        ...data,
        'id': doc.id,
        'vehiclePlate': data['vehiclePlate'] ?? key,
      });
    }).toList();

    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Yeni araç: belge ID = normalize plaka.
  Future<void> saveVehicle(Vehicle vehicle) async {
    final key = normalizePlate(vehicle.plate);
    if (key.isEmpty) {
      throw ArgumentError('Geçersiz plaka');
    }
    final toSave = vehicle.copyWith(plate: key);

    final docRef = _firestore.collection(FirestoreCollections.vehicles).doc(key);
    final existing = await docRef.get();

    if (!existing.exists) {
      // Yeni kayıt: tüm alanları yaz.
      await docRef.set(toSave.toMap());
      _selectedVehicle = toSave;
    } else {
      // Mevcut kayıt: sorunu/arıza notlarını silmeden ekle.
      final issues = toSave.issueNotes
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final updateData = <String, dynamic>{
        'plate': key,
        'ownerName': toSave.ownerName.trim(),
        'ownerPhone': toSave.ownerPhone.trim(),
        'brand': toSave.brand.trim(),
        'model': toSave.model.trim(),
        'year': toSave.year,
        'currentKm': toSave.currentKm,
      };

      if (issues.isNotEmpty) {
        updateData['issueNotes'] = FieldValue.arrayUnion(issues);
      }

      await docRef.update(updateData);
      final updatedSnap = await docRef.get();
      final updatedData = updatedSnap.data();
      if (updatedData != null) {
        _selectedVehicle = Vehicle.fromMap({...updatedData, 'plate': key});
      } else {
        _selectedVehicle = toSave;
      }
    }
    notifyListeners();
  }

  /// Plaka değişmez; diğer alanları günceller.
  Future<void> updateVehicleDetails({
    required String plate,
    required String ownerName,
    required String ownerPhone,
    required String brand,
    required String model,
    required int year,
    required int currentKm,
  }) async {
    final key = normalizePlate(plate);
    if (key.isEmpty) throw ArgumentError('Geçersiz plaka');

    await _firestore.collection(FirestoreCollections.vehicles).doc(key).update({
      'ownerName': ownerName.trim(),
      'ownerPhone': ownerPhone.trim(),
      'brand': brand.trim(),
      'model': model.trim(),
      'year': year,
      'currentKm': currentKm,
    });

    if (_selectedVehicle?.plate == key) {
      _selectedVehicle = _selectedVehicle!.copyWith(
        ownerName: ownerName.trim(),
        ownerPhone: ownerPhone.trim(),
        brand: brand.trim(),
        model: model.trim(),
        year: year,
        currentKm: currentKm,
      );
    }
    notifyListeners();
  }

  /// Araç belgesini ve bu araca ait tüm servis kayıtlarını siler.
  Future<void> deleteVehicleWithServiceRecords(String plate) async {
    final key = normalizePlate(plate);
    if (key.isEmpty) throw ArgumentError('Geçersiz plaka');

    final recordsSnap = await _firestore
        .collection(FirestoreCollections.serviceRecords)
        .where('vehiclePlate', isEqualTo: key)
        .get();

    const chunkSize = 450;
    final docs = recordsSnap.docs;
    for (var i = 0; i < docs.length; i += chunkSize) {
      final batch = _firestore.batch();
      final end = math.min(i + chunkSize, docs.length);
      for (var j = i; j < end; j++) {
        batch.delete(docs[j].reference);
      }
      await batch.commit();
    }

    await _firestore.collection(FirestoreCollections.vehicles).doc(key).delete();

    if (_selectedVehicle?.plate == key) {
      _selectedVehicle = null;
    }
    notifyListeners();
  }

  /// Tek bir servis kaydını belge ID üzerinden siler.
  Future<void> deleteServiceRecordById(String serviceId) async {
    final id = serviceId.trim();
    if (id.isEmpty) throw ArgumentError('Geçersiz servis kaydı');

    await _firestore
        .collection(FirestoreCollections.serviceRecords)
        .doc(id)
        .delete();
    notifyListeners();
  }

  /// Bir araca ait tüm servis kayıtlarını siler; araç kaydı korunur.
  /// Dönüş: silinen kayıt adedi.
  Future<int> deleteServiceHistoryForPlate(String plate) async {
    final key = normalizePlate(plate);
    if (key.isEmpty) throw ArgumentError('Geçersiz plaka');

    final recordsSnap = await _firestore
        .collection(FirestoreCollections.serviceRecords)
        .where('vehiclePlate', isEqualTo: key)
        .get();

    const chunkSize = 450;
    final docs = recordsSnap.docs;
    for (var i = 0; i < docs.length; i += chunkSize) {
      final batch = _firestore.batch();
      final end = math.min(i + chunkSize, docs.length);
      for (var j = i; j < end; j++) {
        batch.delete(docs[j].reference);
      }
      await batch.commit();
    }

    notifyListeners();
    return docs.length;
  }
}
