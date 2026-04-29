import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  const Vehicle({
    required this.plate,
    required this.ownerName,
    required this.ownerPhone,
    required this.brand,
    required this.model,
    required this.year,
    required this.currentKm,
    required this.createdAt,
    this.issueNotes = const [],
  });

  final String plate;
  final String ownerName;
  final String ownerPhone;
  final String brand;
  final String model;
  final int year;
  final int currentKm;
  final DateTime createdAt;
  /// Araçla ilgili problem/arıza notları (birden fazla kayıt olabilir).
  ///
  /// Firestore'da `issueNotes` alanı altında saklanır.
  final List<String> issueNotes;

  Vehicle copyWith({
    String? plate,
    String? ownerName,
    String? ownerPhone,
    String? brand,
    String? model,
    int? year,
    int? currentKm,
    DateTime? createdAt,
    List<String>? issueNotes,
  }) {
    return Vehicle(
      plate: plate ?? this.plate,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      currentKm: currentKm ?? this.currentKm,
      createdAt: createdAt ?? this.createdAt,
      issueNotes: issueNotes ?? this.issueNotes,
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
      currentKm: (map['currentKm'] as num?)?.toInt() ?? 0,
      createdAt: _toDateTime(map['createdAt']),
      issueNotes: _parseIssueNotes(map['issueNotes']),
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
      'currentKm': currentKm,
      'createdAt': Timestamp.fromDate(createdAt),
      'issueNotes': issueNotes,
    };
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  static List<String> _parseIssueNotes(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (value is String) {
      // Eski/yanlış biçimlendirme durumunda tek string geldiyse satır satır böl.
      return value
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }
}

