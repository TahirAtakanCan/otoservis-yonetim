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
  /// Her not: {text: String, addedAt: DateTime} şeklinde saklanır.
  /// Firestore'da `issueNotes` alanı altında tutulur.
  final List<Map<String, dynamic>> issueNotes;

  Vehicle copyWith({
    String? plate,
    String? ownerName,
    String? ownerPhone,
    String? brand,
    String? model,
    int? year,
    int? currentKm,
    DateTime? createdAt,
    List<Map<String, dynamic>>? issueNotes,
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
      'issueNotes':
          issueNotes.map((note) {
            return {
              'text': note['text'] ?? '',
              'addedAt':
                  note['addedAt'] is DateTime
                      ? Timestamp.fromDate(note['addedAt'] as DateTime)
                      : note['addedAt'],
            };
          }).toList(),
    };
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  static List<Map<String, dynamic>> _parseIssueNotes(dynamic value) {
    if (value == null) return const [];

    if (value is List) {
      final result = <Map<String, dynamic>>[];
      for (final e in value) {
        if (e == null) continue;
        
        // Yeni format: Map<String, dynamic> ile
        if (e is Map<String, dynamic>) {
          result.add({
            'text': (e['text'] ?? '').toString().trim(),
            'addedAt': _toDateTime(e['addedAt']),
          });
        }
        // Eski format: String olarak geldiyse (backward compatibility)
        else if (e is String && e.isNotEmpty) {
          result.add({
            'text': e.trim(),
            'addedAt': DateTime.now(),
          });
        }
      }
      return result;
    }

    if (value is String && value.isNotEmpty) {
      // Eski/yanlış biçimlendirme: tek string geldiyse satır satır böl
      return value
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((text) => {
            'text': text,
            'addedAt': DateTime.now(),
          })
          .toList();
    }

    return const [];
  }
}
