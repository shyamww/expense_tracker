// Indian rupee amounts are stored as whole paisa (1 ₹ = 100) in DB and models;
// convert to/from rupees at UI boundaries only.

library money;

const int kPaisaPerRupee = 100;

double rupeesFromPaisa(int paisa) => paisa / kPaisaPerRupee;

/// Legacy REAL rupees from DB → paisa (migration / old JSON).
int paisaFromRupeeDouble(double rupees) =>
    (rupees * kPaisaPerRupee).round();

/// User-entered rupee string, e.g. `2`, `2.3`, `2.35`, optional leading `-`.
int paisaFromRupeeString(String input) {
  var s = input.trim().replaceAll(',', '');
  if (s.isEmpty) return 0;
  final neg = s.startsWith('-');
  if (neg) s = s.substring(1).trim();
  if (s.isEmpty) return 0;
  final parts = s.split('.');
  var whole = int.tryParse(parts[0]) ?? 0;
  if (parts.length == 1) {
    return neg ? -whole * kPaisaPerRupee : whole * kPaisaPerRupee;
  }
  var frac = parts[1];
  if (frac.length > 2) frac = frac.substring(0, 2);
  while (frac.length < 2) {
    frac = '${frac}0';
  }
  final f = int.tryParse(frac) ?? 0;
  if (neg) {
    return -whole * kPaisaPerRupee - f;
  }
  return whole * kPaisaPerRupee + f;
}

/// DB / JSON: int paisa, or legacy fractional rupees.
int amountPaisaFromMap(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return paisaFromRupeeDouble(v.toDouble());
  return 0;
}

/// Backup v5+ uses [amount_paisa]; older backups only [amount] in rupees.
int backupAmountToPaisa(Map<String, dynamic> map) {
  if (map['amount_paisa'] != null) {
    return (map['amount_paisa'] as num).toInt();
  }
  return amountPaisaFromMap(map['amount']);
}

/// `2.30` style (always two fractional digits), no currency prefix.
String formatRupeesFixed2FromPaisa(int paisa) {
  final neg = paisa < 0;
  final a = neg ? -paisa : paisa;
  final ru = a ~/ kPaisaPerRupee;
  final frac = a % kPaisaPerRupee;
  final sign = neg ? '-' : '';
  return '$sign$ru.${frac.toString().padLeft(2, '0')}';
}

/// UI aggregates already in rupees (`double`) → same two-decimal string (half-up to paisa).
String formatRupeesTwoDecimalsFromDouble(double rupees) {
  return formatRupeesFixed2FromPaisa(paisaFromRupeeDouble(rupees));
}

/// Text field when editing an amount stored as paisa.
String amountFieldTextFromPaisa(int paisa) {
  final neg = paisa < 0;
  final a = neg ? -paisa : paisa;
  if (a % kPaisaPerRupee == 0) {
    return '${neg ? '-' : ''}${a ~/ kPaisaPerRupee}';
  }
  final ru = a ~/ kPaisaPerRupee;
  final frac = a % kPaisaPerRupee;
  if (frac % 10 == 0) {
    return '${neg ? '-' : ''}$ru.${frac ~/ 10}';
  }
  return '${neg ? '-' : ''}$ru.${frac.toString().padLeft(2, '0')}';
}
