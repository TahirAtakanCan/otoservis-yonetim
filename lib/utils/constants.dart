import 'package:flutter/material.dart';

/// Firestore koleksiyon adları (uygulama genelinde aynı isimler kullanılmalı).
abstract final class FirestoreCollections {
  static const String vehicles = 'vehicles';
  static const String serviceRecords = 'service_records';
  static const String inventory = 'inventory';
}

/// Uygulama renk paleti (Material 3 ile birlikte kullanın).
abstract final class AppColors {
  /// Birincil: koyu lacivert
  static const Color primaryNavy = Color(0xFF0F172A);

  /// İkincil: turuncu vurgu
  static const Color secondaryOrange = Color(0xFFE67E22);

  /// Açık yüzey / arka plan
  static const Color surfaceMuted = Color(0xFFF1F5F9);
}

/// PDF, giriş ekranı ve başlık çubuğunda kullanılabilecek işletme bilgileri (buradan düzenleyin).
abstract final class BusinessInfo {
  static const String name = 'Canal Oto Servis';
  static const String address = 'Sanayi Mah. Usta Sok. No:12, İstanbul';
  static const String phone = '+90 212 000 00 00';
}

/// KDV oranları (ondalık: 0.10 = %10). Servis ekranı dropdown ile uyumlu.
abstract final class KdvRates {
  static const List<double> values = [0.1, 0.2];

  static String label(double rate) => '%${(rate * 100).round()}';
}

/// Parça / stok kategorileri (Firestore `category` alanı ile aynı metinler).
abstract final class PartCategories {
  static const List<String> all = [
    'Yağlar',
    'Filtreler',
    'Frenler',
    'Elektrik',
    'Diğer',
  ];
}

/// Geriye dönük uyumluluk — [PartCategories] kullanın.
@Deprecated('PartCategories kullanın')
abstract final class InventoryCategories {
  static List<String> get all => PartCategories.all;
}
