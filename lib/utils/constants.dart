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

/// PDF ve resmi dokümanlarda kullanılan işletme bilgileri.
abstract final class BusinessInfo {
  static const String name = 'Canal Oto Servis';
  static const String address = 'Sanayi Mah. Usta Sok. No:12, Istanbul';
  static const String phone = '+90 212 000 00 00';
}
