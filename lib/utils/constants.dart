/// Firestore koleksiyon adları (uygulama genelinde aynı isimler kullanılmalı).
abstract final class FirestoreCollections {
  static const String vehicles = 'vehicles';
  static const String serviceRecords = 'service_records';
  static const String inventory = 'inventory';
}

/// Stok kategorileri (Firestore `category` alanı ile aynı metinler).
abstract final class InventoryCategories {
  static const List<String> all = [
    'Yağlar',
    'Filtreler',
    'Frenler',
    'Elektrik',
    'Diğer',
  ];
}
