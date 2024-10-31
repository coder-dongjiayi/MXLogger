Pod::Spec.new do |s|
# pod lib lint --allow-warnings --verbose --skip-import-validation
  s.name         = "MXLoggerCore"
  s.version      = "1.2.14"
  s.summary      = "MXLoggerCore 客户端夸平台日志收集"

  s.description  = <<-DESC
                     MXLoggerCore 客户端夸平台日志收集
                   DESC

  s.homepage     = "https://github.com/coder-dongjiayi/MXLogger"
  s.license      = { :type => "BSD 3-Clause", :file => "LICENSE.TXT"}
  s.author       = { "dongjiayi" => "dongjiayi1@xdf.cn" }

  s.ios.deployment_target = "9.0"

  s.source       = { :git => "https://github.com/coder-dongjiayi/MXLogger.git", :tag => "v#{s.version}" }
  s.source_files = "Core", "Core/*.{h,cpp,hpp}", "Core/md5/*","Core/aes/*.{hpp,cpp}","Core/aes/openssl/*","Core/json/*","Core/flatbuffers/*","Core/sink/*"
  
  s.public_header_files = "Core/mxlogger.hpp","Core/mxlogger_util.hpp"
   

  s.libraries    = "z", "c++"
  s.framework    = "CoreFoundation","UIKit"

  s.pod_target_xcconfig = {
  	 'VALID_ARCHS' => 'x86_64  arm64',
    "CLANG_CXX_LANGUAGE_STANDARD" => "gnu++17",
    "CLANG_CXX_LIBRARY" => "libc++",
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF" => "NO",
  }

end

