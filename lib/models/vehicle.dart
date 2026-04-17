import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  const Vehicle({
    required this.plate,
    required this.ownerName,
    required this.ownerPhone,
    required this.brand,
    required this.model,
    required this.year,
    required this.createdAt,
  });

  final String plate;
  final String ownerName;
  final String ownerPhone;
  final String brand;
  final String model;
  final int year;
  final DateTime createdAt;

  Vehicle copyWith({
    String? plate,
    String? ownerName,
    String? ownerPhone,
    String? brand,
    String? model,
    int? year,
    DateTime? createdAt,
  }) {
    return Vehicle(
      plate: plate ?? this.plate,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      plate: (map['plate'] ?? '') as String,
      ownerName: (map['ownerName'] ?? '') as String,
      ownerPhone: (map['ownerPhone'] ?? '') as String,
      brand: (map['brand'] ?? '') as String,
      model: (map['model'] ?? '') as String,
      year: (map['year'] as num?)?.toInt() ?? 0,
      createdAt: _toDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plate': plate,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'brand': brand,
      'model': model,
      'year': year,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}

