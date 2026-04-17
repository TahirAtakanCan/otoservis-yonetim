import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    required this.minStockAlert,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String category;
  final int quantity;
  final double unitPrice;
  final int minStockAlert;
  final DateTime updatedAt;

  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    int? quantity,
    double? unitPrice,
    int? minStockAlert,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: (map['id'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      category: (map['category'] ?? '') as String,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      minStockAlert: (map['minStockAlert'] as num?)?.toInt() ?? 0,
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'minStockAlert': minStockAlert,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}

