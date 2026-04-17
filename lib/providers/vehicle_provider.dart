import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:otoservis_app/models/service_record.dart';
import 'package:otoservis_app/models/vehicle.dart';
import 'package:otoservis_app/utils/constants.dart';

class VehicleProvider extends ChangeNotifier {
  VehicleProvider({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Vehicle? _selectedVehicle;
  Vehicle? get selectedVehicle => _selectedVehicle;

  /// Türk plakası: trim, büyük harf, tüm boşlukları kaldır (Firestore anahtarı / arama).
  String normalizePlate(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    final upper = trimmed.toUpperCase();
    return upper.replaceAll(RegExp(r'\s+'), '');
  }

  /// Görüntü için kabaca "34 ABC 123" biçimi (kompakt plakadan).
  String formatPlateForDisplay(String normalizedPlate) {
    final p = normalizePlate(normalizedPlate);
    if (p.length < 3) return p;
    final match = RegExp(r'^(\d{2})([A-Z]{1,3})(\d{2,5})$').firstMatch(p);
    if (match != null) {
      return '${match[1]} ${match[2]} ${match[3]}';
    }
    return p;
  }

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
    await _firestore
        .collection(FirestoreCollections.vehicles)
        .doc(key)
        .set(toSave.toMap());
    _selectedVehicle = toSave;
    notifyListeners();
  }
}
