import 'dart:io';

bool get mxIsTestEnvironment =>
    Platform.environment.containsKey('FLUTTER_TEST');
