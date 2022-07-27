import 'package:aes_crypt/aes_crypt.dart';

// Synchronous string encryption/decryption example

void main() {
  String decText = '';
  String encFilepath = '';

  // Source string to be encrypted
  String srcText =
      'Twas brillig, and the slithy toves did gyre and gimble in the wabe: '
      'All mimsy were the borogoves, and the mome raths outgrabe. '
      'Варкалось. Хливкие шорьки пырялись по наве, и хрюкотали зелюки, как мюмзики в мове.';

  print('Source string: $srcText\n');

  // Creates an instance of AesCrypt class.
  var crypt = AesCrypt('my cool password');

  // Encrypts source string and saves encrypted file as './example/testfile2.txt.aes'.
  // Third argument 'utf16' is optional. If it is not specified or set to 'false',
  // the string will be saved as UTF8 string, otherwise it will be saved as UTF16.
  // The function returns a path to encrypted file.
  // ...
  encFilepath = crypt.encryptTextToFileSync(srcText, './example/testfile2.txt.aes', utf16: true);

  print('Encrypted file: $encFilepath\n');

  try {
    // Let's try to set wrong password and see what will happens.
    crypt.setPassword('my wrong password');
    // Decrypts the file and returns source string.
    decText = crypt.decryptTextFromFileSync(encFilepath, utf16: true);
    print('Decrypted string: $decText');
  } on AesCryptDataException catch (e) {
    // It goes here in the case of wrong password or corrupted file.
    print('The decryption has been completed unsuccessfully.');
    print('Error: $e');
  } on AesCryptFsException catch (e) {
    // It goes here in the case of some file system operation error
    // (file opening, reading or writing).
    print('The decryption has been completed unsuccessfully.');
    print('Error: $e');
  }


  print('\nDone.');
}
