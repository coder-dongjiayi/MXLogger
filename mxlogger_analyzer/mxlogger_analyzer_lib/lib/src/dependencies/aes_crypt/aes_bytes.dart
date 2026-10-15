/// Platform-independent AES byte operations, shared by native and web parsers.
library aes_bytes;

import 'dart:typed_data';

part 'src/aes.dart';

enum AesMode { ecb, cbc, cfb, ofb }

class AesCryptArgumentError extends ArgumentError {
  AesCryptArgumentError(String message) : super(message);

  static void checkNullOrEmpty(Object? argument, String message) {
    if (argument == null ||
        (argument is String && argument.isEmpty) ||
        (argument is Iterable && argument.isEmpty)) {
      throw AesCryptArgumentError(message);
    }
  }
}

extension on Uint8List? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
}
