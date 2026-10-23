#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_mxlogger.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_mxlogger'
  s.version          = '2.2.0'
  s.summary          = 'iOS and macOS implementation of the flutter_mxlogger plugin.'
  s.description      = <<-DESC
iOS and macOS implementation of the flutter_mxlogger Flutter plugin. It exports the
Objective-C MXLogger as C symbols (prefixed flutter_mxlogger_) that the Dart
side binds through dart:ffi, plus a MethodChannel used only to resolve the
default log directory. Not meant to be depended on directly — add the
flutter_mxlogger package to your pubspec instead.
                       DESC
  s.homepage         = 'https://github.com/coder-dongjiayi/MXLogger'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'dongjiayi' => 'dongjiayi' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_mxlogger/Sources/flutter_mxlogger/**/*.{h,mm}'
  s.public_header_files = 'flutter_mxlogger/Sources/flutter_mxlogger/include/**/*.h'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.osx.frameworks = 'FlutterMacOS'
  s.dependency 'MXLogger' ,'2.2.0'
  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.14'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++17',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
