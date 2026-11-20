/// Urdu spelled the several ways it is typed, compared as one: vowel marks and
/// stretching dropped, look-alike letters folded together, spacing tidied.
String normalizeUrdu(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    if ((rune >= 0x064B && rune <= 0x065F) ||
        rune == 0x0670 ||
        rune == 0x0640) {
      continue; // vowel marks, dagger alif, tatweel
    }
    buffer.writeCharCode(switch (rune) {
      0x064A || 0x06CC || 0x06D2 => 0x06CC, // ي ی ے → ی
      0x0643 => 0x06A9, // ك → ک
      0x0629 || 0x06C3 || 0x06D5 => 0x06C1, // ة ۃ ە → ہ
      0x0622 || 0x0623 || 0x0625 => 0x0627, // آ أ إ → ا
      0x06BE => 0x06C1, // ھ → ہ
      _ => rune,
    });
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}

/// Whether [text] has any Arabic-script (Urdu/Arabic) letters in it.
bool hasUrduScript(String text) => RegExp(r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]').hasMatch(text);
