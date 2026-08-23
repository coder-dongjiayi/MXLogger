#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_mxlogger.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_mxlogger'
  s.version          = '2.0.0'
  s.summary          = 'iOS platform side of the flutter_mxlogger plugin.'
  s.description      = <<-DESC
iOS implementation of the flutter_mxlogger Flutter plugin. It exports the
Objective-C MXLogger as C symbols (prefixed flutter_mxlogger_) that the Dart
side binds through dart:ffi, plus a MethodChannel used only to resolve the
default log directory. Not meant to be depended on directly — add the
flutter_mxlogger package to your pubspec instead.
                       DESC
  s.homepage         = 'https://github.com/coder-dongjiayi/MXLogger'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'dongjiayi' => 'dongjiayi' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'MXLogger' ,'2.0.0'
  s.platform = :ios, '9.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
