import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Para birimi, tarih, plaka ve telefon için ortak formatlayıcılar.
abstract final class AppFormatters {
  /// Sadece rakamlar, en fazla 11.
  static String normalizePhoneDigits(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length <= 11) return d;
    return d.substring(0, 11);
  }

  /// Cep: `0 (5xx) xxx xx xx` — 5 ile başlayan 10 hane otomatik `0` alır; diğer
  /// 10–11 haneli girişte yalnızca rakam (maske yok).
  static String formatTurkishPhoneForDisplay(String digits) {
    var d = digits;
    if (d.isEmpty) return '';
    if (d.length == 10 && d.startsWith('5')) d = '0$d';
    if (d.length > 11) d = d.substring(0, 11);
    if (d.isEmpty) return '';

    if (d[0] == '0' && d.length > 1 && d[1] == '5') {
      if (d.length == 1) return d[0];
      if (d.length == 2) return '${d[0]} (${d[1]}';
      if (d.length == 3) {
        return '${d[0]} (${d[1]}${d[2]}';
      }
      if (d.length == 4) {
        return '${d[0]} (${d[1]}${d[2]}${d[3]}) ';
      }
      if (d.length <= 7) {
        return '${d[0]} (${d[1]}${d[2]}${d[3]}) ${d.substring(4)}';
      }
      if (d.length <= 9) {
        return '${d[0]} (${d[1]}${d[2]}${d[3]}) ${d.substring(4, 7)} ${d.substring(7)}';
      }
      return '${d[0]} (${d[1]}${d[2]}${d[3]}) ${d.substring(4, 7)} ${d.substring(7, 9)} ${d.substring(9)}';
    }

    return d;
  }

  static String? validateVehiclePhone(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Zorunlu';
    }
    final d = normalizePhoneDigits(v);
    if (d.isEmpty) return 'Sadece rakam girin';
    if (d.length < 10) return 'En az 10 hane gerekli';
    if (d.length > 11) return 'En fazla 11 hane girebilirsiniz';
    return null;
  }
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

/// Türkiye (cep 05…): en fazla 11 rakam, `0 (5xx) xxx xx xx` görüntü.
class TurkishMobilePhoneTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10 && digits.startsWith('5')) {
      digits = '0$digits';
    }
    if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }
    final newText = AppFormatters.formatTurkishPhoneForDisplay(digits);
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
