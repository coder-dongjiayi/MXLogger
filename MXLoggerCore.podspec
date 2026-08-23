Pod::Spec.new do |s|
# pod lib lint --allow-warnings --verbose --skip-import-validation
  s.name         = "MXLoggerCore"
  s.version      = "2.0.0"
  s.summary      = "High-performance cross-platform logging core built on mmap, with AES-CFB-128 encryption."

  s.description  = <<-DESC
                     MXLoggerCore is the C/C++ engine behind MXLogger. Records are written
                     through an mmap-ed buffer, so a write costs a memcpy instead of a file
                     I/O syscall, and buffered data survives an abnormal process exit.

                     * mmap-backed writes: no main-thread I/O blocking, no data loss on crash
                     * AES-CFB-128 encryption with a caller-supplied key and IV
                     * FlatBuffers serialization: compact binary records, zero-copy reads
                     * File split policies: per hour, day, week or month
                     * Disk budget enforced by max file age and max total size
                     * Shared by the iOS, Android and Flutter bindings, so the .mx file
                       format is byte-identical on every platform

                     This pod contains the core only. iOS projects should depend on the
                     MXLogger pod, which provides the Objective-C API on top of it.
                   DESC

  s.homepage     = "https://github.com/coder-dongjiayi/MXLogger"
  s.license      = { :type => "BSD 3-Clause", :file => "LICENSE.TXT"}
  s.author       = { "dongjiayi" => "dongjiayi" }

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

