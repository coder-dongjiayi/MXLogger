// import "dart:typed_data";
// import 'dart:convert';
// /// https://gist.github.com/proteye/e54eef1713e1fe9123d1eb04c0a5cf9b
// Uint8List createUint8ListFromString(String s) {
//   var ret = new Uint8List(s.length);
//   for (var i = 0; i < s.length; i++) {
//     ret[i] = s.codeUnitAt(i);
//   }
//   return ret;
// }
//
// Uint8List createUint8ListFromHexString(String hex) {
//   var result = new Uint8List(hex.length ~/ 2);
//   for (var i = 0; i < hex.length; i += 2) {
//     var num = hex.substring(i, i + 2);
//     var byte = int.parse(num, radix: 16);
//     result[i ~/ 2] = byte;
//   }
//   return result;
// }
//
// Uint8List createUint8ListFromSequentialNumbers(int len) {
//   var ret = new Uint8List(len);
//   for (var i = 0; i < len; i++) {
//     ret[i] = i;
//   }
//   return ret;
// }
//
// String formatBytesAsHexString(Uint8List bytes) {
//   var result = new StringBuffer();
//   for (var i = 0; i < bytes.lengthInBytes; i++) {
//     var part = bytes[i];
//     result.write('${part < 16 ? '0' : ''}${part.toRadixString(16)}');
//   }
//   return result.toString();
// }
//
// List<int> decodePEM(String pem) {
//   var startsWith = [
//     "-----BEGIN PUBLIC KEY-----",
//     "-----BEGIN PRIVATE KEY-----",
//     "-----BEGIN ENCRYPTED MESSAGE-----",
//     "-----BEGIN PGP PUBLIC KEY BLOCK-----\r\nVersion: React-Native-OpenPGP.js 0.1\r\nComment: http://openpgpjs.org\r\n\r\n",
//     "-----BEGIN PGP PRIVATE KEY BLOCK-----\r\nVersion: React-Native-OpenPGP.js 0.1\r\nComment: http://openpgpjs.org\r\n\r\n",
//   ];
//   var endsWith = [
//     "-----END PUBLIC KEY-----",
//     "-----END PRIVATE KEY-----",
//     "-----END ENCRYPTED MESSAGE-----",
//     "-----END PGP PUBLIC KEY BLOCK-----",
//     "-----END PGP PRIVATE KEY BLOCK-----",
//   ];
//   bool isOpenPgp = pem.indexOf('BEGIN PGP') != -1;
//
//   for (var s in startsWith) {
//     if (pem.startsWith(s)) {
//       pem = pem.substring(s.length);
//     }
//   }
//
//   for (var s in endsWith) {
//     if (pem.endsWith(s)) {
//       pem = pem.substring(0, pem.length - s.length);
//     }
//   }
//
//   if (isOpenPgp) {
//     var index = pem.indexOf('\r\n');
//     pem = pem.substring(0, index);
//   }
//
//   pem = pem.replaceAll('\n', '');
//   pem = pem.replaceAll('\r', '');
//
//   return base64.decode(pem);
// }
//
// List<int> decodeHex(String hex) {
//   hex = hex
//       .replaceAll(':', '')
//       .replaceAll('\n', '')
//       .replaceAll('\r', '')
//       .replaceAll('\t', '');
//
//   return convert.hex.decode(hex);
// }