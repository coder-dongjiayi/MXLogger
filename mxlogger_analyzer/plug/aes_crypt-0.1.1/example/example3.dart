import 'dart:math';
import 'dart:typed_data';

import 'package:aes_crypt/aes_crypt.dart';

// Asynchronous binary data encryption/decryption example

void main() async {
  var random = Random();

  // Relative file path for the encrypted file
  String encFilepath = './example/testfile2.txt.aes';

  // Source binary data to be encrypted
  int srcDataLen = 120;
  Uint8List srcData = Uint8List.fromList(List<int>.generate(srcDataLen, (i) => random.nextInt(256)));

  // Creates an instance of AesCrypt class.
  var crypt = AesCrypt('my cool password');

  // Sets overwrite mode (just as an example).
  crypt.setOverwriteMode(AesCryptOwMode.on);

  print('Source data: ${srcData}\n');

  // Encrypts source data and saves encrypted file.
  await crypt.encryptDataToFile(srcData, encFilepath);

  // Decrypts source data back.
  Uint8List decData = await crypt.decryptDataFromFile(encFilepath);

  print('Decrypted data: ${decData}');
}
