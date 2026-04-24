import 'package:cloud_firestore/cloud_firestore.dart';

class ServicePart {
  const ServicePart({
    required this.partId,
    required this.partName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.isManual = false,
  });

  final String partId;
  final String partName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  /// Stok dışı (elle girilen) satırlar; [true] ise envanterden düşülmez.
  final bool isManual;

  ServicePart copyWith({
    String? partId,
    String? partName,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    bool? isManual,
  }) {
    return ServicePart(
      partId: partId ?? this.partId,
      partName: partName ?? this.partName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      isManual: isManual ?? this.isManual,
    );
  }

  factory ServicePart.fromMap(Map<String, dynamic> map) {
    return ServicePart(
      partId: (map['partId'] ?? '') as String,
      partName: (map['partName'] ?? '') as String,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0,
      isManual: (map['isManual'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'partId': partId,
      'partName': partName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'isManual': isManual,
    };
  }
}

class LaborItem {
  const LaborItem({
    required this.description,
    required this.price,
  });

  final String description;
  final double price;

  LaborItem copyWith({
    String? description,
    double? price,
  }) {
    return LaborItem(
      description: description ?? this.description,
      price: price ?? this.price,
    );
  }

  factory LaborItem.fromMap(Map<String, dynamic> map) {
    return LaborItem(
      description: (map['description'] ?? '') as String,
      price: (map['price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'price': price,
    };
  }
}

class ServiceRecord {
  const ServiceRecord({
    required this.id,
    required this.vehiclePlate,
    required this.vehicleKm,
    required this.technicianId,
    required this.technicianName,
    required this.date,
    required this.parts,
    required this.laborItems,
    required this.subtotal,
    required this.kdvIncluded,
    required this.kdvRate,
    required this.kdvAmount,
    required this.grandTotal,
    required this.notes,
    required this.status,
  });

  final String id;
  final String vehiclePlate;
  final int vehicleKm;
  final String technicianId;
  final String technicianName;
  final DateTime date;
  final List<ServicePart> parts;
  final List<LaborItem> laborItems;
  final double subtotal;
  final bool kdvIncluded;
  final double kdvRate;
  final double kdvAmount;
  final double grandTotal;
  final String notes;
  final String status;

  ServiceRecord copyWith({
    String? id,
    String? vehiclePlate,
    int? vehicleKm,
    String? technicianId,
    String? technicianName,
    DateTime? date,
    List<ServicePart>? parts,
    List<LaborItem>? laborItems,
    double? subtotal,
    bool? kdvIncluded,
    double? kdvRate,
    double? kdvAmount,
    double? grandTotal,
    String? notes,
    String? status,
  }) {
    return ServiceRecord(
      id: id ?? this.id,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleKm: vehicleKm ?? this.vehicleKm,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      date: date ?? this.date,
      parts: parts ?? this.parts,
      laborItems: laborItems ?? this.laborItems,
      subtotal: subtotal ?? this.subtotal,
      kdvIncluded: kdvIncluded ?? this.kdvIncluded,
      kdvRate: kdvRate ?? this.kdvRate,
      kdvAmount: kdvAmount ?? this.kdvAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }

  factory ServiceRecord.fromMap(Map<String, dynamic> map) {
    final rawParts = (map['parts'] as List<dynamic>?) ?? const [];
    final rawLaborItems = (map['laborItems'] as List<dynamic>?) ?? const [];

    return ServiceRecord(
      id: (map['id'] ?? '') as String,
      vehiclePlate: (map['vehiclePlate'] ?? '') as String,
      vehicleKm: (map['vehicleKm'] as num?)?.toInt() ?? 0,
      technicianId: (map['technicianId'] ?? '') as String,
      technicianName: (map['technicianName'] ?? '') as String,
      date: _toDateTime(map['date']),
      parts: rawParts
          .map(
            (item) => ServicePart.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      laborItems: rawLaborItems
          .map(
            (item) => LaborItem.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      kdvIncluded: (map['kdvIncluded'] as bool?) ?? false,
      kdvRate: (map['kdvRate'] as num?)?.toDouble() ?? 0,
      kdvAmount: (map['kdvAmount'] as num?)?.toDouble() ?? 0,
      grandTotal: (map['grandTotal'] as num?)?.toDouble() ?? 0,
      notes: (map['notes'] ?? '') as String,
      status: (map['status'] ?? 'open') as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehiclePlate': vehiclePlate,
      'vehicleKm': vehicleKm,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'date': Timestamp.fromDate(date),
      'parts': parts.map((item) => item.toMap()).toList(),
      'laborItems': laborItems.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'kdvIncluded': kdvIncluded,
      'kdvRate': kdvRate,
      'kdvAmount': kdvAmount,
      'grandTotal': grandTotal,
      'notes': notes,
      'status': status,
    };
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}

