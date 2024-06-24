Pod::Spec.new do |s|
# pod lib lint --allow-warnings --verbose --skip-import-validation
  s.name         = "MXLogger"
  s.version      = "1.2.13"
  s.summary      = "MXLogger 客户端夸平台日志收集"

  s.description  = <<-DESC
                     MXLogger 客户端夸平台日志收集
                   DESC

  s.homepage     = "https://github.com/coder-dongjiayi/MXLogger"
  s.license      = { :type => "BSD 3-Clause", :file => "LICENSE.TXT"}
  s.author       = { "dongjiayi" => "dongjiayi1@xdf.cn" }

  s.ios.deployment_target = "9.0"

  s.source       = { :git => "https://github.com/coder-dongjiayi/MXLogger.git", :tag => "v#{s.version}" }
 
  s.source_files =  "iOS/MXLogger/MXLogger", "iOS/MXLogger/MXLogger/*.{h,mm}"
  s.public_header_files = "iOS/MXLogger/MXLogger/MXLogger.h"


   s.framework    = "CoreFoundation"

   s.dependency 'MXLoggerCore', "1.2.12"
   s.libraries    = "z", "c++"
   
  s.pod_target_xcconfig = {
     'VALID_ARCHS' => 'x86_64  arm64',
    "CLANG_CXX_LANGUAGE_STANDARD" => "gnu++17",
    "CLANG_CXX_LIBRARY" => "libc++",
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF" => "NO",
  }

end

