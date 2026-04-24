import 'package:flutter/material.dart';

const String companyName = 'Mert Opel Servis';
const String companySubtitle = 'Profesyonel Araç Bakım Merkezi';
const String companyPhoneMert = '0543 835 03 90';
const String companyPhoneSukru = '0506 480 6202';
const String companyAddress =
    'Alaylar 2 Mahallesi 152350 Sk. No: 7 Seydişehir/Konya';

/// Geriye dönük uyumluluk — önceki [companyPhone] kullanımı.
const String companyPhone = companyPhoneMert;

/// Tüm PDF’lerde sayfa altı bilgilendirme metni.
const String pdfServiceTagline =
    'Benzinli ve Dizel tüm model araçlara Tamir/Bakım hizmetimiz vardır.';

/// Firestore koleksiyon adları (uygulama genelinde aynı isimler kullanılmalı).
abstract final class FirestoreCollections {
  static const String vehicles = 'vehicles';
  static const String serviceRecords = 'service_records';
  static const String inventory = 'inventory';
  static const String inventoryCategories = 'inventory_categories';
}

/// Uygulama renk paleti (Material 3 ile birlikte kullanın).
abstract final class AppColors {
  /// Birincil: antrasit siyah
  static const Color primaryNavy = Color(0xFF121212);

  /// İkincil: sarı vurgu
  static const Color secondaryOrange = Color(0xFFFACC15);

  /// Açık yüzey / arka plan
  static const Color surfaceMuted = Color(0xFFFFFFFF);
}

/// PDF, giriş ekranı ve başlık çubuğunda kullanılabilecek işletme bilgileri (buradan düzenleyin).
abstract final class BusinessInfo {
  static const String name = companyName;
  static const String subtitle = companySubtitle;
  static const String address = companyAddress;
  static const String phone = companyPhoneMert;
  static const String phoneMert = companyPhoneMert;
  static const String phoneSukru = companyPhoneSukru;
}

/// KDV oranları (ondalık: 0.10 = %10). Servis ekranı dropdown ile uyumlu.
abstract final class KdvRates {
  static const List<double> values = [0.1, 0.2];

  static String label(double rate) => '%${(rate * 100).round()}';
}

/// Parça / stok kategorileri (Firestore `category` alanı ile aynı metinler).
abstract final class PartCategories {
  static const List<String> defaults = [
    'Yağlar',
    'Filtreler',
    'Frenler',
    'Elektrik',
    'Diğer',
  ];

  /// Geriye dönük kullanım için varsayılan liste.
  static const List<String> all = defaults;
}

/// Geriye dönük uyumluluk — [PartCategories] kullanın.
@Deprecated('PartCategories kullanın')
abstract final class InventoryCategories {
  static List<String> get all => PartCategories.all;
}
