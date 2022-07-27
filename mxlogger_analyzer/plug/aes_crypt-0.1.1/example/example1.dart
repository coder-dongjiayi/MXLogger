import 'dart:io';

import 'package:aes_crypt/aes_crypt.dart';

// Synchronous file encryption/decryption example

void main() {
  String encFilepath;
  String decFilepath;

  // The file to be encrypted
  String srcFilepath = './example/testfile.txt';

  print('Unencrypted source file: $srcFilepath');
  print('File content: ' + File(srcFilepath).readAsStringSync() + '\n');

  // Creates an instance of AesCrypt class.
  var crypt = AesCrypt();

  // Sets encryption password.
  // Optionally you can specify the password when creating an instance
  // of AesCrypt class like:
  // var crypt = AesCrypt('my cool password');
  crypt.setPassword('my cool password');

  // Sets overwrite mode.
  // It's optional. By default the mode is 'AesCryptOwMode.warn'.
  crypt.setOverwriteMode(AesCryptOwMode.warn);

  try {
    // Encrypts './example/testfile.txt' file and save encrypted file to a file with
    // '.aes' extension added. In this case it will be './example/testfile.txt.aes'.
    // It returns a path to encrypted file.
    encFilepath = crypt.encryptFileSync('./example/testfile.txt');
    print('The encryption has been completed successfully.');
    print('Encrypted file: $encFilepath');
  } on AesCryptException catch (e) {
    // It goes here if overwrite mode set as 'AesCryptFnMode.warn'
    // and encrypted file already exists.
    if (e.type == AesCryptExceptionType.destFileExists) {
      print('The encryption has been completed unsuccessfully.');
      print(e.message);
    }
    return;
  }

  print('');

  try {
    // Decrypts the file which has been just encrypted.
    // It returns a path to decrypted file.
    decFilepath = crypt.decryptFileSync(encFilepath);
    print('The decryption has been completed successfully.');
    print('Decrypted file 1: $decFilepath');
    print('File content: ' + File(decFilepath).readAsStringSync() + '\n');
  } on AesCryptException catch (e) {
    // It goes here if the file naming mode set as AesCryptFnMode.warn
    // and decrypted file already exists.
    if (e.type == AesCryptExceptionType.destFileExists) {
      print('The decryption has been completed unsuccessfully.');
      print(e.message);
    }
  }

  print('');

  try {
    // Decrypts the file which has been just encrypted and tries to save it under
    // another name than source file name.
    decFilepath = crypt.decryptFileSync(encFilepath, './example/testfile_new.txt');
    print('The decryption has been completed successfully.');
    print('Decrypted file 2: $decFilepath');
    print('File content: ' + File(decFilepath).readAsStringSync());
  } on AesCryptException catch (e) {
    if (e.type == AesCryptExceptionType.destFileExists) {
      print('The decryption has been completed unsuccessfully.');
      print(e.message);
    }
  }

  print('');

  try {
    // Decrypts the file to the same name as previous one but before sets
    // another overwrite mode 'AesCryptFnMode.auto'. See what will happens.
    crypt.setOverwriteMode(AesCryptOwMode.rename);
    decFilepath = crypt.decryptFileSync(encFilepath, './example/testfile_new.txt');
    print('The decryption has been completed successfully.');
    print('Decrypted file 3: $decFilepath');
    print('File content: ' + File(decFilepath).readAsStringSync() + '\n');
  } on AesCryptException catch (e) {
    if (e.type == AesCryptExceptionType.destFileExists) {
      print('The decryption has been completed unsuccessfully.');
      print(e.message);
    }
  }


  print('Done.');
}
