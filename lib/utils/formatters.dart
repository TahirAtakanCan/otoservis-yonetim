import 'package:intl/intl.dart';

/// Para birimi, tarih ve plaka için ortak formatlayıcılar.
abstract final class AppFormatters {
  /// Örnek: 1234.5 → "1.234,50 ₺"
  static String formatLira(num? value) {
    final v = value ?? 0;
    final fmt = NumberFormat('#,##0.00', 'tr_TR');
    return '${fmt.format(v)} ₺';
  }

  /// Örnek: "15 Ocak 2025"
  static String formatDateLong(DateTime date) {
    return DateFormat('d MMMM yyyy', 'tr_TR').format(date);
  }

  /// Tarih + saat (servis kayıtları için).
  static String formatDateTime(DateTime date) {
    return DateFormat('d MMMM yyyy HH:mm', 'tr_TR').format(date);
  }

  /// Plaka normalize: "34abc123" → "34ABC123" (boşluklar kaldırılır).
  static String normalizePlate(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    final upper = trimmed.toUpperCase();
    return upper.replaceAll(RegExp(r'\s+'), '');
  }

  /// Kompakt plakayı görüntü için kabaca "34 ABC 123" biçimine getirir.
  static String formatPlateDisplay(String normalizedPlate) {
    final p = normalizePlate(normalizedPlate);
    if (p.length < 3) return p;
    final match = RegExp(r'^(\d{2})([A-Z]{1,3})(\d{2,5})$').firstMatch(p);
    if (match != null) {
      return '${match[1]} ${match[2]} ${match[3]}';
    }
    return p;
  }
}
