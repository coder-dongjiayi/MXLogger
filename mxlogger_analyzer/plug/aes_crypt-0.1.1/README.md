# aes_crypt 

## Introduction

aes_crypt is a library for Dart and Flutter developers that uses 256-bit AES algorithm 
to encrypt/decrypt files, plain text and binary data. It is fully compatible with the 
[AES Crypt](https://www.aescrypt.com/) file format.
It can be used to integrate AES Crypt functionality into your own Dart or Flutter applications.
All algorithms are implemented in pure Dart and work in all platforms.

aes_crypt writes and reads version 2 (latest) of the AES Crypt file specification. Backwards compatibility 
with reading the version 1 is implemented but untested. 
Output .aes files are fully compatible with any software using the AES Crypt standard file format. 
This library is accompanied by clients and libraries for different operating systems
and programming languages.
For more information about AES Crypt and AES Crypt compatible 
applications for other platforms, please visit [AESCrypt's official website](https://www.aescrypt.com).  
 
## Features

- 256-bit AES encryption format.
- File-to-file encryption and decryption.
- Memory-to-file encryption, file-to-memory decryption.
- Password can be in Unicode (like "密碼 パスワード пароль كلمة السر").
- Support for asynchronous file system reading/writing.
- Encrypted files have .aes extension which clients on other operating systems recognize.
- Compatible software available for Windows, Linux, Mac OS, Android and iOS 
(https://www.aescrypt.com/download/).

## Usage

In the `pubspec.yaml` of your project, add the following dependency:
```yaml
dependencies:
  ...
  aes_crypt: ^0.1.1
```

In your Dart code add the following import:
```dart
import 'dart:typed_data';
import 'package:aes_crypt/aes_crypt.dart';
```

Initialization:
```dart
var crypt = AesCrypt('my cool password');
```
or
```dart
var crypt = AesCrypt();
crypt.setPassword('my cool password');
```

Optionally you can set overwrite mode for the file write operations:
```dart
// Overwrites the file if it exists.
crypt.setOverwriteMode(AesCryptOwMode.on);

// If the file exists, stops the operation and throws 'AesCryptException'
// exception with 'AesCryptExceptionType.destFileExists' type (see 
// example1.dart in 'example'  folder). This mode is set by default.
crypt.setOverwriteMode(AesCryptOwMode.warn);

// If the file exists, adds index '(1)' to its' name and tries to save. 
// If such file also exists, adds '(2)' to its name, then '(3)', etc. 
crypt.setOverwriteMode(AesCryptOwMode.rename);
```

*Notice: All functions having 'Sync' at the end of their names are synchronous.
If you need asynchronous ones, please just remove 'Sync' from the end of function name.*


File encryption/decryption:
```dart
// Encrypts the file srcfile.txt and saves encrypted file under original name 
// with '.aes' extention added (srcfile.txt.aes). You can specify relative or 
// direct path to it. To save the file into current directory specify it 
// either as './srcfile.txt' or as 'srcfile.txt'.
crypt.encryptFileSync('srcfile.txt');

// Encrypts the file srcfile.txt and saves encrypted file under 
// the name enc_file.txt.aes
crypt.encryptFileSync('srcfile.txt', 'enc_file.txt.aes');

// Decrypts the file srcfile.txt.aes and saves decrypted file under 
// the name srcfile.txt
crypt.decryptFileSync('srcfile.txt.aes');

// Decrypts the file srcfile.txt.aes and saves decrypted file under 
// the name dec_file.txt
crypt.decryptFileSync('srcfile.txt.aes', 'dec_file.txt');
```

Text <=> file encryption/decryption:
```dart
String decryptedText;

// Plain text to be encrypted
String srcText = 'some text';

// Encrypts the text as UTF8 string and saves it into 'mytext.txt.aes' file.
crypt.encryptTextToFileSync(srcText, 'mytext.txt.aes');
// Encrypts the text as UTF16 Big Endian string and saves it 
// into 'mytext.txt.aes' file.
crypt.encryptTextToFileSync(srcText, 'mytext.txt.aes', utf16: true);
// Encrypts the text as UTF16 Little Endian string and saves it 
// into 'mytext.txt.aes' file.
crypt.encryptTextToFileSync(srcText, 'mytext.txt.aes', utf16: true, endian: Endian.little);
// Add 'bom: true' as an argument if you want to add byte order mark 
// at the beginning of the text string before the encryption. For example:
// crypt.encryptTextToFileSync(srcText, 'mytext.txt.aes', bom: true);

// Decrypts the file and interprets it based on byte order mark if it has one.
// Otherwise it will be interpreted as UTF8 text.
decryptedString = crypt.decryptTextFromFileSync('mytext.txt.aes');
// Decrypts the file and interprets it based on byte order mark if it has one.
// Otherwise it will be interpreted as UTF16 Big Endian text.
decryptedString = crypt.decryptTextFromFileSync('mytext.txt.aes', utf16: true);
// Decrypts the file and interprets it based on byte order mark if it has one.
// Otherwise it will be interpreted as UTF16 Little Endian text.
decryptedString = crypt.decryptTextFromFileSync('mytext.txt.aes', utf16: true, endian: Endian.little);

```

Binary data <=> file encryption/decryption:
```dart
// Binary data to be encrypted
Uint8List srcData = Uint8List.fromList([1,2,3,4,5]);

// Encrypts the data and saves it into mydata.bin.aes file.
crypt.encryptDataToFileSync(srcData, 'mydata.bin.aes');

// Decrypt the data from 'mydata.bin.aes' file
Uint8List decryptedData = crypt.decryptDataFromFileSync('mydata.bin.aes');
```

Binary data AES encryption/decryption:
```dart
// The encryption key. It should be 128, 192 or 256 bits long.
Uint8List key = Uint8List.fromList([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]);

// The initialization vector used in advanced cipher modes. 
// It must be 128 bits long.
Uint8List iv = Uint8List.fromList([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]);

// AES mode of operation. It can be one of the next values:
//    AesMode.ecb - ECB (Electronic Code Book)
//    AesMode.cbc - CBC (Cipher Block Chaining)
//    AesMode.cfb - CFB (Cipher Feedback)
//    AesMode.ofb - OFB (Output Feedback)
// By default the mode is AesMode.cbc
AesMode mode = AesMode.cbc; // Ok. I know it's meaningless here.

// Sets the encryption key and IV.
crypt.aesSetKeys(key, iv);
// Sets cipher mode
crypt.aesSetMode(mode);

// If you wish you can set the key, IV and cipher mode in one function.
//crypt.aesSetParams(key, iv, mode);

// The binary data to be encrypted
Uint8List srcData = Uint8List.fromList([1,2,3,4,5]);

// Encrypts the data. Padding scheme - null byte (0x00).
Uint8List encryptedData = crypt.aesEncrypt(srcData);
// Decrypts the data
Uint8List decryptedData = crypt.aesDecrypt(encryptedData);
```

SHA256 and HMAC-SHA256 computation:
```dart
// The source data
Uint8List srcData = Uint8List.fromList([1,2,3,4,5,6,7,8,9]);

// Computes SHA256 hash
Uint8List hash = crypt.sha256(srcData);

// Secret cryptographic key for HMAC
Uint8List key = Uint8List.fromList([1,2,3]);

// Computes HMAC-SHA256 code
Uint8List hmac = crypt.hmacSha256(key, srcData);
```


## Future plans

- reducing the memory usage for large file processing
- asynchronous encrypting/decrypting
- support for streams
- support for key files

## Support

Please file feature requests and bugs at the [issue tracker](https://github.com/alexgoussev/aes_crypt/issues)

I would be grateful if you help me to correct grammar and syntactical errors 
for this readme and library documentation.  
