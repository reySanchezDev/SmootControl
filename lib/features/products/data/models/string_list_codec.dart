import 'dart:convert';

/// Encodes and decodes simple string lists.
final class StringListCodec {
  const StringListCodec._();

  /// Encodes strings as JSON.
  static String encode(List<String> values) {
    return jsonEncode([
      for (final value in values)
        if (value.trim().isNotEmpty) value.trim(),
    ]);
  }

  /// Decodes strings from JSON.
  static List<String> decode(String source) {
    if (source.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return const [];
      return [
        for (final value in decoded)
          if (value is String && value.trim().isNotEmpty) value.trim(),
      ];
    } on FormatException {
      return const [];
    }
  }
}
